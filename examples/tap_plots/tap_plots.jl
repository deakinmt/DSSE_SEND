###########################
## This example shows how to plot the residuals of DSSE results
## using the default (off) MV/LV tap settings in the network model and the 
## corrected (ok) tap settings. This corresponds to figure 9 in the paper.
###########################

using CSV, DataFrames, StatsPlots, LaTeXStrings, Dates

include("plot_function.jl") # this file contains the `plot_residuals` function used here

# the csv files below could be created using SEND_DSSE as in `examples/state_estimation_and_power_flow/state_estimation_with_tap_settings_analysis.jl`
offfile = "tap_plots/tap_analyses_aggr_2 minutes_offtaps.csv" # file with DSSE residual values with wrong tap settings in the network model
okfile  = "tap_plots/tap_analyses_aggr_2 minutes_oktaps.csv"  # file with DSSE residual values with improved tap settings in the network model

# the two lines below convert the CSV files above into dataframes
ok_df  = CSV.read(okfile, DataFrames.DataFrame)
off_df = CSV.read(offfile, DataFrames.DataFrame)

yticks_off = ([0.00, 0.05, 0.10, 0.15], [L"%$i" for i in [0.00, 0.05, 0.10, 0.15]]) # set the y-axis ticks for the plot with wrong tap settings
yticks_ok = (-0.02:0.01:0.02, [L"%$i" for i in -0.02:0.01:0.02]) # set the y-axis ticks for the plot with ok tap settings

# the two lines below call the plotting function and realize the plots 
plot_with_ok_tap = plot_residuals(ok_df, ok_df.timestep[3], yticks_ok)
plot_with_off_tap = plot_residuals(off_df, off_df.timestep[3], yticks_off)