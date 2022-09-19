function run_dsse_multi_ts(math::Dict, timerange::StepRange{Dates.DateTime, T}, aggregation::Dates.TimePeriod, solver::Module; rescaler::Float64=1e3, criterion::String="rwlav") where T <: Dates.TimePeriod
    @assert timerange.step >= aggregation "You are using a timerange whose step is smaller than the aggregation level. This is probably wrong."
    math["se_settings"] = Dict("rescaler"=>rescaler, "criterion"=>criterion)

    ρ_ts = Dict{String, Any}()
    diagnose_se = Dict{String, Any}()
    vals = Dict{String, Any}()
    for time_step in timerange
        ρ_ts[string(time_step)] = Dict{String, Any}()
        vals[string(time_step)] = Dict{String, Any}()

        add_measurements!(time_step, math, aggregation)
        add_ss13_2_meas!(time_step, math, aggregation)
        hack_ss19!(math) 
        delete_ss17_meas!(math)

        se_sol = solve_acr_mc_se(math, solver.Optimizer)
        for (_,bus) in se_sol["solution"]["bus"]
            bus["vm"] = sqrt.(bus["vr"].^2+bus["vi"].^2)
        end
        ρ_ts[string(time_step)]["V"] = get_voltage_residuals_one_ts(math, se_sol)
        ρ_ts[string(time_step)]["V_pu"] = get_voltage_residuals_one_ts(math, se_sol, in_volts=false)
        ρ_ts[string(time_step)]["power"] = get_power_residuals_one_ts(math, se_sol)
        vals[string(time_step)]["V"] = [bus["vm"]*math["bus"][b]["vbase"]*1000*sqrt(3) for (b, bus) in se_sol["solution"]["bus"]]
        vals[string(time_step)]["V_pu"] = [bus["vm"] for (_, bus) in se_sol["solution"]["bus"]]
        vals[string(time_step)]["power_load"] = se_sol["solution"]["load"]
        vals[string(time_step)]["power_gen"] = se_sol["solution"]["gen"]
        diagnose_se[string(time_step)] = Dict("solve_time" => se_sol["solve_time"], 
                                        "termination_status"=>se_sol["termination_status"], "objective"=>se_sol["objective"], 
                                        "resc"=>rescaler, "crit"=>criterion, "aggr" => aggregation)
    end
    return ρ_ts, vals, diagnose_se
end