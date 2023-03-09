using CSV, DataFrames, StatsPlots

okfile  = "tap_analyses_aggr_2 minutes_oktaps.csv"
offfile = "tap_analyses_aggr_2 minutes_offtaps.csv"

ok_df  = CSV.read(okfile)
off_df = CSV.read(offfile)

function plot_residuals_single_ts(df::DataFrames.DataFrame, ts::Dates.DateTime; aggr::String="", taps::String="", report_details::Bool=false)

    df_ts = filter(x->x.timestep.==ts, df)
    x_ids = unique([name[1:end-3] for name in names(df_ts)[4:end]])

    p = StatsPlots.scatter([df_ts[1,x*"_p1"]  for x in x_ids], label="Phase ab", markershape=:circle , ms = 5, mc=:white, msc=:black, msw=2)
    StatsPlots.scatter!([df_ts[1,x*"_p2"] for x in x_ids], label="Phase bc", markershape=:cross  , color="black", ms = 5, msw=4)
    StatsPlots.scatter!([df_ts[1,x*"_p3"] for x in x_ids], label="Phase ca", markershape=:diamond, color="grey" , ms = 4)
    plot!(xrotation=-45, xticks = (1:1:length(x_ids), x_ids), ylabel="Voltage residuals [p.u.]")

    if report_details
        plot!(title="Aggr. $aggr"*", ts: $ts, Taps: $taps") #title can be easily cropped out in LaTeX eventually
    end

    return p
end

#savefig("residuals_off_taps_example.pdf")

function plot_residuals_multi_ts(df::DataFrames.DataFrame, trange::Dates.StepRange; aggr::String="",taps::String="", report_details::Bool=false)

    df_ts = filter(x->x.timestep ∈ trange, df)
    x_ids = unique([name[1:end-3] for name in names(df_ts)[4:end]])

    rdf_p1 = DataFrames.DataFrame(name=[], val = [], pos=[])
    rdf_p2 = DataFrames.DataFrame(name=[], val = [], pos=[])
    rdf_p3 = DataFrames.DataFrame(name=[], val = [], pos=[])

    nc = 0
    for name in unique([ n[1:end-3] for n in names(df_ts[4:end])])
        nc+=3
        rdf_p1 = vcat(rdf_p1,DataFrame(name=repeat([name], size(df_ts)[1]), val =df_ts[:,name*"_p1"], pos=repeat([nc-0.5], size(df_ts)[1]))) 
        rdf_p2 = vcat(rdf_p2,DataFrame(name=repeat([name], size(df_ts)[1]), val =df_ts[:,name*"_p2"], pos=repeat([nc], size(df_ts)[1]))) 
        rdf_p3 = vcat(rdf_p3,DataFrame(name=repeat([name], size(df_ts)[1]), val =df_ts[:,name*"_p3"], pos=repeat([nc+0.5], size(df_ts)[1]))) 
    end
    
    p = @df rdf_p1 boxplot(:pos, :val, barwidth=0.5, label="Phase ab", markershape=:circle , ms = 5, color="green")
        @df rdf_p2 boxplot!(:pos, :val,barwidth=0.5, label="Phase bc", markershape=:cross  , color="grey", ms = 5, mc=:black, msc=:black, msw=2)
        @df rdf_p3 boxplot!(:pos, :val,barwidth=0.5, label="Phase ca", markershape=:diamond  , color="blue", ms = 5)
    
    plot!(xrotation=-45, xticks = (unique(rdf_p2.pos), x_ids), ylabel="Voltage residuals [p.u.]")

    if report_details
        plot!(title="Aggr. $aggr"*", ts: $ts, Taps: $taps") #title can be easily cropped out
    end

    return p
end