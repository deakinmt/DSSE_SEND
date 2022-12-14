### parse from config file if this gets mature! (for every measured point you set in the file which measurements to pick, pqv, etc.)
"""
currently do P,Q,|V|, then we'll see.
"""
function add_measurements!(day_string::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[])
    file = joinpath(_DS.BASE_DIR, "twin_data/telemetry/2022$day_string/all_measurements$day_string.csv")
    ts_df = create_measurement_df(day_string, timestep, aggregation, file; exclude=exclude)
    add_measurements_from_df!(data, ts_df)
end

function add_measurements!(day_string::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[])
    file = joinpath(_DS.BASE_DIR, "twin_data/telemetry/2022$day_string/all_measurements$day_string.csv")
    ts_df = create_measurement_df(day_string, timestep, aggregation, file; exclude=exclude)
    add_measurements_from_df!(data, ts_df)
end

function create_measurement_df(day_string::String, timestep::Dates.DateTime, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[])
    file = joinpath(_DS.BASE_DIR, "twin_data/telemetry/2022$day_string/all_measurements$day_string.csv")
    meas_df = CSV.read(file)
    create_measurement_df(meas_df, timestep, aggregation, exclude=exclude)
end

function create_measurement_df(day_string::String, timestep::Dates.DateTime, aggregation::Dates.TimePeriod, file::String; exclude::Vector{String}=String[])
    meas_df = CSV.read(file)
    create_measurement_df(meas_df, timestep, aggregation, exclude=exclude)
end

function create_measurement_df(meas_df::DataFrames.DataFrame, timestep::Dates.DateTime, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[])::DataFrames.DataFrame
    if aggregation == Dates.Second(30) 
        ts_df = filter(x->x.IsoDatetime .== timestep, meas_df)
    else
        timerange = (timestep-aggregation+Dates.Second(30)):Dates.Second(30):timestep
        ts_df = aggregate_and_average_measurements(meas_df, timerange) # averages the measurements over the selected period
    end
    filter!(x->x.Id ??? setdiff(Set(unique(ts_df.Id)), Set(exclude)), ts_df)
    return ts_df
end

function aggregate_and_average_measurements(meas_df::DataFrames.DataFrame, timerange::StepRange{Dates.DateTime})::DataFrames.DataFrame
    aggr_df = filter(x->x.IsoDatetime ??? timerange, meas_df)
    res_df = DataFrames.DataFrame(repeat([[]], 11), names(aggr_df))
    for id in unique(aggr_df.Id)
        id_df = filter(x->x.Id == id, aggr_df)
        push!(res_df, [id, timerange[end], Statistics.mean(id_df.v1), Statistics.mean(id_df.v2), Statistics.mean(id_df.v3), 
                        Statistics.mean(id_df.i1), Statistics.mean(id_df.i2), Statistics.mean(id_df.i3), Statistics.mean(id_df.p), Statistics.mean(id_df.q), Statistics.mean(id_df.pf)])
    end
    return res_df
end

function add_measurements_from_df!(data::Dict, ts_df::DataFrames.DataFrame)
    data["meas"] = Dict{String, Any}()
    m = 1
    for (_, load) in data["load"]
        meas = filter(x->x.Id .== load["name"], ts_df)
        add_measurement!(data, load, meas, m, :pd)
        add_measurement!(data, load, meas, m+1, :qd)
        add_measurement!(data, load, meas, m+2, :vm)
        m+=3
    end
    m = maximum(parse.(Int, collect(keys(data["meas"]))))+1
    for (_, gen) in data["gen"]
        meas = filter(x->x.Id .== gen["name"], ts_df)
        add_measurement!(data, gen, meas, m, :pg)
        add_measurement!(data, gen, meas, m+1, :qg)
        add_measurement!(data, gen, meas, m+2, :vm)
        m+=3
    end
end

function add_measurement!(data::Dict, d::Dict, meas::DataFrames.DataFrame, m::Int, var::Symbol)
    
    cmp, cmp_id = if var ??? [:pd, :qd]
            :load, d["index"] 
          elseif var ??? [:pg, :qg]
            :gen, d["index"]
          else
            :bus, haskey(d, "load_bus") ? d["load_bus"] : d["gen_bus"] 
          end

    if !isempty(meas)
        dst = build_dst(meas, data, d, var) 
        data["meas"]["$m"] = Dict("var"=>var, "cmp"=> cmp, "cmp_id"=>cmp_id, "dst"=>dst, "name"=>meas.Id)
    end
end

function build_dst(meas::DataFrames.DataFrame, data::Dict, d::Dict, var::Symbol)
    if var == :vm
        bus_id = haskey(d, "load_bus") ? d["load_bus"] : d["gen_bus"] 
        m1, m2, m3 = (meas.v1[1], meas.v2[1], meas.v3[1])./(sqrt(3)*data["bus"]["$bus_id"]["vbase"]*1000)
        ?? = maximum([abs(0.002/3*Statistics.mean([m1, m2, m3])), 1e-7]) #voltage tolerances are ??0.2%
        if isnan(??) ?? = 1e-7 end
        if isnan(m1) m1 = 1e-7 end
        if isnan(m2) m2 = 1e-7 end
        if isnan(m3) m3 = 1e-7 end
    elseif var ??? [:pd, :qd, :pg, :qg]
        m1, m2, m3 = p_perunit(meas[Symbol(String(var)[1])][1], meas.v1[1], meas.v2[1], meas.v3[1], meas.i1[1], meas.i2[1], meas.i3[1])
        ?? = maximum([abs(0.005/3*Statistics.mean([m1, m2, m3])), 1e-7])
        if isnan(??) ?? = 1e-7 end
        if isnan(m1) m1 = 1e-7 end
        if isnan(m2) m2 = 1e-7 end
        if isnan(m3) m3 = 1e-7 end
    else
        @error "Measurement $var not recognized for $(meas.Id[1])"
    end
    return [_DST.Normal(m1, ??), _DST.Normal(m2, ??), _DST.Normal(m3, ??)]
end

function p_perunit(pow::Real, v1::Real, v2::Real, v3::Real, i1::Real, i2::Real, i3::Real)
    p1 = pow*(v1*i1)/sum([v1*i1, v2*i2, v3*i3])
    p2 = pow*(v2*i2)/sum([v1*i1, v2*i2, v3*i3])
    p3 = pow*(v3*i3)/sum([v1*i1, v2*i2, v3*i3])
    return p1/1e5, p2/1e5, p3/1e5
end
"""
All other measurements refer to a substation with load and generation.
This has only voltage and no active load/gen, so we only add the voltage indeed
"""
function add_ss13_2_meas!(day_string::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod)
    ts_df = create_measurement_df(day_string, timestep, aggregation)
    if !haskey(data, "meas") || isempty(data["meas"])
        data["meas"] = Dict{String, Any}()
        m = 0
    else
        m = maximum(parse.(Int, collect(keys(data["meas"]))))
    end

    meas = filter(x->x.Id .== "ss13_2", ts_df)
    bus_id = [b for (b,bus) in data["bus"] if bus["name"] == "ss13a"][1]

    m1, m2, m3 = (meas.v1[1], meas.v2[1], meas.v3[1])./(sqrt(3)*data["bus"][bus_id]["vbase"]*1000)
    ?? = abs(0.002/3*Statistics.mean([m1, m2, m3]))

    data["meas"]["$(m+1)"] = Dict("var"=>:vm, "cmp" => :bus, "cmp_id"=>parse(Int, bus_id), 
                        "dst" => [_DST.Normal(m1, ??), _DST.Normal(m2, ??), _DST.Normal(m3, ??)],
                        "name" => "ss13_2"
                        )
    nothing
end

function hack_ss19!(data)
    for (_,meas) in data["meas"]
        if meas["name"][1] == "ss19" && meas["var"] == :vm
            v1, v2, v3 = _DST.mean.(meas["dst"])
            if isapprox(v1, 1.05008, atol = 0.0001)
                ?? = _DST.std(meas["dst"][2])
                v1 = Statistics.mean([v2, v3])
                meas["dst"][1] = _DST.Normal(v1,??*2)
            end
        end
    end
end