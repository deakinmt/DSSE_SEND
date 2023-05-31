##############################################################
#
# This script takes P and Q from a "synthetic" measurement day in July: missing and NaN values are replaced/allocated 
# and aggregated P and Q are allocated over the three phases
# It generates the (error-less/ground-truth) voltages used as a reference for state estimation calculations
# by running power flows from P and Q with PowerModelsDistribution
#
##############################################################

import PowerModelsDistribution
import CSV, DataFrames
import Dates, Ipopt

include("utils.jl")

ntw  = _DS.default_network_parser(;adjust_tap_settings=true)

p_load = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_lds_W_p.csv") 
q_load = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_lds_VAr_q.csv") 

p_gen = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_gen_kW_p.csv") 
q_gen = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_gen_kVAr_q.csv") 

volts = CSV.read("Example_load_flow_day_at_SEND//xmpl_load_flow_voltages_volts.csv")

result_cols = names(volts)

_DS.assign_voltage_bounds!(ntw , vmin=0.8, vmax=1.3)

result_pmd_vm_pf = DataFrames.DataFrame([name => [] for name in result_cols])
result_pmd_vd_pf = DataFrames.DataFrame([name => [] for name in result_cols])
result_pmd_va_pf = DataFrames.DataFrame([name => [] for name in result_cols])

for row_idx in 1:size(p_gen)[1]
    assign_powerflow_input!(ntw, row_idx, p_load, q_load, p_gen, q_gen)
    pf_sol  = _PMD.solve_mc_pf(ntw, _PMD.ACRUPowerModel, Ipopt.Optimizer)
    _DS.post_process_dsse_solution!(pf_sol)
    result_line_vm = Vector{Any}([p_gen[row_idx, "IsoDatetime"]])
    result_line_vd = Vector{Any}([p_gen[row_idx, "IsoDatetime"]])
    result_line_va = Vector{Any}([p_gen[row_idx, "IsoDatetime"]])
    for r in 2:3:length(result_cols)
        for (b, bus) in ntw["bus"]
            if bus["name"] == lowercase(result_cols[r][1:end-2])
                push!(result_line_vm, pf_sol["solution"]["bus"][b]["vm"])
                push!(result_line_vd, pf_sol["solution"]["bus"][b]["vd"])
                push!(result_line_va, pf_sol["solution"]["bus"][b]["va"])
            end
        end
    end
    push!(result_pmd_vm_pf, vcat(result_line_vm...))
    push!(result_pmd_vd_pf, vcat(result_line_vd...))
    push!(result_pmd_va_pf, vcat(result_line_va...))
end
CSV.write("vm_pf_pmd_pf.csv", result_pmd_vm_pf)
CSV.write("vd_pf_pmd_pf.csv", result_pmd_vd_pf)
CSV.write("va_pf_pmd_pf.csv", result_pmd_va_pf)