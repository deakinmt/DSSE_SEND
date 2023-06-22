import Pkg
Pkg.activate("..") # use the environment in DSSE_SEND/examples

import DSSE_SEND as _DS
import CSV
import Dates, Ipopt, StatsPlots

include("linear_model_utils.jl")

A,b,vbase,v_idx,p_idx, x0 = get_Abvvpx_mv()

x′ = build_xprime(p_idx)

V⁺ = build_Vplus(v_idx) # 1.1 for LV, 1.06 for MV
v_res = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/curtailment_modelling/vm_se_pu_paper_cs1_2022_5_13.csv"))

pgi_t = []
for row_idx in 1:size(v_res)[1] 
    b_t = build_b_from_se_results(v_res, v_idx, vbase, row_idx)
    pgi = []
    for i in 1:length(V⁺)
        push!(pgi, (V⁺[i]*vbase[i]-b_t[i])/((A*x′)[i])) # in watts
    end
    push!(pgi_t, minimum(pgi))
end

pick_date = ["2022_5_13", "2022_9_17", "2022_7_15"][1]

solarmod = CSV.read(raw"../twin_data\curtailment_modelling\solar_model.csv")
curt = CSV.read(raw"../twin_data\curtailment_modelling\solar_curt_model.csv")
pgi_t_zeroed = [solarmod[pick_date][(i-1)*10+1] == 0 ? 0. : p for (i,p) in enumerate(pgi_t)
                ]

StatsPlots.plot(solarmod[pick_date][1:10:end], label = "Solar model")
StatsPlots.plot!(curt[pick_date][1:10:end], label = "Curtailment model")
StatsPlots.plot!(pgi_t_zeroed/1e6, label = "p*", ylabel = "Power [MW]")
StatsPlots.plot!(title=pick_date)