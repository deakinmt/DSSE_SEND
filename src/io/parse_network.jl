"""
    default_network_parser(;adjust_tap_settings::Bool=true)::Dict
    
Produces a PowerModelsDistribution MATHEMATICAL data dictionary.
Users can choose whether to adjust the tap settings via argument `adjust_tap_settings`.
This is by default set to `true`. If `false`, all tap ratios are given the default 1.0 value.
Adjusting the tap settings produces better results but the option is left for ease of comparison.
Furthermore, generators in the .dss file - other than the voltage source - are modelled as negative loads.
"""
function default_network_parser(;adjust_tap_settings::Bool=true)::Dict
    eng = _DS.parse_send_ntw_eng()  # get the ENGINEERING network data dictionary
    if adjust_tap_settings _DS.update_tap_setting!(eng) end
    math = _PMD.transform_data_model(eng)
    _DS.model_generators_as_loads!(math)
    return math
end
"""
    parse_send_ntw_eng()::Dict

Accesses the send network's dss files and parses them to a PowerModelsDistribution `ENGINEERING` data model
"""
parse_send_ntw_eng()::Dict =
 _PMD.parse_file(joinpath(_DS.BASE_DIR, "twin_data/send_network_model/master_dsse.dss"), data_model=_PMD.ENGINEERING)
"""
 parse_send_ntw_eng(pth::String)::Dict

As its argument-less peer, but this goes and gets the master.dss file in the path
"""
parse_send_ntw_eng(pth::String)::Dict =
 _PMD.parse_file(pth, data_model=_PMD.ENGINEERING)
"""
 parse_send_ntw_math()::Dict

Accesses the send network's dss files and parses them to a PowerModelsDistribution `MATHEMATICAL` data model
"""
parse_send_ntw_math()::Dict = 
 _PMD.parse_file(joinpath(_DS.BASE_DIR, "twin_data/send_network_model/master_dsse.dss"), data_model=_PMD.MATHEMATICAL)
"""
Substation ss17 has really bad measurements, that cause high residuals.
This gets rid of those measurements and can be used as example to delete other measurements.
You can also simply not generate measurements for the ss17 (or other) substations by
useing the `exclude` argument in function `add_measurements!`
"""
function delete_ss17_meas!(math::Dict)
    ss17_bus = [load["load_bus"] for (l,load) in math["load"] if load["name"] == "ss17"][1]
    for (m,meas) in math["meas"]
        if (meas["var"] == :vd && meas["cmp_id"] == ss17_bus) || (meas["cmp"] == :load && meas["name"][1] == "ss17")
            delete!(math["meas"], m)
        end
    end
end
"""
The PowerModelsDistribution DSS parser does not seem to automatically register tap settings
(at least in the format used in this .dss file) and assignts all taps as 1.0. This 
function reads the actual tap settings given in the `xfmrs_dsse.dss` file and assigns 
them to the engineering data dictionary `ntw_eng`
"""
function update_tap_setting!(ntw_eng::Dict)
    xfmrs_file = joinpath(_DS.BASE_DIR, "twin_data/send_network_model/xfmrs_dsse.dss")
    f = open(xfmrs_file) 
    for line in readlines(f)
        spl = split(line, " ")
        tr = spl[2][13:end]
        if occursin("tap", spl[end])
            tapset = parse(Float64, spl[end][5:end]) 
            ntw_eng["transformer"][tr]["tm_set"] = [[1.0, 1.0, 1.0], [tapset, tapset, tapset]]
        end
    end
    close(f)
end
"""
    model_generators_as_loads!(math::Dict)

Takes a PowerModelsDistribution `MATHEMATICAL` dictionary and returns
the same but with generators modelled like (negative) loads.
This is to avoid discrepancies between the OpenDSS and the PowerModelsDistribution models.
"""
function model_generators_as_loads!(math::Dict)
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
"""
Assigns active and reactive power bounds to the mathematical dictionary `math`,
to all loads (except those loads that are actually generators).
"""
function assign_power_rating_based_bounds!(math::Dict)
    for (_, load) in math["load"]
        if load["name"] ∉ ["ss13_1", "wt", "storage", "solar"] # exclude generators
            load["pmin"] = -load["pd"]
            load["pmax"] = load["pd"]
            load["qmin"] = -0.3*load["pd"]
            load["qmax"] = 0.3*load["pd"]
        end
    end
end