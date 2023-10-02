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
