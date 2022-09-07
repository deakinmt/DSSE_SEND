function run_dsse_multiple_ts(math::Dict, timerange::StepRange{Dates.DateTime, T}, aggregation::Dates.TimePeriod, solver::Module; rescaler::Float64=1e3, criterion::String="rwlav") where T <: Dates.TimePeriod
    @assert timerange.step >= aggregation "You are using a timerange whose step is smaller than the aggregation level. This is probably wrong."
    math["se_settings"] = Dict("rescaler"=>rescaler, "criterion"=>criterion)
    #delete measurements for ss17

    ρ_ts = Dict{String, Any}()
    diagnose_se = Dict{String, Any}()
    for time_step in timerange
        add_measurements!(time_step, math, aggregation)
        add_ss13_2_meas!(time_step, math, aggregation)
        for m in ["13","14","15"] delete!(math["meas"], m) end
        se_sol = solve_acr_mc_se(math, solver.Optimizer)
        for (b,bus) in se_sol["solution"]["bus"]
            bus["vm"] = sqrt.(bus["vr"].^2+bus["vi"].^2)
        end
        ρ_ts[string(time_step)] = get_voltage_residuals_onets(math, se_sol)
        diagnose_se[string(time_step)] = Dict("solve_time" => se_sol["solve_time"], 
                                        "termination_status"=>se_sol["termination_status"], "objective"=>se_sol["objective"], 
                                        "resc"=>rescaler, "crit"=>criterion, "aggr" => aggregation)
    end
    return ρ_ts, diagnose_se
end