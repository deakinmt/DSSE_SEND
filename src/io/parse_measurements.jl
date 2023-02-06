"""
    add_measurements!(timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[], add_ss13::Bool=true)

Function that accesses the digital twin measurement file and adds the measurements to a PowerModelsDistribution dictionary (`data`) so that 
it can be used to run a state estimation calculation.
For each measurement, an entry is added in `data["meas"]` and the structure of this dictionary is detailed in the documentation of the 
PowerModelsDistributionStateEstimation package.
IMPORTANT NOTES: 1) by default, only P,Q and |U| measurements are added. Current measurements are available in the csv files too, tough.
                 2) some assumptions are taken to split the aggregated power measurements across the three phases. Please check the paper discussion.
                 3) if the above are not satisfactory, users can create their own measurement parsers, in similar fashions. This function can be used as "model" 
    Arguments:
    - timestep:    DateTime entry that picks the time step of the given day for which measurements are wanted
    - data:        PowerModelsDistribution `MATHEMATICAL` data dictionary for the SEND network
    - aggregation: the measurement csv file reports measurements with a granularity of 30 seconds. If aggregation is N × 30 seconds, with N > 1,
                   this function takes the measurements of the N-1 previous time steps and combines them to that of `timestep` (averaging).
                   Essentially, it is to explore the impact of different measurement granularities.
    - exclude:     allows the user to NOT create measurements for some loads/gens, e.g., "ss17". Might be useful if the measurements of a certain device 
                   are consistently corrupted. Or to explore under-determined scenarios, etc.
    - add_ss13:    if `true` (default), measurements for the voltage source are added, else these are ignored
"""
function add_measurements!(timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[], add_ss13::Bool=true)::Nothing
    day = Dates.Day(timestep).value
    month = Dates.Month(timestep).value
    file = joinpath(_DS.BASE_DIR, "twin_data/telemetry/2022_$(month)_$(day)/all_measurements_$(month)_$(day).csv")
    ts_df = create_measurement_df(file, timestep, aggregation; exclude=exclude)
    add_measurements_from_df!(data, ts_df)
    if add_ss13 _DS.add_ss13_meas!(file, timestep, data, aggregation) end
    nothing
end
"""
    add_balanced_measurements!(timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[], add_ss13::Bool=true)
Similar to `add_measurements!` (see that for more info) but specifically subdivides aggregated three-phase power measurements ̲EQUALLY per phase.
"""
function add_balanced_measurements!(timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[])::Nothing
    day = Dates.Day(timestep).value
    month = Dates.Month(timestep).value
    file = joinpath(_DS.BASE_DIR, "twin_data/telemetry/2022_$(month)_$(day)/all_measurements_$(month)_$(day).csv")
    ts_df = create_measurement_df(file, timestep, aggregation; exclude=exclude)
    add_measurements_from_df_balanced!(data, ts_df)
    if add_ss13 _DS.add_ss13_meas!(file, timestep, data, aggregation) end
    nothing
end
"""
Create_measurement_df(timestep::Dates.DateTime, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[])
    creates a dataframe from the measurements csv file. This is later use to build the measurement dictionary, e.g., in function `add_measurements!`
    Arguments:
    - timestep:    DateTime entry that picks the time step of the given day for which measurements are wanted
    - aggregation: the measurement csv file reports measurements with a granularity of 30 seconds. If aggregation is N × 30 seconds, with N > 1,
                   this function takes the measurements of the N-1 previous time steps and combines them to that of `timestep` (averaging).
                   Essentially, it is to explore the impact of different measurement granularities.
    - exclude:     allows the user to NOT create measurements for some loads/gens, e.g., "ss17". Might be useful if the measurements of a certain device 
                   are consistently corrupted. Or to explore under-determined scenarios, etc.
"""
function create_measurement_df(timestep::Dates.DateTime, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[])::DataFrames.DataFrame
    day = Dates.Day(timestep).value
    month = Dates.Month(timestep).value
    file = joinpath(_DS.BASE_DIR, "twin_data/telemetry/2022_$(month)_$(day)/all_measurements_$(month)_$(day).csv")
    meas_df = CSV.read(file)
    create_measurement_df(meas_df, timestep, aggregation, exclude=exclude)
end
"""
    create_measurement_df(file::String, timestep::Dates.DateTime, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[])
Creates a dataframe from the measurements csv file. This is later use to build the measurement dictionary, e.g., in function `add_measurements!`
    Arguments:
    - file:        path to the measurement csv file to use
    - timestep:    DateTime entry that picks the time step of the given day for which measurements are wanted
    - aggregation: the measurement csv file reports measurements with a granularity of 30 seconds. If aggregation is N × 30 seconds, with N > 1,
                   this function takes the measurements of the N-1 previous time steps and combines them to that of `timestep` (averaging).
                   Essentially, it is to explore the impact of different measurement granularities.
    - exclude:     allows the user to NOT create measurements for some loads/gens, e.g., "ss17". Might be useful if the measurements of a certain device 
                   are consistently corrupted. Or to explore under-determined scenarios, etc.
"""
function create_measurement_df(file::String, timestep::Dates.DateTime, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[])::DataFrames.DataFrame
    meas_df = CSV.read(file)
    create_measurement_df(meas_df, timestep, aggregation, exclude=exclude)
end
"""
    create_measurement_df(meas_df::DataFrames.DataFrame, timestep::Dates.DateTime, aggregation::Dates.TimePeriod; exclude::Vector{String}=String[])
Creates a dataframe from an existing measurement dataframe. Essentially just aggregates and averages the measurement of the input dataframe.
    Arguments:
    - meas_df:     measurement dataframe (read from a measurement csv file)
    - timestep:    DateTime entry that picks the time step of the given day for which measurements are wanted
    - aggregation: the measurement csv file reports measurements with a granularity of 30 seconds. If aggregation is N × 30 seconds, with N > 1,
                   this function takes the measurements of the N-1 previous time steps and combines them to that of `timestep` (averaging).
                   Essentially, it is to explore the impact of different measurement granularities.
    - exclude:     allows the user to NOT create measurements for some loads/gens, e.g., "ss17". Might be useful if the measurements of a certain device 
                   are consistently corrupted. Or to explore under-determined scenarios, etc.
"""
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
"""
    aggregate_and_average_measurements(meas_df::DataFrames.DataFrame, timerange::StepRange{Dates.DateTime})::DataFrames.DataFrame
Given a measurement dataframe `meas_df`, this function filters out all the measurements that do not pertain to the wanted time range `timerange`, and then
"aggregates" the measurements from that time range into a single average time step measurement.
"""
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
"""
    add_measurements_from_df!(data::Dict, ts_df::DataFrames.DataFrame)
Given a single time steps's measurement dataframe `ts_df` (which can be the average/aggregation of multiple time steps),
these measurements are added to the network dictionary `data` according to the format defined in PowerModelsDistributionStateEstimation.
The subdivision of aggregated power measurements per phase is that defined in the paper.
"""
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
"""
    add_measurement!(data::Dict, d::Dict, meas::DataFrames.DataFrame, m::Int, var::Symbol)
Building block for function `add_measurements_from_df!`: adds an entry/measurement to the measurement dictionary.
    Arguments:
    - `d`:    dictionary of the load or generator that the measurement refers to (`data["load"][l]` or similar)
    - `meas`: measurement dataframe for that component and a certain time step (possibly aggregation of multiple time steps)
    - `m`:    integer that corresponds to the index of the newly-being-added measurement
    - `var`:  symbol that indicates which variable the measurement refers to, e.g., :pg, :pd, :vd (see PowerModelsDistributionStateEstimation docs)
"""
function add_measurement!(data::Dict, d::Dict, meas::DataFrames.DataFrame, m::Int, var::Symbol)
    
    cmp, cmp_id = if var ∈ [:pd, :qd]
            :load, d["index"] 
          elseif var ∈ [:pg, :qg]
            :gen, d["index"]
          else
            :bus, haskey(d, "load_bus") ? d["load_bus"] : d["gen_bus"] 
          end

    if !isempty(meas)
        dst = build_dst(meas, data, d, var, haskey(d, "reverse_generator")) # loads that were generators in the .dss model have this 
                                                                            # `reverse generator` key, so the sign of their measurement
                                                                            # assigned here is opposite to that in the measurement csv/dataframe
        data["meas"]["$m"] = Dict("var"=>var, "cmp"=> cmp, "cmp_id"=>cmp_id, "dst"=>dst, "name"=>meas.Id)
    end
end
"""
    build_dst(meas::DataFrames.DataFrame, data::Dict, d::Dict, var::Symbol, reverse::Bool)
Function that builds the "dst" value of a measurement dictionary entry according to the format of PowerModelsDistributionStateEstimation.
    Arguments:
    - `meas`:    measurement dataframe for that component and a certain time step (possibly aggregation of multiple time steps)
    - `data`:    `MATHEMATICAL` network data dictionary to which the measurement entry is added
    - `d`:       dictionary of the load or generator that the measurement refers to (`data["load"][l]` or similar)
    - `var`:     symbol that indicates which variable the measurement refers to, e.g., :pg, :pd, :vd
    - `reverse`: changes the sign of a measurement entry in `meas` with its opposite (e.g., because a generator is now modelled as load)
"""
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
"""
    p_subdivision(pow::Real, v1::Real, v2::Real, v3::Real, i1::Real, i2::Real, i3::Real)::Tuple{Float64, Float64, Float64}
Rule to subdivide three-phase aggregated power measurements across the single phases.
Essentially, the subdivision depends on the measured current in each phase and the voltage difference measurements. 
v1, v2, v3, i1, i2, i3 are scalars and come from a measurement dataframe for a given (possibly aggregated) time step and a given user.
It is not a rigorous method, check paper for a discussion.
    Arguments:
    - pow:  value of the three-phase measurement
    - v1:   value of the voltage difference between phases 1 and 2
    - v2:   ....
    - v3:   ....
    - i1:   value of current measurement, phase 1
    - i2:   ....
    - i3:   ....
"""
function p_subdivision(pow::Real, v1::Real, v2::Real, v3::Real, i1::Real, i2::Real, i3::Real)::Tuple{Float64, Float64, Float64}
    p1 = pow*(v1*i1)/sum([v1*i1, v2*i2, v3*i3])
    p2 = pow*(v2*i2)/sum([v1*i1, v2*i2, v3*i3])
    p3 = pow*(v3*i3)/sum([v1*i1, v2*i2, v3*i3])
    return p1, p2, p3
end
"""
    add_measurements_from_df_balanced!(data::Dict, ts_df::DataFrames.DataFrame)
Like add_measurements_from_df! but the aggregated three-phase power measurements are equally split across the three phases.
"""
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
"""
    add_measurement_balanced!(data::Dict, ts_df::DataFrames.DataFrame)
Like add_measurement! but the aggregated three-phase power measurements are equally split across the three phases.
"""
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
"""
    build_dst_balanced!(data::Dict, ts_df::DataFrames.DataFrame)
Like buid_dst! but the aggregated three-phase power measurements are equally split across the three phases.
"""
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
"""
    measurement_error_model(meas::DataFrames.DataFrame, data::Dict, var::Symbol, bus_id::Int)::Vector{Float64}
Given the measurement values, this function assigns the (per unit) σs of power measurements according to the model detailed in the paper. 
    Arguments:
    - `meas`:    measurement dataframe for that component and a certain time step (possibly aggregation of multiple time steps)
    - `data`:    `MATHEMATICAL` network data dictionary to which the measurement entry is added
    - `var`:     symbol that indicates which variable the measurement refers to, e.g., :pg, :pd (power measurements only)
    - `bus_id`:  index of the bus to which the measured component is connected (needed to check its nominal voltage)
"""
function measurement_error_model(meas::DataFrames.DataFrame, data::Dict, var::Symbol, bus_id::Int)::Vector{Float64}
    if minimum([meas.i1[1], meas.i2[1], meas.i3[1]]) < 120
        max_err = var ∈ [:pd, :pg] ? fill(0.01*120*(data["bus"]["$bus_id"]["vbase"]*1000)/1e5, 3) : fill(0.02*120*(data["bus"]["$bus_id"]["vbase"]*1000/1e5), 3)
    else
        max_err = var ∈ [:pd, :pg] ? [meas.i1[1], meas.i2[1], meas.i3[1]]*0.01*(data["bus"]["$bus_id"]["vbase"]*1000/1e5) : [meas.i1[1], meas.i2[1], meas.i3[1]]*0.02*(data["bus"]["$bus_id"]["vbase"]*1000/1e5)
    end
    return max_err./(3*data["settings"]["sbase"]) #σs in per unit
end
"""
    add_ss13_meas!(file::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod)
Function `add_measurements!(...)` only adds load measurements. See add_measurements! for the argument definition
This function complements it by adding the voltage source/slack bus measurements of ss13_1
and the voltage-only measurements for ss13_2 (open switch so no power/current measurements).
"""
function add_ss13_meas!(file::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod)
    add_ss13_1_meas!(file, timestep, data, aggregation)
    add_ss13_2_meas!(file, timestep, data, aggregation)
end
"""
    add_ss13_1_meas!(file::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod)
ss13_1 corresponds to the voltage source. This function adds its measurements (P,Q,|U|) to a network `data` dictionary.
This complements `add_measurements!` which does not provide support to add voltage source measurements.
See `add_ss13_meas!` and `add_measurements!` for more info and a description of the arguments.
"""
function add_ss13_1_meas!(file::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod)
    ts_df = create_measurement_df(file, timestep, aggregation)
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
end
"""
    add_ss13_2_meas!(file::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod)
ss13_2 corresponds to a measurement on bus ss13a in the SEND single-line equivalent picture in the README.
Only voltage measurements are added, there is no active component; the switch to the HV/MV station is open.
See `add_ss13_meas!` and `add_measurements!` for more info and arguments
"""
function add_ss13_2_meas!(file::String, timestep::Dates.DateTime, data::Dict, aggregation::Dates.TimePeriod)
    ts_df = create_measurement_df(file, timestep, aggregation)
    if !haskey(data, "meas") || isempty(data["meas"])
        data["meas"] = Dict{String, Any}()
        m = 0
    else
        m = maximum(parse.(Int, collect(keys(data["meas"]))))
    end

    meas = filter(x->x.Id .== "ss13_2", ts_df)
    bus_id = [b for (b,bus) in data["bus"] if bus["name"] == "ss13_2"][1]

    m1, m2, m3 = (meas.v1[1], meas.v2[1], meas.v3[1])./(data["bus"][bus_id]["vbase"]*1000)
    σ = abs(0.002/3*Statistics.mean([m1, m2, m3]))

    data["meas"]["$(m+1)"] = Dict("var"=>:vd, "cmp" => :bus, "cmp_id"=>parse(Int, bus_id), 
                        "dst" => [_DST.Normal(m1, σ), _DST.Normal(m2, σ), _DST.Normal(m3, σ)],
                        "name" => "ss13_2"
                        )
end