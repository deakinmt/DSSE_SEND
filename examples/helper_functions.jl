"""
The powermodelsdistribution parser does not seem to automatically register tap settings
and assignts all taps as 1.0. This functions reads the actual tap settings given in the 
`xfmrs_dsse.dss` file and assigns them to the engineering data dictionary `ntw_eng`
"""
function update_tap_setting!(ntw_eng::Dict)
    xfmrs_file = joinpath(_DS.BASE_DIR, "twin_data/send_network_model/xfmrs_dsse.dss")
    f = open(xfmrs_file) 
    for line in readlines(f)
        spl = split(line, " ")
        tr = spl[2][13:end]
        if occursin("tap", spl[end])
            tapset = parse(Float64, spl[end][5:end]) 
            ntw_eng["transformer"][tr]["tm_set"] = [[1.0, 1.0, 1.0], [tapset, tapset, tapset]]
        end
    end
    close(f)
end
"""
function assign_power_rating_based_pseudomeas(math::Dict; path::String=joinpath(_DS.BASE_DIR, "twin_data/send_network_model/xfmr_loading.csv"))
    Arguments:
    - math: mathemetical model dictionary in use
    - path: path to the csv file where the transformer loading and rating are available

    The scope is to assigns pseudomeasurements for those non-measured users for which an 
        estimate of the transformer loading is available.
    The pseudo-measurement corresponds to the product of the transformer rating and loading,
    and as such it is time-invariant. The standard deviation of the pseudo-measurement is 100x
    larger than that of a regular power measurement.
    #ND THIS FUNCTION IS NOT finished, we decided to add only variable bounds atm!
"""
function assign_power_rating_based_pseudomeas(math::Dict; path::String=joinpath(_DS.BASE_DIR, "twin_data/send_network_model/xfmr_loading.csv"))
    df = CSV.read(path)
    df_pseudo = filter(x -> (x.meas == 0 && !isnan(x."loading_%")), df) # filter out measured substations and those with no loading estimates (nans)
    m = maximum(parse.(Int, collect(keys(math["meas"]))))
    for (_,load) in math["load"]
        if load["name"] ∈ df_pseudo.transformer
            # not finished, we decided to add only variable bounds!
        end
    end

end
"""
Assigns active and reactive power bounds to the mathematical dictionary `math`,
to all loads (except those loads that are actually generators).
"""
function assign_power_rating_based_bounds!(math::Dict)
    for (_, load) in math["load"]
        if load["name"] ∉ ["ss13_1", "wt", "storage", "solar"] # exclude generators
            load["pmin"] = -load["pd"]
            load["pmax"] = load["pd"]
            load["qmin"] = -0.3*load["pd"]
            load["qmax"] = 0.3*load["pd"]
        end
    end
end