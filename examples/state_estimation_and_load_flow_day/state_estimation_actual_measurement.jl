##############################################################
#
# This script runs state estimation with the SEND measurements
# with or without aggregated powers (disaggregating them = hack).
# A csv file with measurement residuals is created 
#
##############################################################

import Pkg
Pkg.activate("..") # use the environment in DSSE_SEND/examples

import DSSE_SEND as _DS
import CSV, DataFrames
import Dates, Ipopt

include("utils.jl")

ntw  = _DS.default_network_parser(;adjust_tap_settings=true)
_DS.assign_se_settings!(ntw)

p_gen = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_gen_kW_p.csv") 
q_gen = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_gen_kVAr_q.csv") 

volts = CSV.read(raw"C:\Users\mvanin\.julia\dev\DSSE_SEND\examples\vd_pf_pmd_pf.csv")

result_cols = vcat("max_err", "termination_status", "solve_time", "objective",names(volts)) 

ntw["se_settings"] = Dict("rescaler" => 1e3, "criterion" => "rwlav")

_DS.assign_voltage_bounds!(ntw , vmin=0.8, vmax=1.3)

result_vm_df = DataFrames.DataFrame([name => [] for name in result_cols])
result_vd_df = DataFrames.DataFrame([name => [] for name in result_cols])
result_va_df = DataFrames.DataFrame([name => [] for name in result_cols])

time_step_begin = Dates.DateTime(2022, 07, 15, 00, 00, 00)
time_step_end = Dates.DateTime(2022, 07, 15, 23, 55, 00)
time_step_step = Dates.Minute(5)
aggregation = time_step_step

exclude = ["ss02", "ss17"]
_DS.add_measurements!(time_step_begin, ntw , aggregation, exclude = exclude, add_ss13=true, aggregate_power=true) # this is just to initialize the result dataframe
meas_names = [meas["name"] isa Vector ? meas["name"][1] : meas["name"] for (_,meas) in ntw["meas"]]

max_err = 0.0

cols = vcat("timestep", "termination_status", "objective", 
            [name*"_p1" for name in unique(meas_names)], [name*"_p2" for name in unique(meas_names)], [name*"_p3" for name in unique(meas_names)])

residual_df  = DataFrames.DataFrame([name => [] for name in cols])

aggregate_power = true

for row_idx in 1:size(p_gen)[1] # 87:size(p_gen)[1]

    _DS.add_measurements!(p_gen[row_idx, :IsoDatetime], ntw , aggregation, exclude = exclude, add_ss13=true, aggregate_power=aggregate_power) 
    if aggregate_power _DS.aggregate_source_gen_meas!(ntw) end
    se_sol  = _DS.solve_acr_mc_se(ntw, Ipopt.Optimizer)
    _DS.post_process_dsse_solution!(se_sol)

    ρ  = _DS.get_voltage_residuals_one_ts(ntw , se_sol, in_volts=false)

    res_line   = vcat(p_gen[row_idx, :IsoDatetime], se_sol["termination_status"] , se_sol["objective"] , vcat([ρ[c][1] for c in unique(meas_names)]...), 
                                                                                 vcat([ρ[c][2] for c in unique(meas_names)]...), 
                                                                                 vcat([ρ[c][3] for c in unique(meas_names)]...))

    push!(residual_df , res_line)
end
CSV.write("actual_meas_aggr_power.csv", residual_df)
