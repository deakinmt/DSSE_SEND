import DSSE_SEND as _DS
import Ipopt
import PowerModelsDistribution as _PMD #<-- TODO: remove by import+export in _DS
import CSV, DataFrames, Dates

# the one below parses the ntw data from 12/09.
ntw_eng = _DS.parse_send_new_ntw_eng() 
# alternatively, call parse_send_ntw_eng(pth::String) where pth is the path to master.dss

math = _DS.new_dss2dsse_data_pipeline(ntw_eng; limit_demand=false, limit_bus=true)

# set time range and aggregation for the state estimation calculations
# a state estimation is run every `time_step_step` timestamps starting from
# `time_step_begin` to `time_step_end`
# the aggregation must be a multiple of 30 seconds and allows you to average
# the measurement values of the `aggregation` time steps, instead of using the
# instantaneous 30" measurements. This should avoid some errors due to loss of
# sync between different measurements. If aggregation is 30", then the inst. 
# values are taken instead (i.e., nothing is really aggregated).
# aggregation and time_step_step don't have to be equal

chosen_day = Dates.Date(2022, 05, 13)#NB: this should match the time_steps below!

time_step_begin = Dates.DateTime(2022, 05, 13, 00, 14, 30)
time_step_end = time_step_begin+Dates.Minute(2)
time_step_step = Dates.Minute(2)
aggregation = time_step_step

plots_pu = [] # initialize plots in per unit array
plots_v = [] # initialize plots in volts array

for ts in time_step_begin:time_step_step:time_step_end

    day_string = "_$(string(Dates.Month(chosen_day))[1])_$(string(Dates.Day(chosen_day))[1:2])" 
    _DS.add_measurements!(day_string, ts, math, aggregation) # adds P,Q,|U| measurements for all gens/loads that have them
    _DS.add_ss13_2_meas!(day_string, ts, math, aggregation) # adds only the voltage of ss13_2 (not a substation but a node)
    _DS.hack_ss19!(math) # one of the voltages of ss19 is flat. this hacky function replace that measurement with a better guess
    _DS.delete_ss17_meas!(math) # ss17 measurements' are flat lines. just remove them

    # choose settings of the state estimator:
    # criterion should be rwlav or wls/rwls
    # the rescaler should not affect the results (unless it's so high or low that you break ipopt), 
    # but affects convergence speed. Normally if > 1, speed should improve
    math["se_settings"] = Dict("rescaler"=>1e3, "criterion"=>"rwlav")

    # just runs SE for the current timestep 
    se_sol = _DS.solve_acr_mc_se(math, Ipopt.Optimizer)

    # adds voltage magnitude to the bus result dictionary
    # pmd does not do it by default because because we are using the ACR formulation
    for (b,bus) in se_sol["solution"]["bus"]
        bus["vm"] = sqrt.(bus["vr"].^2+bus["vi"].^2)
    end

    # gets the voltage residuals
    ρ = _DS.get_voltage_residuals_one_ts(math, se_sol, in_volts=false)
    p = _DS.plot_voltage_residuals_one_ts(ρ, in_volts=false, title="ts.: $(string(ts)[6:end]), aggr.: $aggregation")
    ρ_v = _DS.get_voltage_residuals_one_ts(math, se_sol)
    p_v = _DS.plot_voltage_residuals_one_ts(ρ_v, title="ts.: $(string(ts)[6:end]), aggr.: $aggregation")

    push!(plots_pu, p)
    push!(plots_v, p_v)
end

# as an alternative to the for loop above, you can also just call this function
# as a result from the for loop above you get a plot for every time step, with
# the one below you get them "cumulatively" (boxplots).
# the nice about the one below is that is also returns a dictionary for you to
# inspect the SE results for convergence issues, etc. (this is dict. `dgn` below)
res, vals, dgn = _DS.run_dsse_multi_ts(math, time_step_begin:time_step_step:time_step_end, aggregation, Ipopt)

# this plots one boxplot per phase, call them as pltz[1], pltz[2], pltz[3]
pltz_v = _DS.plot_voltage_residuals_multi_ts(res, in_volts=true, title="ts: $(string(time_step_begin)[6:end]) to $(string(time_step_end)[6:end]), agg: $(aggregation), step:$time_step_step") 
pltz_p = _DS.plot_power_residuals_multi_ts(res, p_or_q="p", in_kw=true) 
pltz_q = _DS.plot_power_residuals_multi_ts(res, p_or_q="q", in_kw=true) 

#you can also plot the total power residual, i.e., sum of the three phases
pltz_p = _DS.plot_power_residuals_multi_ts(res, p_or_q="p", in_kw=true, per_phase=false) 

# you can always plot the voltage residuals separately (per time step) as follows
# sorry I don't have one equivalent for the power. but also not sure it's useful
p_v = _DS.plot_voltage_residuals_one_ts(res_v["2022-08-12T00:30:30"]["V"])

# and you can plot timeseries for a chosen substation and quantity among "v", "p", and "q"
# again you get three plots, one per phase
p = _DS.plot_timeseries(res, vals, "v", "ss19", time_step_begin:time_step_step:time_step_end)

StatsPlots.plot()
for id in unique(df.Id)
    dff = filter(x->x.Id == id, df)
    StatsPlots.plot!(dff.v1, label="$id")
end
p