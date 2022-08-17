import DSSE_SEND as _DS
import Ipopt
import PowerModelsDistribution as _PMD
import CSV, DataFrames

ntw_eng = _DS.parse_send_ntw_eng() # get the ENGINEERING network data dictionary
_DS.quickplot_send_network(ntw_eng) # quickly plots the network

pf_sol = _PMD.solve_mc_pf(ntw_eng, _PMD.ACRUPowerModel, Ipopt.Optimizer)

bus_ids = []
vm = []
for (b,bus) in pf_sol["solution"]["bus"]
    push!(bus_ids,b)
    push!(vm, bus["vm"][1])#bus["vm"] = sqrt.(bus["vr"].^2+bus["vi"].^2)
end

CSV.write("powerflow_result.csv", DataFrames.DataFrame(bus_id = bus_ids, vm=vm ))