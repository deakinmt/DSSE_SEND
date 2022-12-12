import DSSE_SEND as _DS
import Ipopt, Dates
import PowerModelsDistribution as _PMD
import CSV, DataFrames

include("helper_functions.jl")

eng = _DS.parse_send_ntw_eng()  # get the ENGINEERING network data dictionary
math = _DS.new_dss2dsse_data_pipeline(eng; limit_demand=false, limit_bus=true)
### NOTE! the tap setting is set to 1.0 by default in the dss parser

eng_tapfix = deepcopy(eng) 
math_tapfix = _DS.new_dss2dsse_data_pipeline(eng_tapfix; limit_demand=false, limit_bus=true)
update_tap_setting!(eng_tapfix)

chosen_day = Dates.Date(2022, 07, 15)#NB: this should match the time_steps below!

time_step_begin = Dates.DateTime(2022, 07, 15, 00, 14, 30)
time_step_end = time_step_begin+Dates.Minute(2)
time_step_step = Dates.Minute(2)
aggregation = time_step_step

plots_pu = [] # initialize plots in per unit array
plots_v = [] # initialize plots in volts array

ts = time_step_begin

day_string = "_$(string(Dates.Month(chosen_day))[1])_$(string(Dates.Day(chosen_day))[1:2])" 
_DS.add_measurements!(day_string, ts, math, aggregation, exclude = ["ss02"]) #exclude ss02 because measurements are nans
_DS.add_ss13_meas!(day_string, ts, math, aggregation)

math["se_settings"] = Dict("rescaler"=>1e3, "criterion"=>"rwlav")

se_sol = _DS.solve_acr_mc_se(math, Ipopt.Optimizer)