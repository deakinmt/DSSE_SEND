import Pkg
Pkg.activate("..") # use the environment in DSSE_SEND/examples

import DSSE_SEND as _DS
import CSV
import Dates, Ipopt

include("linear_model_utils.jl")

A,b,vbase,v_idx,p_idx, x0 = get_Abvvpx()

x1 = build_x0_synt(p_idx, 1) # ask matt: just remove this functionality altogether both for the measurement and the synthetic case?
                             # how do we incorporate Matt's generated x0 to this workflow?


v_res = CSV.read(joinpath(_DS.BASE_DIR, "examples/results_and_plots/vm_se_pu_paper_cs1_auto_error_true_frompmd.csv"))

for row_idx in 1:size(v_res)[1] # do eachrow instead if it fits the integration with Matt's b
    b_t = build_b_from_se_results(v_res, v_idx, vbase, row_idx)
end

pp = perturb_powers(x1, pperc)
vp = (A*x1+b1)./vbase

cols = vcat("timestep", "termination_status", "objective", 
            [name*"_p1" for name in unique(meas_names)], [name*"_p2" for name in unique(meas_names)], [name*"_p3" for name in unique(meas_names)])

# perturbation percentage 
pperc = 1.01

