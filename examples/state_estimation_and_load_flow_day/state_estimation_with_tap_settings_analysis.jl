##############################################################
#
# This script runs state estimation with the SEND measurements, 
# for a case with far off tap settings vs one with corrected tap settings
# Disaggregated power measurements are used (which is a bit of a hack, see the paper).
# Residuals with and without corrected taps are reported for comparison.
# 
##############################################################

import Pkg
Pkg.activate("..") # use the environment in DSSE_SEND/examples

import DSSE_SEND as _DS
import Ipopt, Dates
import PowerModelsDistribution as _PMD
import CSV, DataFrames

data_ok  = _DS.default_network_parser(;adjust_tap_settings=true)
data_off = _DS.default_network_parser(;adjust_tap_settings=false)

_DS.assign_se_settings!(data_ok)
_DS.assign_se_settings!(data_off)

_DS.assign_voltage_bounds!(data_ok , vmin=0.5, vmax=1.5)
_DS.assign_voltage_bounds!(data_off, vmin=0.5, vmax=1.5)

time_step_begin = Dates.DateTime(2022, 07, 15, 12, 14, 30)
time_step_end = time_step_begin+Dates.Minute(10)
time_step_step = Dates.Minute(2)
aggregation = time_step_step

exclude = ["ss02", "ss17"]
_DS.add_measurements!(time_step_begin, data_ok , aggregation, exclude = exclude, add_ss13=true) # this is just to initialize the result dataframe
meas_names = [meas["name"] isa Vector ? meas["name"][1] : meas["name"] for (_,meas) in data_ok["meas"]]

cols = vcat("timestep", "termination_status", "objective", 
            [name*"_p1" for name in unique(meas_names)], [name*"_p2" for name in unique(meas_names)], [name*"_p3" for name in unique(meas_names)])

residual_df_ok  = DataFrames.DataFrame([name => [] for name in cols])
residual_df_off = DataFrames.DataFrame([name => [] for name in cols])

for ts in time_step_begin:time_step_step:time_step_end

    _DS.add_measurements!(ts, data_ok , aggregation, exclude = exclude, add_ss13=true) 
    _DS.add_measurements!(ts, data_off, aggregation, exclude = exclude, add_ss13=true) 
    
    se_sol_ok  = _DS.solve_acr_mc_se(data_ok , Ipopt.Optimizer)
    se_sol_off = _DS.solve_acr_mc_se(data_off, Ipopt.Optimizer)

    _DS.post_process_dsse_solution!(se_sol_ok)
    _DS.post_process_dsse_solution!(se_sol_off)

    # gets the voltage residuals in per unit
    ρ_ok  = _DS.get_voltage_residuals_one_ts(data_ok , se_sol_ok , in_volts=false)
    ρ_off = _DS.get_voltage_residuals_one_ts(data_off, se_sol_off, in_volts=false)

    ok_res_line   = vcat(ts, se_sol_ok["termination_status"] , se_sol_ok["objective"] , vcat([ρ_ok[c][1] for c in unique(meas_names)]...), 
                                                                                 vcat([ρ_ok[c][2] for c in unique(meas_names)]...), 
                                                                                 vcat([ρ_ok[c][3] for c in unique(meas_names)]...))

    off_res_line  = vcat(ts, se_sol_off["termination_status"], se_sol_off["objective"], vcat([ρ_off[c][1] for c in unique(meas_names)]...), 
                                                                                 vcat([ρ_off[c][2] for c in unique(meas_names)]...), 
                                                                                 vcat([ρ_off[c][3] for c in unique(meas_names)]...))


    push!(residual_df_ok , ok_res_line)
    push!(residual_df_off, off_res_line)

end

CSV.write("tap_analyses_aggr_$(aggregation)_oktaps.csv", residual_df_ok)
CSV.write("tap_analyses_aggr_$(aggregation)_offtaps.csv", residual_df_off)