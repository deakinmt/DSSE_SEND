import Pkg
Pkg.activate("..") # use the environment in DSSE_SEND/examples

import DSSE_SEND as _DS
import CSV, DataFrames
import Dates, Ipopt

include("utils.jl")

ntw  = _DS.default_network_parser(;adjust_tap_settings=true)

p_load = CSV.read("state_estimation_and_load_flow_day//xmpl_load_flow_lds_W_p.csv") 
q_load = CSV.read("state_estimation_and_load_flow_day//xmpl_load_flow_lds_VAr_q.csv") 

p_gen = CSV.read("state_estimation_and_load_flow_day//xmpl_load_flow_gen_kW_p.csv") 
q_gen = CSV.read("state_estimation_and_load_flow_day//xmpl_load_flow_gen_kVAr_q.csv") 

#volts = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_voltages_volts.csv")
volts = CSV.read(raw"C:\Users\mvanin\.julia\dev\DSSE_SEND\examples\vm_pf_pmd_pf.csv")

i_df_load = CSV.read("state_estimation_and_load_flow_day//xmpl_load_current_A.csv")
i_df_gen = CSV.read("state_estimation_and_load_flow_day//xmpl_gen_current_A.csv")

result_cols = vcat("max_err", "termination_status", "solve_time", "objective",names(volts)) 

ntw["se_settings"] = Dict("rescaler" => 1e3, "criterion" => "rwlav")

_DS.assign_voltage_bounds!(ntw , vmin=0.8, vmax=1.3)

option1 = Dict("power" => "per_phase", "voltage" => "phase", "full_meas_set" => true, "add_error"=>false)
option2 = Dict("power" => "aggregated", "voltage" => "phase", "full_meas_set" => true, "add_error"=>false)
option3 = Dict("power" => "per_phase", "voltage" => "line", "full_meas_set" => true, "add_error"=>false)
option4 = Dict("power" => "aggregated", "voltage" => "line", "full_meas_set" => true, "add_error"=>false)
option5 = Dict("power" => "aggregated", "voltage" => "line", "full_meas_set" => false, "add_error"=>false)
# option 6 is with the actual measurements, done separately

paper_cs1 = Dict("power" => "per_phase", "voltage" => "phase", "full_meas_set" => true, "add_error"=>true, "add_offset" => false)
paper_cs2 = Dict("power" => "per_phase", "voltage" => "phase", "full_meas_set" => true, "add_error"=>true, "add_offset" => true)
paper_cs3 = Dict("power" => "per_phase", "voltage" => "phase", "full_meas_set" => true, "add_error"=>false, "add_offset" => true)

max_err = 0.01

for (opt, optstring) in zip([paper_cs1, paper_cs2], ["paper_cs1", "paper_cs2"])# (opt, optstring) in zip([option1, option2, option3, option4, option5], ["opt1", "opt2", "opt3", "opt4", "opt5"])
    result_vm_df = DataFrames.DataFrame([name => [] for name in result_cols])
    result_vd_df = DataFrames.DataFrame([name => [] for name in result_cols])
    result_va_df = DataFrames.DataFrame([name => [] for name in result_cols])
    for row_idx in 1:size(p_gen)[1]
        add_measurements_se_day!(opt, ntw, row_idx, p_load, q_load, p_gen, q_gen, volts, i_df_load, i_df_gen)
        if opt["add_offset"]
            add_offset_at_source_bus!(ntw, .005)
        end
        se_sol  = _DS.solve_acr_mc_se(ntw, Ipopt.Optimizer)
        _DS.post_process_dsse_solution!(se_sol)
        result_line_vm = [max_err, se_sol["termination_status"], se_sol["solve_time"],se_sol["objective"], p_gen[row_idx, "IsoDatetime"]]
        result_line_va = [max_err, se_sol["termination_status"], se_sol["solve_time"],se_sol["objective"], p_gen[row_idx, "IsoDatetime"]]
        result_line_vd = [max_err, se_sol["termination_status"], se_sol["solve_time"],se_sol["objective"], p_gen[row_idx, "IsoDatetime"]]
        for r in 5:3:length(result_cols)
            for (b, bus) in ntw["bus"]
                if bus["name"] == lowercase(result_cols[r][1:end-2])
                    push!(result_line_vm, se_sol["solution"]["bus"][b]["vm"])
                    push!(result_line_vd, se_sol["solution"]["bus"][b]["vd"])
                    push!(result_line_va, se_sol["solution"]["bus"][b]["va"])
                end
            end
        end
        push!(result_vm_df, vcat(result_line_vm...))
        push!(result_vd_df, vcat(result_line_vd...))
        push!(result_va_df, vcat(result_line_va...))
    end
    CSV.write("vm_se_pu_$(optstring)_auto_error_$(opt["add_error"])_frompmd.csv", result_vm_df)
    CSV.write("vd_se_pu_$(optstring)_auto_error_$(opt["add_error"])_frompmd.csv", result_vd_df)
    CSV.write("va_se_pu_$(optstring)_auto_error_$(opt["add_error"])_frompmd.csv", result_va_df)
end