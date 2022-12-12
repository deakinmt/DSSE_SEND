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
new files
"""
parse_send_new_ntw_eng()::Dict =
 _PMD.parse_file(joinpath(_DS.BASE_DIR, "twin_data/send_network_model/master_dsse.dss"), data_model=_PMD.ENGINEERING)
"""
Generators seem to be parsed from .dss to PV buses and FREQUENCYDROOP control model in MATHEMATICAL model.
This reverts them to PQ buses and sets ISOCHRONOUS control.
Should be equivalent to a negative load. --> to verify
"""
function adjust_gen_data!(math::Dict)
    @assert math["data_model"] == _PMD.MATHEMATICAL "This function works only with mathematical models"
    gen_buses = [gen["gen_bus"] for (_,gen) in math["gen"]]
    for (_,bus) in math["bus"]
        if bus["index"] ∈ gen_buses bus["bus_type"] = 1 end
    end
    for (_, gen) in math["gen"]
        if !occursin("voltage_source", gen["source_id"])
            gen["control_mode"] = _PMD.ISOCHRONOUS
        # else
        #     gen["name"] = "ss13_1" # TO CHECK HOW TO HANDLE THIS???
        #     math["bus"]["$(gen["gen_bus"])"]["bus_type"] = 3
        #     math["bus"]["$(gen["gen_bus"])"]["vmin"] = [0.0, 0.0, 0.0]
        #     math["bus"]["$(gen["gen_bus"])"]["vmax"] = [2.0, 2.0, 2.0]
        #     delete!(math["bus"]["$(gen["gen_bus"])"], "vm")
        end
    end
end
"""
Adapt the names of loads and generators so that they match the measurement ids in the 
big_lookup_csv.
Alternative is to create the latter directly in a way that the names match (less code and cleaner, actually)
Keep like this atm while we are still taking design decisions.
"""
function adjust_load_gen_names!(math::Dict)
    @assert math["data_model"] == _PMD.MATHEMATICAL "This function works only with mathematical models"
    for (g, gen) in math["gen"]
        if gen["name"] == "wind1"
            gen["name"] = "wind"
        elseif gen["name"] == "solar1"
            gen["name"] = "solar"
        elseif gen["name"] == "bess"
            gen["name"] = "storage"
        elseif gen["name"] == "_virtual_bus.voltage_source.source" || gen["name"] == "_virtual_gen.voltage_source.source" 
            gen["name"] = "ss13_1" # TO CHECK HOW TO HANDLE THIS???
            math["bus"]["$(gen["gen_bus"])"]["bus_type"] = 3
            math["bus"]["$(gen["gen_bus"])"]["vmin"] = [0.0, 0.0, 0.0]
            math["bus"]["$(gen["gen_bus"])"]["vmax"] = [2.0, 2.0, 2.0]
            delete!(math["bus"]["$(gen["gen_bus"])"], "vm")
        end
    end
    for (l,load) in math["load"]
        if load["name"] == "t01"
            load["name"] = "ss01_tx1"
        elseif load["name"] == "t02"
            load["name"] = "ss01_tx2"
        end
    end
end
"""
Removes the transformers loads/gens that are connected to the LV but measured on the MV side.
It keeps the loads/gens, but puts them on the MV bus where the measurement belongs.
This function does not remove the voltage source though, see `rm_voltage_source!`
"""
function adjust_some_meas_location!(data::Dict)
    data["generator"]["wind1"]["bus"] = "tx3"
    delete!(data["transformer"], "xfmr_2")
    delete!(data["bus"], "tx3_lv")
    data["generator"]["bess"]["bus"] = "tx5"
    delete!(data["transformer"], "xfmr_4")
    delete!(data["bus"], "tx5_lv")
    data["load"]["ss17"]["bus"] = "ss17"
    delete!(data["transformer"], "xfmr_23")
    delete!(data["bus"], "ss17_lv")
    data["generator"]["solar1"]["bus"] = "rmu2"
    delete!(data["transformer"], "xfmr_1")
    delete!(data["bus"], "rmu2_lv")
end
"""
Removes the voltage source transfo and just treats the connection at the HV/LV transfo as a 
slackbus. Data must be in the MATHEMATICAL form.
"""
function rm_voltage_source!(data::Dict)
    data["gen"]["6"]["vbase"] = data["bus"]["34"]["vbase"]
    data["gen"]["6"]["gen_bus"] = 34
    data["bus"]["34"]["bus_type"] = 3
    for bus in ["142", "55", "81", "80", "78", "79"]
        delete!(data["bus"], bus)
    end
    for branch in ["102", "56", "55", "54"]
        delete!(data["branch"], branch)
    end
    for (t, trnsfo) in data["transformer"]
        if occursin("sourcexfmr", trnsfo["name"]) delete!(data["transformer"], t) end
    end
end
"""
Some substations are measured (they are in the csv files) but there is no load associated to them.
This function defines loads and transfos, so we can use those measurements!
    Some of these are on the MV, some on the LV
"""
function add_loads_for_measured_ss!(data::Dict)
    data["load"]["ss12"] = deepcopy(data["load"]["ss16"])
    data["load"]["ss12"]["source_id"] = "load.ss12"
    data["load"]["ss12"]["bus"] = "ss12"

    data["load"]["ss11"] = deepcopy(data["load"]["ss16"])
    data["load"]["ss11"]["source_id"] = "load.ss11"
    data["load"]["ss11"]["bus"] = "ss11_lv"
    data["bus"]["ss11_lv"] = deepcopy(data["bus"]["tx4_lv"])
    data["transformer"]["xfmr_nu1"] = deepcopy(data["transformer"]["xfmr_5"])
    data["transformer"]["xfmr_nu1"]["source_id"] = "xfmr_nu1"
    data["transformer"]["xfmr_nu1"]["bus"] = ["ss11", "ss11_lv"]

    data["load"]["ss25"] = deepcopy(data["load"]["ss16"])
    data["load"]["ss25"]["source_id"] = "load.ss25"
    data["load"]["ss25"]["bus"] = "ss25_lv"
    data["bus"]["ss25_lv"] = deepcopy(data["bus"]["tx4_lv"])
    data["transformer"]["xfmr_nu2"] = deepcopy(data["transformer"]["xfmr_5"])
    data["transformer"]["xfmr_nu2"]["source_id"] = "xfmr_nu2"
    data["transformer"]["xfmr_nu2"]["bus"] = ["ss25", "ss25_lv"]
    # I WOULD LIKE TO ADD SS29 BUT IT DOES NOT EVEN EXIST AS A BUS, SO dontknow WHERE IT IS LOCATED
    # data["load"]["ss29"] = deepcopy(data["load"]["ss16"])
    # data["load"]["ss29"]["source_id"] = "load.ss29"
    # data["load"]["ss29"]["bus"] = "ss29_lv"
    # data["bus"]["ss29_lv"] = deepcopy(data["bus"]["tx4_lv"])
    # data["transformer"]["xfmr_nu3"] = deepcopy(data["transformer"]["xfmr_5"])
    # data["transformer"]["xfmr_nu3"]["source_id"] = "xfmr_nu3"
    # data["transformer"]["xfmr_nu3"]["bus"] = ["ss29", "ss29_lv"]
end
"""
Deletes the transfo and LV bus for those loads that are not measured.
    The load is moved to the MV side.
    This reduces the complexity because fewer transfos = fewer constraints!
"""
function delete_transfo_where_no_meas!(data::Dict)
    delete!(data["bus"], "ss08_lv")
    delete!(data["transformer"], "xfmr_13")
    data["load"]["ss08"]["bus"] = "ss08"

    delete!(data["bus"], "t08_lv")
    delete!(data["transformer"], "xfmr_12")
    data["load"]["t08"]["bus"] = "t08"

    delete!(data["bus"], "ss06_lv")
    delete!(data["transformer"], "xfmr_10")
    data["load"]["ss06"]["bus"] = "ss06"

    delete!(data["bus"], "t07_lv")
    delete!(data["transformer"], "xfmr_11")
    data["load"]["t07"]["bus"] = "t07"

    delete!(data["bus"], "ss22_lv")
    delete!(data["transformer"], "xfmr_20")
    data["load"]["ss22"]["bus"] = "ss22"

    delete!(data["bus"], "ss23_lv")
    delete!(data["transformer"], "xfmr_21")
    data["load"]["ss23"]["bus"] = "ss23"

    delete!(data["bus"], "tx4_lv")
    delete!(data["transformer"], "xfmr_3")
    data["generator"]["wind2"]["bus"] = "tx4"

    delete!(data["bus"], "rmu1_lv")
    delete!(data["transformer"], "xfmr_0")
    data["generator"]["solar2"]["bus"] = "rmu1"
end

function dss2dsse_data_pipeline(ntw_eng::Dict)::Dict   
    adjust_some_meas_location!(ntw_eng) # some generators/loads are connected to the lv side in the dictionary, but the measurement is on the MV side! this fixes this discrepancy and removes the transfo
    add_loads_for_measured_ss!(ntw_eng)
    delete_transfo_where_no_meas!(ntw_eng)
    math = _PMD.transform_data_model(ntw_eng)
    #rm_voltage_source!(math)  
    adjust_gen_data!(math) # makes it such that the generators are not assigned to frequencydroop control and PV buses
    adjust_load_gen_names!(math) #adjusts the names of the gens in the math Dict to make them match the big measurements csv file
    return math
end
"""
to be used with the new master_dsse.dss from september 2022
This function 1) adjusts some tap settings
              2) changes some generators settings, such that they just behave as negative loads and not as PV buses or weird stuff
              3) allows generators to have negative injection (i.e., behave as loads).
                 For instance, the storage does charge so that's needed.
"""
function new_dss2dsse_data_pipeline(ntw_eng::Dict; limit_demand::Bool=false, limit_bus::Bool=false)::Dict  
    # ntw_eng["transformer"]["xfmr_4"]["tm_set"] = [[1.0, 1.0, 1.0], [1.0625, 1.0625,1.0625]]
    # ntw_eng["transformer"]["xfmr_15"]["tm_set"] = [[1.0, 1.0, 1.0], [1.0625, 1.0625,1.0625]]
    # ntw_eng["transformer"]["xfmr_16"]["tm_set"] = [[1.0, 1.0, 1.0], [1.0625, 1.0625,1.0625]]
    #ntw_eng["transformer"]["xfmr_29"]["tm_set"] = [[1.0, 1.0, 1.0], [1.0625, 1.0625,1.0625]]
    #ntw_eng["transformer"]["xfmr_29"]["tm_set"] = [[1.0, 1.0, 1.0], [1.03125, 1.03125,1.03125]] #load ss29
    
    math = _PMD.transform_data_model(ntw_eng)
    adjust_gen_data!(math) 

    for (_,gen) in math["gen"]
        gen["pmin"] = [-0.1, -0.1, -0.1] # the storage can have negative power!
        gen["qmin"] = [-0.1, -0.1, -0.1]
    end
    if limit_demand
        for (_,load) in math["load"] # to limit the power "guess" at non-monitored loads
            load["pmin"] = [-1., -1., -1.] 
            load["pmax"] = [1., 1., 1.]
            load["qmin"] = [-1., -1., -1.] 
            load["qmax"] = [1., 1., 1.]
        end
    end
    if limit_bus
        for (_,bus) in math["bus"] # to limit the power "guess" at non-monitored loads
            bus["vmin"] = [0.5, 0.5, 0.5] 
            bus["vmax"] = [1.5, 1.5, 1.5]
        end
    end
    return math
end
"""
As of Sept. 2022, that ss17 substation has really bad measurements, that cause high residuals 
both there and elsewhere. This gets rid of those measurements
"""
function delete_ss17_meas!(math::Dict)
    ss17_bus = [load["load_bus"] for (l,load) in math["load"] if load["name"] == "ss17"][1]
    for (m,meas) in math["meas"]
        if (meas["var"] == :vm && meas["cmp_id"] == ss17_bus) || (meas["cmp"] == :load && meas["name"][1] == "ss17")
            delete!(math["meas"], m)
        end
    end
end