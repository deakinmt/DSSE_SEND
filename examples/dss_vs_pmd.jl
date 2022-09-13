import DSSE_SEND as _DS
import Ipopt
import PowerModelsDistribution as _PMD
import CSV, DataFrames

ntw_eng = _DS.parse_send_ntw_eng() # get the ENGINEERING network data dictionary
_DS.quickplot_send_network(ntw_eng) # quickly plots the network

ntw_eng["generator"] = Dict{String, Any}()

for (l,load) in ntw_eng["load"]
    # if haskey(ntw_eng["load"][l], "control_mode")
    #     bus = load["bus"]
    #     ntw_eng["load"][l] = ntw_eng["load"]["ss14"]
    #     ntw_eng["load"][l]["bus"] = bus
    # end
    load["pd_nom"] = [0.0,0.0,0.0]
    load["qd_nom"] = [0.0,0.0,0.0]
end

pf_sol = _PMD.solve_mc_pf(ntw_eng, _PMD.ACRUPowerModel, Ipopt.Optimizer)

bus_ids = []
vm = []
for (b,bus) in pf_sol["solution"]["bus"]
    push!(bus_ids,b)
    push!(vm, sqrt.(bus["vr"].^2+bus["vi"].^2)[1])
end

CSV.write("powerflow_result_fullload_nogen.csv", DataFrames.DataFrame(bus_id = bus_ids, vm=vm ))

perunitization = Dict("sourcebus" => 78.74, )

#########################################
############ ALL ATTEMPTS ###############
#########################################

ntw_eng = _DS.parse_send_ntw_eng(joinpath(_DS.BASE_DIR, "matts_files/send_network_220812/master_220817.dss")) # get the ENGINEERING network data dictionary

ntw_eng["generator"] = Dict{String, Any}()

pf_sol = _PMD.solve_mc_pf(ntw_eng, _PMD.ACRUPowerModel, _PMD.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-12))

bus_ids = []
vm = []
for (b,bus) in pf_sol["solution"]["bus"]
    push!(bus_ids,b)
    push!(vm, sqrt.(bus["vr"].^2+bus["vi"].^2)[1])
end

CSV.write("220817_pf_result_fullload_nogen_noloadloss.csv", DataFrames.DataFrame(bus_id = bus_ids, vm=vm ))

for (l,load) in ntw_eng["load"]
    load["pd_nom"] = [0.0,0.0,0.0]
    load["qd_nom"] = [0.0,0.0,0.0]
end

pf_sol = _PMD.solve_mc_pf(ntw_eng, _PMD.ACRUPowerModel, Ipopt.Optimizer)

bus_ids = []
vm = []
for (b,bus) in pf_sol["solution"]["bus"]
    push!(bus_ids,b)
    push!(vm, sqrt.(bus["vr"].^2+bus["vi"].^2)[1])
end

CSV.write("220817_pf_result_zeroload_nogen_noloadloss.csv", DataFrames.DataFrame(bus_id = bus_ids, vm=vm ))
