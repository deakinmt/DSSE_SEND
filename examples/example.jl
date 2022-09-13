import DSSE_SEND as _DS
import Ipopt
import PowerModelsDistribution as _PMD #<-- TODO: remove by import+export in _DS
import CSV, DataFrames, Dates

ntw_eng = _DS.parse_send_new_ntw_eng() # get the ENGINEERING network data dictionary
math = _DS.new_dss2dsse_data_pipeline(ntw_eng)
#_DS.quickplot_send_network(math) # quickly plots the network

# choose time step for the state estimation
time_step = Dates.DateTime(2022,08,12, 00, 04, 30)
# choose aggregation, must be multiple of 30 seconds!
aggregation = Dates.Minute(2)

_DS.add_measurements!(time_step, math, aggregation) # add P,Q,V measurements for loads and generators
_DS.add_ss13_2_meas!(time_step, math, aggregation)

# choose settings of the state estimator
math["se_settings"] = Dict("rescaler"=>1e3, "criterion"=>"rwlav")

se_sol = _DS.solve_acr_mc_se(math, Ipopt.Optimizer) #todo: import ivr formulation!
for (b,bus) in se_sol["solution"]["bus"]
    bus["vm"] = sqrt.(bus["vr"].^2+bus["vi"].^2)
end

ρ = _DS.get_voltage_residuals_onets(math, se_sol)
p = _DS.plot_voltage_residuals_onets(ρ)

ρₚ = _DS.get_power_residuals_onets(math, se_sol)

################################ trying to make the above better

# step 1: delete the ss17 measurements!

ntw_eng = _DS.parse_send_new_ntw_eng()
nu_eng = deepcopy(ntw_eng)
nu_eng["transformer"]["xfmr_4"]["tm_set"] = [[1.0, 1.0, 1.0], [1.0625, 1.0625,1.0625]]
nu_eng["transformer"]["xfmr_15"]["tm_set"] = [[1.0, 1.0, 1.0], [1.0625, 1.0625,1.0625]]
nu_eng["transformer"]["xfmr_16"]["tm_set"] = [[1.0, 1.0, 1.0], [1.0625, 1.0625,1.0625]]
math = _DS.new_dss2dsse_data_pipeline(nu_eng)

# choose time step for the state estimation
time_step = Dates.DateTime(2022,08,12, 00, 04, 30)
# choose aggregation, must be multiple of 30 seconds!
aggregation = Dates.Minute(2)

_DS.add_measurements!(time_step, math, aggregation)
_DS.add_ss13_2_meas!(time_step, math, aggregation)

# choose settings of the state estimator
math["se_settings"] = Dict("rescaler"=>1e3, "criterion"=>"rwlav")

#delete measurements for ss17
_DS.delete_ss17_meas!(math)

se_sol = _DS.solve_acr_mc_se(math, Ipopt.Optimizer)
for (b,bus) in se_sol["solution"]["bus"]
    bus["vm"] = sqrt.(bus["vr"].^2+bus["vi"].^2)
end

ρ = _DS.get_voltage_residuals_onets(math, se_sol)
p = _DS.plot_voltage_residuals_onets(ρ)

ρₚ = _DS.get_power_residuals_onets(math, se_sol)

a, b = _DS.run_dsse_multiple_ts(math, time_step:Dates.Minute(2):time_step+Dates.Minute(20), aggregation, Ipopt)

# notes for Matt:
# -ss33, ss26, ss27, ss28 moved to MV, removed transfo
