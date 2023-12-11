##############################################################
#
# This script takes "synthetic" P and Q: missing and NaN values are replaced/allocated as described in the paper 
# and aggregated P and Q are allocated over the three phases
# Power flows are run with PowerModelsDistribution.
# The generated (error-less/ground-truth) voltages could be used as reference/input for synthetic DSSE
#
##############################################################

import PowerModelsDistribution
import CSV, DataFrames
import Dates, Ipopt

include("utils.jl")

ntw  = _DS.default_network_parser(;adjust_tap_settings=true) # get network data from .dss files

# get the synthetic power data (they stem from the measurements, but all missing/NaN values are removed and replaced 
# by the allocation of the differences between demand and generation, see paper)
p_load = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/lds_W_p.csv"))
q_load = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/lds_VAr_q.csv"))
p_gen = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/gen_kW_p.csv"))
q_gen = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/gen_kVAr_q.csv")) 

# get voltages at the voltage source, for the slack bus of the power flow
volts = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/srcv_pu.csv"))

# initialize column names of result dataframe
result_cols = names(CSV.read("state_estimation_and_load_flow_day//xmpl_load_flow_voltages_volts.csv"))

_DS.assign_voltage_bounds!(ntw , vmin=0.8, vmax=1.3) # add voltage bounds to DSSE

# initialize result dataframes
result_pmd_vm_pf = DataFrames.DataFrame([name => [] for name in result_cols]) # stores phase voltage magnitudes
result_pmd_vd_pf = DataFrames.DataFrame([name => [] for name in result_cols]) # stores line voltage magnitudes
result_pmd_va_pf = DataFrames.DataFrame([name => [] for name in result_cols]) # stores voltage angles

for row_idx in 1:size(p_gen)[1] # for every time step (for which we have generation)
    assign_powerflow_input!(ntw, row_idx, p_load, q_load, p_gen, q_gen, volts) # assign the synthetic input for the power flows
    pf_sol  = _PMD.solve_mc_pf(ntw, _PMD.ACRUPowerModel, Ipopt.Optimizer) # run power flow
    _DS.post_process_dsse_solution!(pf_sol) # format power flow solution (same function as for DSSE, hence the name)
    # format the solution so that it can be added as a row to the appropriate dataframe
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
# to save as csv file, uncomment the below
# CSV.write("vm_pf_2022_9_17.csv", result_pmd_vm_pf)
# CSV.write("vd_pf_2022_9_17.csv", result_pmd_vd_pf)
# CSV.write("va_pf_2022_9_17.csv", result_pmd_va_pf)