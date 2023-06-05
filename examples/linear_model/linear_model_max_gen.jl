import Pkg
Pkg.activate("..") # use the environment in DSSE_SEND/examples

import DSSE_SEND as _DS
import CSV
import Dates, Ipopt

include("linear_model_utils.jl")

A,b,vbase,v_idx,p_idx, x0 = get_Abvvpx_mv()

x′ = build_xprime(p_idx)

V⁺ = fill(1.06, length(v_idx))
v_res = CSV.read(joinpath(_DS.BASE_DIR, "examples/results_and_plots/vm_se_pu_paper_cs1_auto_error_true_frompmd.csv"))

pgi_t = []
for row_idx in 1:size(v_res)[1] # do eachrow instead if it fits the integration with Matt's b
    b_t = build_b_from_se_results(v_res, v_idx, vbase, row_idx)
    pgi = []
    for i in 1:length(V⁺)
        push!(pgi, (V⁺[i]-b_t[i]/vbase[i])/((A*x′)[i])) # in watts
    end
    push!(pgi_t, minimum(abs.(pgi)))
end

solarmod = CSV.read(raw"../twin_data\curtailment_modelling\solar_model.csv")
curt = CSV.read(raw"../twin_data\curtailment_modelling\solar_curt_model.csv")

plot(solarmod["2022_9_17"][1:10:end], label = "Solar model")
plot!(curt["2022_9_17"][1:10:end], label = "Curtailment model")
plot!(pgi_t/1000, label = "p*")