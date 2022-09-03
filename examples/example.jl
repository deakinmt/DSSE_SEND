import DSSE_SEND as _DS
import Ipopt
import PowerModelsDistribution as _PMD #<-- TODO: remove by import+export in _DS
import CSV, DataFrames # <-- TODO: remove

ntw_eng = _DS.parse_send_ntw_eng() # get the ENGINEERING network data dictionary
_DS.adjust_some_meas_location!(ntw_eng) # some generators/loads are connected to the lv side in the dictionary, but the measurement is on the MV side! this fixes this discrepancy and removes the transfo

_DS.quickplot_send_network(ntw_eng) # quickly plots the network

math = _PMD.transform_data_model(ntw_eng)
_DS.quickplot_send_network(math) # quickly plots the network

_DS.rm_voltage_source!(math)

_DS.adjust_gen_data!(math) # makes it such that the generators are not assigned to frequencydroop control and PV buses
_DS.adjust_load_gen_names!(math) #adjusts the names of the gens in the math Dict to make them match the big measurements csv file

# choose time step for the state estimation
time_step = Dates.DateTime(2022,08,12, 00, 04, 30)
# choose aggregation, must be multiple of 30 seconds!
aggregation = Dates.Minute(2)

_DS.add_measurements!(time_step, math, aggregation)
_DS.add_ss13_2_meas!(time_step, math, aggregation)

# choose settings of the state estimator
math["se_settings"] = Dict("rescaler"=>1e3, "criterion"=>"rwlav")

se_sol = _DS.solve_acr_mc_se(math, Ipopt.Optimizer)
for (b,bus) in se_sol["solution"]["bus"]
    bus["vm"] = sqrt.(bus["vr"].^2+bus["vi"].^2)
end


math["meas"]["71"]
math["bus"]["142"]
for (g, gen) in math["gen"]
    if gen["gen_bus"] == 142
        display(g)
    end
end
