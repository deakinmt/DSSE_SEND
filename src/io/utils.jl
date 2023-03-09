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
"""
Retrieves loading data of substations, in kW. #TODO --> remove imaginary part altogether and get rid of `complex?`
"""
function get_max_ss_loads(;complex=false)
    dict = complex ?
        Dict(
            "ss11" => 300+0j,
            "ss15" => 300+0j,
            "ss16" => 200+0j,
            "ss25" => 800+0j,
            "ss26" => 400+0j,
            "ss12" => 114+0j,
            "ss22" => 114+0j,
            "t07"  => 800+0j,
            "t08"  => 400+0j,
            "ss03" => 230+0j,
            "ss04" => 225+0j,
            "ss05" => 150+0j,
            "ss06" => 175+0j,
            "ss08" => 162+0j,
            "ss21" => 826+0j,
            "ss23" => 392+0j,
            "ss24" => 829+0j,
        ) :
        Dict(
            "ss11" => 300.,
            "ss15" => 300.,
            "ss16" => 200.,
            "ss25" => 800.,
            "ss26" => 400.,
            "ss12" => 114.,
            "ss22" => 114.,
            "t07"  => 800.,
            "t08"  => 400.,
            "ss03" => 230.,
            "ss04" => 225.,
            "ss05" => 150.,
            "ss06" => 175.,
            "ss08" => 162.,
            "ss21" => 826.,
            "ss23" => 392.,
            "ss24" => 829.,
        ) 
    return dict
end