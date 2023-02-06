"""
Plots power of a certain load/generator from csv file of measurements
"""
function plot_powers(choose_id::String, timerange::StepRange{Dates.DateTime, T}; savefig::Bool=false) where T <: Dates.TimePeriod
    day = Dates.Day(timerange[1]).value
    month = Dates.Month(timerange[1]).value
    file = joinpath(_DS.BASE_DIR, "twin_data/telemetry/2022_$(month)_$(day)/all_measurements_$(month)_$(day).csv")
    df = CSV.read(file)
    df_id = filter(x->x.Id .== choose_id, df)
    df_ts = filter(x->x.IsoDatetime ∈ timerange, df_id)
    plt = StatsPlots.plot([df_ts.p, df_ts.q], legend = :topleft, labels=["P" "Q"],
                ylabel="kW/kVAr", title =  "Power plot for $choose_id",
                xticks = ([i for i in 1:40:length(timerange)], [string(x)[6:end-2] for x in timerange[1:40:end]]), 
                xrotation=-45)
    if savefig StatsPlots.savefig(plt, choose_id*"_power.png") end
    return plt 
end