##############################################################
#
# This script runs state estimation with the synthetic measurements, i.e., 
# measurements created by the user by adding noise on the ground truth 
# (power flow results).
# Several options are created by additionally manipulating the ground truth output,
# e.g., aggregating three-phase power measurements instead of using the per-phase value.
# 
##############################################################

import DSSE_SEND as _DS
import Dates, Ipopt, CSV, DataFrames

include("utils.jl")

ntw  = _DS.default_network_parser(;adjust_tap_settings=true) # parse network data
_DS.assign_voltage_bounds!(ntw , vmin=0.8, vmax=1.3) # assign upper/lower bus voltage bounds  
ntw["se_settings"] = Dict("rescaler" => 1e3, "criterion" => "rwlav") # add state estimation settings

# get ground truth demand, generation and voltages, stemming from a power flow 
p_load = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/lds_W_p.csv"))
q_load = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/lds_VAr_q.csv"))
p_gen = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/gen_kW_p.csv"))
q_gen = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/gen_kVAr_q.csv")) 
volts = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/vm_pf.csv"))
i_df_load = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/load_current_A.csv"))
i_df_gen = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/gen_current_A.csv"))

result_cols = names(volts) # initialize name of columns for result DataFrame
result_cols = vcat("max_err", "termination_status", "solve_time", "objective",names(volts))  # initialize name of columns for result DataFrame

# different options can be added to the ground truth, resulting in different synthetic measurement settings
# the ideal case is: 
# - power measurements are per-phase ("power" => "per_phase" in the dictionary)
# - voltage measurements are phase voltages as opposed to line voltages ("voltage" => "phase")
# - the full measurement set is used/all users are measured ("full_meas_set" => true)
# - no noise / error is added to the ground truth, i.e., measurements are perfect ("add_error"=>false)
# - no voltage measurement offset is added on the network PCC ("add_offset" => false)

# for the results in the paper, we ultimately use the following set of options:
paper_cs = Dict("power" => "per_phase", "voltage" => "phase", "full_meas_set" => true, "add_error"=>true, "add_offset" => false)

index = 1 # legacy parameter added to the dataframe but not actually used in calculations, please ignore

for (opt, optstring) in zip([paper_cs], ["paper_cs"])# to run multiple options could do: (opt, optstring) in zip([option1, option2, option3, option4, option5], ["opt1", "opt2", "opt3", "opt4", "opt5"])

    # initialize result dataframes to store for future use:
    result_vm_df = DataFrames.DataFrame([name => [] for name in result_cols]) # phase voltage magnitude results
    result_vd_df = DataFrames.DataFrame([name => [] for name in result_cols]) # line voltage magnitude results
    result_va_df = DataFrames.DataFrame([name => [] for name in result_cols]) # voltage angle results
    noisy_voltages = DataFrames.DataFrame([name => [] for name in result_cols[5:end]]) # stores voltages + random noise (i.e., the DSSE's voltage measurement inputs)

    # initialize residual dataframe
    res_df = DataFrames.DataFrame([name => Any[] for name in vcat("timestep", volt_meas)])

    for row_idx in 1:nrow(p_gen) # for all the time steps for which we have synthetic generation values
        add_measurements_se_day!(opt, ntw, row_idx, p_load, q_load, p_gen, q_gen, volts, i_df_load, i_df_gen) # add measurements (adding noise to the input ground truth if specified)
        if opt["add_offset"] # add a given offset at source bus, if needed. value here is 0.005 p.u. volts
            add_offset_at_source_bus!(ntw, .005)
        end
        se_sol  = _DS.solve_acr_mc_se(ntw, Ipopt.Optimizer) # run DSSE
        _DS.post_process_dsse_solution!(se_sol) # formatting DSSE solution

        # build results for this timesetp in a "row form" to subsequently add to the dataframes above
        result_line_vm = [index, se_sol["termination_status"], se_sol["solve_time"],se_sol["objective"], p_gen[row_idx, "IsoDatetime"]]
        result_line_va = [index, se_sol["termination_status"], se_sol["solve_time"],se_sol["objective"], p_gen[row_idx, "IsoDatetime"]]
        result_line_vd = [index, se_sol["termination_status"], se_sol["solve_time"],se_sol["objective"], p_gen[row_idx, "IsoDatetime"]]
        result_line_noisyv = Any[p_gen[row_idx, "IsoDatetime"]]
        measured_buses = [meas["name"] for (_, meas) in ntw["meas"] if meas["var"] ∈ [:vm, :vd] ]
        for r in 5:3:length(result_cols)
            skipped = true
            for (b, bus) in ntw["bus"]
                if bus["name"] == lowercase(result_cols[r][1:end-2])
                    push!(result_line_vm, se_sol["solution"]["bus"][b]["vm"])
                    push!(result_line_vd, se_sol["solution"]["bus"][b]["vd"])
                    push!(result_line_va, se_sol["solution"]["bus"][b]["va"])
                    skipped = false
                end
            end
            if !skipped
                if lowercase(result_cols[r][1:end-2]) ∈ measured_buses
                    for (m,meas) in ntw["meas"]
                        if meas["name"] == lowercase(result_cols[r][1:end-2]) && meas["var"] ∈ [:vm, :vd]
                            push!(result_line_noisyv, _DST.mean.(meas["dst"]))
                        end
                    end
                else
                    push!(result_line_noisyv, [1., 1., 1.])
                end
            end
        end
        res_line = calculate_v_residuals(ntw, se_sol, row_idx)
        
        # adds results to data frames
        push!(result_vm_df, vcat(result_line_vm...))
        push!(result_vd_df, vcat(result_line_vd...))
        push!(result_va_df, vcat(result_line_va...))
        push!(noisy_voltages, vcat(result_line_noisyv...))
        push!(res_df, res_line)
    end
    # remove comment to write the results as csv files
    # CSV.write("vm_se_pu_$(optstring)_2022_9_17_nov.csv", result_vm_df)
    # CSV.write("vd_se_pu_$(optstring)_2022_9_17_nov.csv", result_vd_df)
    # CSV.write("va_se_pu_$(optstring)_2022_9_17_nov.csv", result_va_df)
    # CSV.write("noisy_voltages_$(optstring)_2022_9_17_nov.csv", noisy_voltages)
    # CSV.write("residuals_$(optstring)_2022_9_17_nov.csv", res_df)
end


################ HOW TO CREATE THE CURRENT FILES:
## first get the voltages 
# volts = CSV.read(joinpath(_DS.BASE_DIR, "twin_data\\load_allocation_cases\\2022_9_17\\voltages_volts.csv"))
## then run the following
# build_currents_df(volts, p_load, q_load, p_gen, q_gen, ntw, "2022_9_17")
