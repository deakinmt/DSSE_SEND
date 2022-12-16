### parse from config file if this gets mature! (for every measured point you set in the file which measurements to pick, pqv, etc.)
"""
currently do P,Q,|V|, then we'll see.
"""
function add_measurements!(day_string::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[])
    file = joinpath(_DS.BASE_DIR, "twin_data/telemetry/2022$day_string/all_measurements$day_string.csv")
    ts_df = create_measurement_df(day_string, timestep, aggregation, file; exclude=exclude)
    add_measurements_from_df!(data, ts_df)
end

function add_balanced_measurements!(day_string::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[])
    file = joinpath(_DS.BASE_DIR, "twin_data/telemetry/2022$day_string/all_measurements$day_string.csv")
    ts_df = create_measurement_df(day_string, timestep, aggregation, file; exclude=exclude)
    add_measurements_from_df_balanced!(data, ts_df)
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
    filter!(x->x.Id ∈ setdiff(Set(unique(ts_df.Id)), Set(exclude)), ts_df)
    return ts_df
end

function aggregate_and_average_measurements(meas_df::DataFrames.DataFrame, timerange::StepRange{Dates.DateTime})::DataFrames.DataFrame
    aggr_df = filter(x->x.IsoDatetime ∈ timerange, meas_df)
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
        add_measurement!(data, load, meas, m+2, :vd)
        m+=3
    end
    m = maximum(parse.(Int, collect(keys(data["meas"]))))+1
    for (_, gen) in data["gen"]
        meas = filter(x->x.Id .== gen["name"], ts_df)
        add_measurement!(data, gen, meas, m, :pg)
        add_measurement!(data, gen, meas, m+1, :qg)
        add_measurement!(data, gen, meas, m+2, :vd)
        m+=3
    end
end

function add_measurements_from_df_balanced!(data::Dict, ts_df::DataFrames.DataFrame)
    data["meas"] = Dict{String, Any}()
    m = 1
    for (_, load) in data["load"]
        meas = filter(x->x.Id .== load["name"], ts_df)
        add_measurement_balanced!(data, load, meas, m, :pd)
        add_measurement_balanced!(data, load, meas, m+1, :qd)
        add_measurement!(data, load, meas, m+2, :vd)
        m+=3
    end
    m = maximum(parse.(Int, collect(keys(data["meas"]))))+1
    for (_, gen) in data["gen"]
        meas = filter(x->x.Id .== gen["name"], ts_df)
        add_measurement_balanced!(data, gen, meas, m, :pg)
        add_measurement_balanced!(data, gen, meas, m+1, :qg)
        add_measurement!(data, gen, meas, m+2, :vd)
        m+=3
    end
end

function add_measurement_balanced!(data::Dict, d::Dict, meas::DataFrames.DataFrame, m::Int, var::Symbol)
    
    cmp, cmp_id = if var ∈ [:pd, :qd]
            :load, d["index"] 
          elseif var ∈ [:pg, :qg]
            :gen, d["index"]
          else
            :bus, haskey(d, "load_bus") ? d["load_bus"] : d["gen_bus"] 
          end

    if !isempty(meas)
        dst = build_dst_balanced(meas, data, d, var, haskey(d, "reverse_generator")) 
        data["meas"]["$m"] = Dict("var"=>var, "cmp"=> cmp, "cmp_id"=>cmp_id, "dst"=>dst, "name"=>meas.Id)
    end
end

function add_measurement!(data::Dict, d::Dict, meas::DataFrames.DataFrame, m::Int, var::Symbol)
    
    cmp, cmp_id = if var ∈ [:pd, :qd]
            :load, d["index"] 
          elseif var ∈ [:pg, :qg]
            :gen, d["index"]
          else
            :bus, haskey(d, "load_bus") ? d["load_bus"] : d["gen_bus"] 
          end

    if !isempty(meas)
        dst = build_dst(meas, data, d, var, haskey(d, "reverse_generator")) 
        data["meas"]["$m"] = Dict("var"=>var, "cmp"=> cmp, "cmp_id"=>cmp_id, "dst"=>dst, "name"=>meas.Id)
    end
end

function build_dst(meas::DataFrames.DataFrame, data::Dict, d::Dict, var::Symbol, reverse::Bool)
    bus_id = haskey(d, "load_bus") ? d["load_bus"] : d["gen_bus"] 
    if var == :vd
        m1, m2, m3 = (meas.v1[1], meas.v2[1], meas.v3[1])./(data["bus"]["$bus_id"]["vbase"]*1000)
        #m1, m2, m3 = (meas.v1[1], meas.v2[1], meas.v3[1])./(sqrt(3)*data["bus"]["$bus_id"]["vbase"]*1000)
        σ = fill(sqrt(3)*0.005/3, 3) #voltage tolerances are ±0.5%
        if isnan(m1) m1 = 1e-7 end
        if isnan(m2) m2 = 1e-7 end
        if isnan(m3) m3 = 1e-7 end
        if any(isnan.([m1,m2,m3])) @warn "measurement for bus $bus_id has NaN(s)!" end
    elseif var ∈ [:pd, :qd, :pg, :qg]
        scale =  d["name"] ∈ ["solar", "storage", "wt", "_virtual_gen.voltage_source.source"] ? 1.0 : 1000 #except for those three, measurements are in W, not in kW (probably)
        m1, m2, m3 = p_subdivision(meas[Symbol(String(var)[1])][1], meas.v1[1], meas.v2[1], meas.v3[1], meas.i1[1], meas.i2[1], meas.i3[1])./(data["settings"]["sbase"]*scale)
        if reverse m1, m2, m3 = -m1,-m2,-m3 end
        σ = measurement_error_model(meas, data, var, bus_id)
        if isnan(m1) m1 = 1e-7 end
        if isnan(m2) m2 = 1e-7 end
        if isnan(m3) m3 = 1e-7 end
        if any(isnan.([m1,m2,m3])) @warn "measurement for load $(d["index"]) has NaN(s)!" end
    else
        @error "Measurement $var not recognized for $(meas.Id[1])"
    end

    return [_DST.Normal(m1, σ[1]), _DST.Normal(m2, σ[2]), _DST.Normal(m3, σ[3])]
end

function build_dst_balanced(meas::DataFrames.DataFrame, data::Dict, d::Dict, var::Symbol, reverse::Bool)
    bus_id = haskey(d, "load_bus") ? d["load_bus"] : d["gen_bus"] 
    
    if var ∈ [:pd, :qd, :pg, :qg]
        scale =  d["name"] ∈ ["solar", "storage", "wt"] ? 1.0 : 1000 #except for those three, measurements are in W, not in kW (probably)
        m1, m2, m3 = meas[Symbol(String(var)[1])][1]/3/(data["settings"]["sbase"]*scale), meas[Symbol(String(var)[1])][1]/3/(data["settings"]["sbase"]*scale), meas[Symbol(String(var)[1])][1]/3/(data["settings"]["sbase"]*scale) #p_subdivision(meas[Symbol(String(var)[1])][1], meas.v1[1], meas.v2[1], meas.v3[1], meas.i1[1], meas.i2[1], meas.i3[1])./(data["settings"]["sbase"]*scale)
        if reverse m1, m2, m3 = -m1,-m2,-m3 end
        σ = measurement_error_model(meas, data, var, bus_id)
        if isnan(m1) m1 = 1e-7 end
        if isnan(m2) m2 = 1e-7 end
        if isnan(m3) m3 = 1e-7 end
        if any(isnan.([m1,m2,m3])) @warn "measurement for load $(d["index"]) has NaN(s)!" end
    else
        @error "Measurement $var not recognized for $(meas.Id[1])"
    end

    return [_DST.Normal(m1, σ[1]), _DST.Normal(m2, σ[2]), _DST.Normal(m3, σ[3])]
end

function measurement_error_model(meas, data, var, bus_id)
    if minimum([meas.i1[1], meas.i2[1], meas.i3[1]]) < 120
        max_err = var ∈ [:pd, :pg] ? fill(0.01*120*(data["bus"]["$bus_id"]["vbase"]*1000)/1e5, 3) : fill(0.02*120*(data["bus"]["$bus_id"]["vbase"]*1000/1e5), 3)
    else
        max_err = var ∈ [:pd, :pg] ? [meas.i1[1], meas.i2[1], meas.i3[1]]*0.01*(data["bus"]["$bus_id"]["vbase"]*1000/1e5) : [meas.i1[1], meas.i2[1], meas.i3[1]]*0.02*(data["bus"]["$bus_id"]["vbase"]*1000/1e5)
    end
    return max_err./(3*data["settings"]["sbase"]) #sigma
end

function p_subdivision(pow::Real, v1::Real, v2::Real, v3::Real, i1::Real, i2::Real, i3::Real)
    p1 = pow*(v1*i1)/sum([v1*i1, v2*i2, v3*i3])
    p2 = pow*(v2*i2)/sum([v1*i1, v2*i2, v3*i3])
    p3 = pow*(v3*i3)/sum([v1*i1, v2*i2, v3*i3])
    return p1, p2, p3
end
"""
add_measurements!(...) only adds load and generator measurements, now we
add the substation/slackbus measurements (bus 13)
"""
function add_ss13_meas!(day_string::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod)
    add_ss13_1_meas!(day_string, timestep, data, aggregation)
    add_ss13_2_meas!(day_string, timestep, data, aggregation)
end

function add_ss13_1_meas!(day_string::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod)
    ts_df = create_measurement_df(day_string, timestep, aggregation)
    if !haskey(data, "meas") || isempty(data["meas"])
        data["meas"] = Dict{String, Any}()
        m = 0
    else
        m = maximum(parse.(Int, collect(keys(data["meas"]))))
    end

    meas = filter(x->x.Id .== "ss13_1", ts_df)

    @assert data["gen"]["4"]["name"] == "_virtual_gen.voltage_source.source" "Index of voltage source changed in data gen dictionary"
    add_measurement!(data, data["gen"]["4"], meas, m+1, :pg)
    add_measurement!(data, data["gen"]["4"], meas, m+2, :qg)
    add_measurement!(data, data["gen"]["4"], meas, m+3, :vd)

    nothing
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
    bus_id = [b for (b,bus) in data["bus"] if bus["name"] == "ss13_2"][1]

    m1, m2, m3 = (meas.v1[1], meas.v2[1], meas.v3[1])./(data["bus"][bus_id]["vbase"]*1000)
    #m1, m2, m3 = (meas.v1[1], meas.v2[1], meas.v3[1])./(sqrt(3)*data["bus"][bus_id]["vbase"]*1000)
    σ = abs(0.002/3*Statistics.mean([m1, m2, m3]))

    data["meas"]["$(m+1)"] = Dict("var"=>:vd, "cmp" => :bus, "cmp_id"=>parse(Int, bus_id), 
                        "dst" => [_DST.Normal(m1, σ), _DST.Normal(m2, σ), _DST.Normal(m3, σ)],
                        "name" => "ss13_2"
                        )
    nothing
end

function generators_as_loads!(math::Dict)
    l = maximum(collect(parse.(Int, (keys(math["load"])))))
    for (g, gen) in math["gen"]
        if !occursin("voltage_source", gen["name"])
            l+=1
            math["load"]["$l"] = deepcopy(math["load"]["3"]) #or any other laod
            math["load"]["$l"]["name"] = gen["name"] #or any other laod
            math["load"]["$l"]["load_bus"] = gen["gen_bus"] #or any other laod
            math["load"]["$l"]["vbase"] = 6.35085
            math["load"]["$l"]["reverse_generator"] = true
            delete!(math["gen"],g)
        end
    end
end

function generators_as_loads_pf!(math::Dict)
    l = maximum(collect(parse.(Int, (keys(math["load"])))))
    for (g, gen) in math["gen"]
        if !occursin("voltage_source", gen["name"])
            l+=1
            math["load"]["$l"] = Dict{String, Any}()
            math["load"]["$l"]["model"] = _PMD.POWER
            math["load"]["$l"]["configuration"] = _PMD.WYE
            math["load"]["$l"]["connections"] = [1,2,3]
            math["load"]["$l"]["status"] = 1
            math["load"]["$l"]["dispatchable"] = 0
            math["load"]["$l"]["vnom_kv"] = 1.0
            math["load"]["$l"]["name"] = gen["name"] 
            math["load"]["$l"]["source_id"] = gen["source_id"]
            math["load"]["$l"]["load_bus"] = gen["gen_bus"] 
            math["load"]["$l"]["vbase"] = gen["vbase"]

            math["load"]["$l"]["pd"] = gen["pmax"]
            math["load"]["$l"]["qd"] = gen["qmax"]
            math["load"]["$l"]["pmax"] = math["load"]["$l"]["pd"]
            math["load"]["$l"]["qmax"] = math["load"]["$l"]["qd"]
            math["load"]["$l"]["pmin"] = -math["load"]["$l"]["pd"]
            math["load"]["$l"]["qmin"] = -math["load"]["$l"]["qd"]
            math["load"]["$l"]["index"] = l

            math["load"]["$l"]["reverse_generator"] = true
            math["bus"]["$(gen["gen_bus"])"]["bus_type"] = 1
            delete!(math["gen"],g)
        end
    end
end
# legacy: delete?
# function hack_ss19!(data)
#     for (_,meas) in data["meas"]
#         if meas["name"][1] == "ss19" && meas["var"] == :vd
#             v1, v2, v3 = _DST.mean.(meas["dst"])
#             if isapprox(v1, 1.05008, atol = 0.0001)
#                 σ = _DST.std(meas["dst"][2])
#                 v1 = Statistics.mean([v2, v3])
#                 meas["dst"][1] = _DST.Normal(v1,σ*2)
#             end
#         end
#     end
# end