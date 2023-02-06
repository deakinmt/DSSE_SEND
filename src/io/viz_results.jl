"""
if in_volts is true, then it returns them in volts
              false, then it returns them in per units
"""
function get_voltage_residuals_one_ts(data::Dict, sol::Dict; in_volts::Bool=true)
    ρ = Dict{String, Any}()
    for (m,meas) in data["meas"]
        if meas["var"] ∈ [:vd, :vm]
            vm_se   = sol["solution"]["bus"]["$(meas["cmp_id"])"]["$(meas["var"])"]
            vm_meas = _DST.mean.(meas["dst"])
            id = meas["name"] isa Vector ? meas["name"][1] : meas["name"]
            ρ["$id"] = in_volts ? (vm_se-vm_meas)*data["bus"]["$(meas["cmp_id"])"]["vbase"]*1000*sqrt(3) : vm_se-vm_meas
        end
    end
    return ρ
end

function get_voltage_measurement(data; in_volts::Bool=true)
    ρ = Dict{String, Any}()
    for (m,meas) in data["meas"]
        if meas["var"] ∈ [:vd, :vm]
            vm_meas = _DST.mean.(meas["dst"])
            id = meas["name"] isa Vector ? meas["name"][1] : meas["name"]
            ρ["$id"] = in_volts ? vm_meas*data["bus"]["$(meas["cmp_id"])"]["vbase"]*1000*sqrt(3) : vm_meas
        end
    end
    return ρ
end

"""
if in_volts is true, then it plots them in volts
              false, then it plots them in per units
"""
function plot_voltage_residuals_one_ts(ρ::Dict; in_volts::Bool=true, title::String="")

    ylabel = in_volts ? "Voltage residuals [V]" : "Voltage residuals [p.u.]" 

    StatsPlots.scatter(collect(keys(ρ)), [x[1] for x in collect(values(ρ))], label="Phase a", markershape=:circle)
    StatsPlots.scatter!(collect(keys(ρ)), [x[2] for x in collect(values(ρ))], label="Phase b", markershape=:diamond)
    StatsPlots.scatter!(collect(keys(ρ)), [x[3] for x in collect(values(ρ))], label="Phase c",markershape=:cross,
                        ylabel = ylabel, title = title,
                        xticks=(0.5:1:length(keys(ρ))-0.5, collect(keys(ρ))), xrotation=-45)
end

function plot_voltage_residuals_multi_ts(ρ::Dict; in_volts::Bool=true, title::String="")
    colnames = vcat(:timestep, :id, :phase_a, :phase_b, :phase_c)
    df = DataFrames.DataFrame(repeat([[]], length(colnames)), colnames)
    pu_or_v = in_volts ? "V" : "V_pu"
    ylabel = in_volts ? "Voltage residuals [V]" : "Voltage residuals [p.u.]"
    for (ts, r) in ρ
        for (name, resid) in r[pu_or_v]
            push!(df, [ts, name, resid[1], resid[2], resid[3]])
        end
    end
    x = collect(keys(ρ))[1]
    p1 = StatsPlots.@df df StatsPlots.boxplot(:id, :phase_a, label="Phase a", legend=:topleft, ylabel=ylabel, xticks=(0.5:1:length(keys(ρ[x][pu_or_v]))-0.5, sort(unique(df.id))), xrotation=-45, title=title, titlefontsize=8)
    p2 = StatsPlots.@df df StatsPlots.boxplot(:id, :phase_b, label="Phase b", legend=:topleft, ylabel=ylabel, xticks=(0.5:1:length(keys(ρ[x][pu_or_v]))-0.5, sort(unique(df.id))), xrotation=-45, title=title, titlefontsize=8)
    p3 = StatsPlots.@df df StatsPlots.boxplot(:id, :phase_c, label="Phase c", legend=:topleft, ylabel=ylabel, xticks=(0.5:1:length(keys(ρ[x][pu_or_v]))-0.5, sort(unique(df.id))), xrotation=-45, title=title, titlefontsize=8)
    return p1,p2,p3
end

function plot_power_residuals_multi_ts(ρ::Dict; per_phase::Bool = true, p_or_q::String="p", in_kw::Bool=true, title::String="")
    colnames = per_phase ? vcat(:timestep, :id, :phase_a, :phase_b, :phase_c) : vcat(:timestep, :id, :power)
    df = DataFrames.DataFrame(repeat([[]], length(colnames)), colnames)
    ylabel_qty = p_or_q == "p" ? "kW" : "kVAr"
    ylabel = in_kw ? "$(uppercase(p_or_q)) residuals [$ylabel_qty]" : "$(uppercase(p_or_q)) residuals [p.u.]"
    for (ts, r) in ρ
        for (name, qty) in r["power"]
            for (q, qq) in qty
                if occursin(p_or_q, q)
                    k = in_kw ? "kW" : "abs"
                    resid = qq[k]
                    if per_phase
                        push!(df, [ts, name, resid[1], resid[2], resid[3]])
                    else
                        push!(df, [ts, name, resid[1]+resid[2]+resid[3]])
                    end
                end
            end
        end
    end
    x = collect(keys(ρ))[1]
    if per_phase
        p1 = StatsPlots.@df df StatsPlots.boxplot(:id, :phase_a, label="Phase a", legend=:topleft, ylabel=ylabel, xticks=(0.5:1:length(keys(ρ[x]["power"]))-0.5, sort(unique(df.id))), xrotation=-45, title=title)
        p2 = StatsPlots.@df df StatsPlots.boxplot(:id, :phase_b, label="Phase b", legend=:topleft, ylabel=ylabel, xticks=(0.5:1:length(keys(ρ[x]["power"]))-0.5, sort(unique(df.id))), xrotation=-45, title=title)
        p3 = StatsPlots.@df df StatsPlots.boxplot(:id, :phase_c, label="Phase c", legend=:topleft, ylabel=ylabel, xticks=(0.5:1:length(keys(ρ[x]["power"]))-0.5, sort(unique(df.id))), xrotation=-45, title=title)
        return p1,p2,p3
    else
        p = StatsPlots.@df df StatsPlots.boxplot(:id, :power, label="Total 3P power", legend=:topleft, ylabel=ylabel, xticks=(0.5:1:length(keys(ρ[x]["power"]))-0.5, sort(unique(df.id))), xrotation=-45, title=title)
        return p
    end
end

function get_power_residuals_one_ts(data::Dict, sol::Dict)
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
"""
plots a time series from any results from the `run_dsse_multi_ts` function (except the diagnostic dictionary)
"""
function plot_timeseries(res::Dict, vals::Dict, what::String, choose_id::String, timerange)
    @assert lowercase(what) ∈ ["p", "q", "v"] "please choose a `what` among p, q, or v. not $what"
    x = []
    y_meas_ph1 = []
    y_est_ph1 = []
    y_meas_ph2 = []
    y_est_ph2 = []
    y_meas_ph3 = []
    y_est_ph3 = []

    for (t, ts) in res
        if Dates.DateTime(t) ∈ timerange
            if lowercase(what) ∈ ["p", "q"]
                is_load = haskey(ts["power"][choose_id], "pd")
                if is_load
                    y_est = vals[t]["power_load"][choose_id][lowercase(what)*"d"] #variable value calculated by SE
                    y_meas = y_est-ts["power"][choose_id][lowercase(what)*"d"]["abs"] #measurement = variable value-residual
                else
                    y_est = vals[t]["power_gen"][choose_id][lowercase(what)*"g"] #variable value calculated by SE
                    y_meas = y_est-ts["power"][choose_id][lowercase(what)*"g"]["abs"] #measurement = variable value-residual
                end
            else
                y_est = vals[t]["V_pu"][choose_id] #variable value calculated by SE
                y_meas = y_est-ts["V_pu"][choose_id] #measurement = variable value-residual
            end
            push!(y_meas_ph1, y_meas[1])
            push!(y_meas_ph2, y_meas[2])
            push!(y_meas_ph3, y_meas[3])
            push!(y_est_ph1, y_est[1])
            push!(y_est_ph2, y_est[2])
            push!(y_est_ph3, y_est[3])
            push!(x, t[6:end])
        end
    end
    p1 = StatsPlots.plot([x,x], [y_meas_ph1, y_est_ph1], labels=["Meas." "Est."], ylabel="$(uppercase(what)) - ph. 1 [p.u.]", xrotation=-45)
    p2 = StatsPlots.plot([x,x], [y_meas_ph2, y_est_ph2], labels=["Meas." "Est."], ylabel="$(uppercase(what)) - ph. 2 [p.u.]", xrotation=-45)
    p3 = StatsPlots.plot([x,x], [y_meas_ph3, y_est_ph3], labels=["Meas." "Est."], ylabel="$(uppercase(what)) - ph. 3 [p.u.]", xrotation=-45)
    return p1, p2, p3
end