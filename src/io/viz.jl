"""
Plots power of a certain load/generator
"""
function plot_powers(choose_id::String, timerange::StepRange{Dates.DateTime, T}; savefig::Bool=false, file::String=joinpath(_DS.BASE_DIR, "matts_files/all_measurements.csv")) where T <: Dates.TimePeriod
    df = CSV.read(file)
    df_id = filter(x->x.Id .== choose_id, df)
    df_ts = filter(x->x.IsoDatetime ∈ timerange, df_id)
    plt = StatsPlots.plot([df_ts.p, df_ts.q], legend = :topleft, labels=["P" "Q"],
                ylabel="kW/kVAr", title = choose_id,
                xticks = ([i for i in 1:40:length(timerange)], [string(x)[6:end-2] for x in timerange[1:40:end]]), 
                xrotation=-45)
    if savefig StatsPlots.savefig(plt, choose_id*"_power.png") end
    return plt 
end

function get_voltage_residuals_onets(data::Dict, sol::Dict)
    ρ = Dict{String, Any}()
    for (m,meas) in data["meas"]
        if meas["var"] == :vm
            vm_se   = sol["solution"]["bus"]["$(meas["cmp_id"])"]["vm"]
            vm_meas = _DST.mean.(meas["dst"])
            id = meas["name"] isa Vector ? meas["name"][1] : meas["name"]
            ρ["$id"] = (vm_se-vm_meas)*data["bus"]["$(meas["cmp_id"])"]["vbase"]*1000*sqrt(3)
        end
    end
    return ρ
end

function plot_voltage_residuals_onets(ρ::Dict; data::Dict=Dict{String, Any}())
    if !isempty(data)

    else
        ylabel = "Voltage residuals [p.u.]"
    end
    StatsPlots.scatter(collect(keys(ρ)), [x[1] for x in collect(values(ρ))], label="Phase a", markershape=:circle)
    StatsPlots.scatter!(collect(keys(ρ)), [x[2] for x in collect(values(ρ))], label="Phase b", markershape=:diamond)
    StatsPlots.scatter!(collect(keys(ρ)), [x[3] for x in collect(values(ρ))], label="Phase c",markershape=:cross,
                        ylabel = ylabel,
                        xticks=(0.5:1:length(keys(ρ))-0.5, collect(keys(ρ))), xrotation=-45)
end

function plot_voltage_residuals_multits(ρ::Dict)
    colnames = vcat(:timestep, :id, :phase_a, :phase_b, :phase_c)
    df = DataFrames.DataFrame(repeat([[]], length(colnames)), colnames)
    for (ts, r) in ρ
        for (name, resid) in r
            push!(df, [ts, name, resid[1], resid[2], resid[3]])
        end
    end
    x = collect(keys(ρ))[1]
    StatsPlots.plot(ylabel="Voltage residuals [V]",xticks=(0.5:1:length(keys(ρ[x]))-0.5, collect(keys(ρ[x]))), xrotation=-45)
    StatsPlots.@df df StatsPlots.boxplot!(:id, :phase_a)
    StatsPlots.@df df StatsPlots.boxplot!(:id, :phase_b)
    StatsPlots.@df df StatsPlots.boxplot!(:id, :phase_c)
end

function plot_voltage_residuals_multits2(ρ::Dict)
    colnames = vcat(:timestep, :id, :phase_a, :phase_b, :phase_c)
    colnames = vcat(:timestep, :id, :phase, :res)
    df = DataFrames.DataFrame(repeat([[]], length(colnames)), colnames)
    for (ts, r) in ρ
        for (name, resid) in r
            for x in 1:3
                push!(df, [ts, name, ["Phase A", "Phase B", "Phase C"][x], resid[x]])
            end
        end
    end
    StatsPlots.@df df boxplot(:id, :res, groupby=:phase)
end

function get_power_residuals_onets(data::Dict, sol::Dict)
    ρ = Dict{String, Any}()
    for (m,meas) in data["meas"]
        if meas["var"] ∈ [:pd, :qd]
            pq_se   = sol["solution"]["load"]["$(meas["cmp_id"])"]["$(string(meas["var"]))"]
            pq_meas = _DST.mean.(meas["dst"])
            id = meas["name"] isa Vector ? meas["name"][1] : meas["name"]
            if !haskey(ρ, "$id")
                ρ["$id"] = Dict{String, Any}()
                ρ["$id"]["pd"] = Dict{String, Any}()
                ρ["$id"]["qd"] = Dict{String, Any}()
            end
            ρ["$id"]["$(string(meas["var"]))"] = Dict("perc"=>(pq_se-pq_meas)./pq_meas*100, "abs"=>pq_se-pq_meas, "kW"=>(pq_se-pq_meas)*1e5) 
        end
        if meas["var"] ∈ [:pg, :qg]
            pq_se   = sol["solution"]["gen"]["$(meas["cmp_id"])"]["$(string(meas["var"]))"]
            pq_meas = _DST.mean.(meas["dst"])
            id = meas["name"] isa Vector ? meas["name"][1] : meas["name"]
            if !haskey(ρ, "$id")
                ρ["$id"] = Dict{String, Any}()
                ρ["$id"]["pg"] = Dict{String, Any}()
                ρ["$id"]["qg"] = Dict{String, Any}()
            end
            ρ["$id"]["$(string(meas["var"]))"] = Dict("perc"=>(pq_se-pq_meas)./pq_meas.*100, "abs"=>pq_se-pq_meas, "kW"=>(pq_se-pq_meas)*1e5) 
        end
    end
    return ρ
end
