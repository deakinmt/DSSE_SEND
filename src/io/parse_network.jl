"""
    parse_send_ntw_eng()::Dict

Accesses the send network's dss files and parses them to a PowerModelsDistribution `ENGINEERING` data model
"""
parse_send_ntw_eng()::Dict =
 _PMD.parse_file(joinpath(_DS.BASE_DIR, "matts_files/send_network_220812/master.dss"), data_model=_PMD.ENGINEERING)
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
 _PMD.parse_file(joinpath(_DS.BASE_DIR, "matts_files/send_network_220812/master.dss"), data_model=_PMD.MATHEMATICAL)
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
        if !occursin("voltage_source", gen["name"])
            gen["control_mode"] = _PMD.ISOCHRONOUS
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
        elseif gen["name"] == "_virtual_gen.voltage_source.source"
            gen["name"] = "ss13_1" # TO CHECK HOW TO HANDLE THIS???
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
the one below does not remove the voltage source though, not sure how to do that.
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