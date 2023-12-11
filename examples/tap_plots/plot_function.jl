# this file contains the plot function used in `tap_plots.jl`

using DataFrames, StatsPlots, LaTeXStrings, Dates

"""
Given a dataframe with DSSE residuals `df`, a time step in DateTime format `ts`, and ticks settings for the y-axis, `yticks`,
this function plots the voltage residuals of the measured users, given the values in the `df`.
    Note that timestep `ts` must correspond to a time step in `df` (i.e., for which results exist)
"""
function plot_residuals(df::DataFrames.DataFrame, ts::Dates.DateTime, yticks)

    guidefontsize = 15
    tickfontsize = 11

    df_ts = filter(x->x.timestep.==ts, df)
    x_ids = unique([name[1:end-3] for name in names(df_ts)[4:end]])

    xtkz = []
    for i in x_ids
        if !occursin("_", i)
            push!(xtkz, L"\textrm{%$i}")
        else
            sp = split(i, "_")
            spp = sp[1]*"\\_"*sp[2]
            push!(xtkz, L"\textrm{%$spp}")
        end
    end

    p = StatsPlots.scatter([df_ts[1,x*"_p1"].+1e-7  for x in x_ids], label=L"\textrm{U_{ab}}", markershape=:circle , ms = 5, mc=:white, msc=:black, msw=2)
    StatsPlots.scatter!([df_ts[1,x*"_p2"].+1e-7 for x in x_ids], label=L"\textrm{U_{bc}}", markershape=:cross  , color="black", ms = 5, msw=4)
    StatsPlots.scatter!([df_ts[1,x*"_p3"].+1e-7 for x in x_ids], label=L"\textrm{U_{ca}}", markershape=:diamond, color="grey" , ms = 4)
    StatsPlots.plot!(guidefontsize=guidefontsize-1, tickfontsize=tickfontsize, legendfontsize=11, xrotation=-45, 
    xticks = (1:1:length(x_ids), xtkz), ylabel=L"\textrm{Voltage \, \,  residuals, \, pu}",
     xlabel = L"\textrm{Measurement \, \,  ID}",
     yticks = yticks,
     bottom_margin = 6StatsPlots.mm
     )

    return p
end