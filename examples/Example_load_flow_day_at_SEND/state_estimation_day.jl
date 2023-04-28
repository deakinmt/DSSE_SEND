import Pkg
Pkg.activate("..") # use the environment in DSSE_SEND/examples

import DSSE_SEND as _DS
import CSV, DataFrames
import Dates, Ipopt

include("utils.jl")

ntw  = _DS.default_network_parser(;adjust_tap_settings=true)

p_load = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_lds_W_p.csv") 
q_load = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_lds_VAr_q.csv") 

p_gen = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_gen_kW_p.csv") 
q_gen = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_gen_kVAr_q.csv") 

volts = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_voltages_volts.csv")

max_err = 0.0001 #assign a max error of 1% to all measurements

result_cols = vcat("max_err", "termination_status", "objective",names(volts)) 

result_df = DataFrames.DataFrame([name => [] for name in result_cols])

ntw["se_settings"] = Dict("rescaler" => 1e3, "criterion" => "rwlav")

_DS.assign_voltage_bounds!(ntw , vmin=0.8, vmax=1.3)

for row_idx in 1:size(p_gen)[1]
    add_measurements_se_day_old_ntw!(ntw, max_err, row_idx, p_load, q_load, p_gen, q_gen, volts)
    se_sol  = _DS.solve_acr_mc_se(ntw, Ipopt.Optimizer)
    _DS.post_process_dsse_solution!(se_sol)

    result_line = [max_err, se_sol["termination_status"], se_sol["objective"], p_gen[row_idx, "IsoDatetime"]]
    for r in 5:3:length(result_cols)
        for (b, bus) in ntw["bus"]
            if bus["name"] == lowercase(result_cols[r][1:end-2])
                push!(result_line, se_sol["solution"]["bus"][b]["vm"])
            end
        end
    end
    push!(result_df, vcat(result_line...))
end
