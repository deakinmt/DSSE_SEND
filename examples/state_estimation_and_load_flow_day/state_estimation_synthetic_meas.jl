import Pkg
Pkg.activate("..") # use the environment in DSSE_SEND/examples

import DSSE_SEND as _DS
using CSV, DataFrames
import Distributions as _DST
import Dates, Ipopt

include("utils.jl")

ntw  = _DS.default_network_parser(;adjust_tap_settings=true)

p_load = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/lds_W_p.csv"))
q_load = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/lds_VAr_q.csv"))

p_gen = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/gen_kW_p.csv"))
q_gen = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/gen_kVAr_q.csv")) 

volts = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/vm_pf.csv"))

result_cols = names(volts)

_DS.assign_voltage_bounds!(ntw , vmin=0.8, vmax=1.3)

i_df_load = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/load_current_A.csv"))
i_df_gen = CSV.read(joinpath(_DS.BASE_DIR, "twin_data/load_allocation_cases/2022_9_17/gen_current_A.csv"))

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

max_err = 0.005

function calculate_v_residuals(ntw, se_sol, timestep)
    volt_meas = [m for (m,meas) in ntw["meas"] if meas["var"] == :vm]
    res_line = Any[timestep]
    for m in volt_meas
        cmp_id = ntw["meas"][m]["cmp_id"]
        meas = _DST.mean.(ntw["meas"][m]["dst"])
        res  = sqrt.(se_sol["solution"]["bus"]["$cmp_id"]["vr"].^2+se_sol["solution"]["bus"]["$cmp_id"]["vi"].^2)         
        push!(res_line, meas.-res)   
    end
    return res_line
end

for (opt, optstring) in zip([paper_cs1], ["paper_cs1"])# (opt, optstring) in zip([option1, option2, option3, option4, option5], ["opt1", "opt2", "opt3", "opt4", "opt5"])
    result_vm_df = DataFrames.DataFrame([name => [] for name in result_cols])
    result_vd_df = DataFrames.DataFrame([name => [] for name in result_cols])
    result_va_df = DataFrames.DataFrame([name => [] for name in result_cols])
    res_df = DataFrames.DataFrame([name => Any[] for name in vcat("timestep", volt_meas)])
    noisy_voltages = DataFrames.DataFrame([name => [] for name in result_cols[5:end]])
    for row_idx in 1:nrow(p_gen)
        add_measurements_se_day!(opt, ntw, row_idx, p_load, q_load, p_gen, q_gen, volts, i_df_load, i_df_gen)
        if opt["add_offset"]
            add_offset_at_source_bus!(ntw, .005)
        end
        se_sol  = _DS.solve_acr_mc_se(ntw, Ipopt.Optimizer)
        _DS.post_process_dsse_solution!(se_sol)
        result_line_vm = [max_err, se_sol["termination_status"], se_sol["solve_time"],se_sol["objective"], p_gen[row_idx, "IsoDatetime"]]
        result_line_va = [max_err, se_sol["termination_status"], se_sol["solve_time"],se_sol["objective"], p_gen[row_idx, "IsoDatetime"]]
        result_line_vd = [max_err, se_sol["termination_status"], se_sol["solve_time"],se_sol["objective"], p_gen[row_idx, "IsoDatetime"]]
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
        push!(result_vm_df, vcat(result_line_vm...))
        push!(result_vd_df, vcat(result_line_vd...))
        push!(result_va_df, vcat(result_line_va...))
        push!(noisy_voltages, vcat(result_line_noisyv...))
        push!(res_df, res_line)
    end
    CSV.write("vm_se_pu_$(optstring)_2022_9_17_nov.csv", result_vm_df)
    CSV.write("vd_se_pu_$(optstring)_2022_9_17_nov.csv", result_vd_df)
    CSV.write("va_se_pu_$(optstring)_2022_9_17_nov.csv", result_va_df)
    CSV.write("noisy_voltages_$(optstring)_2022_9_17_nov.csv", noisy_voltages)
    CSV.write("residuals_$(optstring)_2022_9_17_nov.csv", res_df)
end


################ IF YOU DON'T HAVE THE CURRENT FILES:

# voltz = CSV.read(joinpath(_DS.BASE_DIR, "twin_data\\load_allocation_cases\\2022_9_17\\voltages_volts.csv"))
# build_currents_df(voltz, p_load, q_load, p_gen, q_gen, ntw, "2022_9_17")
