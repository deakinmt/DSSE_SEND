"""
    assign_se_settings!(data::Dict; rescaler::Float64=1e3, criterion::String="rwlav")
PowerModelsDistributionStateEstimation requires users to decide on two settings for state estimation calculations.
See the PMDSE package docs for more info. 
For users that are not familiar with package/concept, it is advertised to keep the default values.
"""
function assign_se_settings!(data::Dict; rescaler::Float64=1e3, criterion::String="rwlav")::Nothing
    data["se_settings"] = Dict("rescaler"=>rescaler, "criterion"=>criterion)
    nothing
end
"ASsign upper and lower bounds to (all) network buses"
function assign_voltage_bounds!(data::Dict; vmin::Float64=0.5, vmax::Float64=1.5)::Nothing
    for (_,bus) in data["bus"]
        bus["vmin"] = fill(vmin, 3)
        bus["vmax"] = fill(vmax, 3)
    end
    nothing
end
"""
    post_process_dsse_solution!(sol::Dict)
Adds information to the solution dictionary `sol` stemming from SE calculations.
This is useful for analyses, plotting, etc.
"""
function post_process_dsse_solution!(sol::Dict)::Nothing
    for (_,bus) in sol["solution"]["bus"]
        vi = bus["vi"]
        vr = bus["vr"]
        bus["vm"] = vi.^2+vr.^2
        bus["vd"] = [sqrt(vr[2]^2+vr[1]^2-2*vr[1]*vr[2]+vi[2]^2+vi[1]^2-2*vi[1]*vi[2]), sqrt(vr[2]^2+vr[3]^2-2*vr[3]*vr[2]+vi[2]^2+vi[3]^2-2*vi[3]*vi[2]), sqrt(vr[1]^2+vr[3]^2-2*vr[3]*vr[1]+vi[1]^2+vi[3]^2-2*vi[3]*vi[1])]
        bus["va"] = atan.(vi, vr)
    end
    nothing
end
"""
    assign_power_rating_based_bounds!(math::Dict)

    Assigns active and reactive power bounds to a `MATHEMATICAL` data dictionary,
to all loads (except those loads that are actually generators).
"""
function assign_power_rating_based_bounds!(data::Dict)
    for (_, load) in data["load"]
        if load["name"] ∉ ["ss13_1", "wt", "storage", "solar"] # exclude generators
            load["pmin"] = -load["pd"]
            load["pmax"] = load["pd"]
            load["qmin"] = -0.3*load["pd"]
            load["qmax"] = 0.3*load["pd"]
        end
    end
end