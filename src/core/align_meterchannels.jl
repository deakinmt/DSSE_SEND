function create_timeseries_dict(;csv_file::String=joinpath(_DS.BASE_DIR, joinpath("matts_files", "all_measurements.csv")))::Dict
    d = Dict{String, Any}()
    df = CSV.read(csv_file)
    for id in unique(df.Id)
        df_id = sort!(filter(x->x.Id .== id, df), :IsoDatetime)
        d[id] = Dict("v1" => df_id.v1, "v2" => df_id.v2, "v3" => df_id.v3)
    end
    return d
end

function groupby_voltlevel(all_dict, volt_level, tolerance)
    volt_dict = deepcopy(all_dict)
    for (k, v) in volt_dict
        if !isapprox(v["v1"][1], volt_level, atol=tolerance)
            delete!(volt_dict, k)
        end
    end
    return volt_dict
end
# improvement: do in the order of appearance of the style
function preprocess_voltage_timeseries(dict::Dict, style::Vector{String})
    preproc_dict = deepcopy(dict)
    if "normalize_avg" ∈ style
        for (k, v) in preproc_dict
            preproc_dict[k]["v1"]./=Statistics.mean(v["v1"])
            preproc_dict[k]["v2"]./=Statistics.mean(v["v2"])
            preproc_dict[k]["v3"]./=Statistics.mean(v["v3"])
        end
    end
    if "normalize_minmax" ∈ style
        for (k, v) in preproc_dict
            preproc_dict[k]["v1"]./=(maximum(v["v1"]) - minimum(v["v1"]))
            preproc_dict[k]["v2"]./=(maximum(v["v2"]) - minimum(v["v2"]))
            preproc_dict[k]["v3"]./=(maximum(v["v3"]) - minimum(v["v3"]))
        end
    end
    if "normalize_max" ∈ style
        for (k, v) in preproc_dict
            preproc_dict[k]["v1"]./=maximum(v["v1"])
            preproc_dict[k]["v2"]./=maximum(v["v2"])
            preproc_dict[k]["v3"]./=maximum(v["v3"])
        end
    end
    if "diff" ∈ style
        for (k, v) in preproc_dict
            preproc_dict[k]["v1"] = diff(v["v1"])
            preproc_dict[k]["v2"] = diff(v["v2"])
            preproc_dict[k]["v3"] = diff(v["v3"])
        end
    end
    return preproc_dict
end

function find_correlations_and_report(dict::Dict, ref::String, metric::String)::Dict
    @assert ref ∈ collect(keys(dict)) "The chosen reference is not in the given dictionary"
    result_dict = Dict{String, Any}()
    v1ref, v2ref, v3ref = dict[ref]["v1"], dict[ref]["v2"], dict[ref]["v3"]
    for (k, v) in dict
        if k != ref
            if metric == "pearson"
                result_dict[k] = [Statistics.cor(v["v1"], v1ref) Statistics.cor(v["v2"], v1ref) Statistics.cor(v["v3"], v1ref); 
                                Statistics.cor(v["v1"], v2ref) Statistics.cor(v["v2"], v2ref) Statistics.cor(v["v3"], v2ref);
                                Statistics.cor(v["v1"], v3ref) Statistics.cor(v["v2"], v3ref) Statistics.cor(v["v3"], v3ref)]
            elseif metric == "spearman"
                result_dict[k] = [StatsBase.corspearman(v["v1"], v1ref) StatsBase.corspearman(v["v2"], v1ref) StatsBase.corspearman(v["v3"], v1ref); 
                                  StatsBase.corspearman(v["v1"], v2ref) StatsBase.corspearman(v["v2"], v2ref) StatsBase.corspearman(v["v3"], v2ref);
                                  StatsBase.corspearman(v["v1"], v3ref) StatsBase.corspearman(v["v2"], v3ref) StatsBase.corspearman(v["v3"], v3ref)]
            elseif metric == "euclidean"
                result_dict[k] = [sum((v["v1"].-v1ref).^2) sum((v["v2"].-v1ref).^2) sum((v["v3"] .- v1ref).^2); 
                                  sum((v["v1"].- v2ref).^2) sum((v["v2"].- v2ref).^2) sum((v["v3"].-v2ref).^2);
                                  sum((v["v1"].- v3ref).^2) sum((v["v2"].- v3ref).^2) sum((v["v3"].- v3ref).^2)]
            end
        end
    end
    return result_dict
end

function calculate_add_PVUR!(dict::Dict)
    for (k,v) in dict
        dict[k]["pvur"] = [maximum([abs(v["v1"][i]-v["v2"][i]), abs(v["v1"][i]-v["v3"][i]), abs(v["v3"][i]-v["v2"][i])])/Statistics.mean([v["v3"][i], v["v2"][i], v["v1"][i]]) for i in 1:length(v["v1"])]*100
    end
end

function assign_from_correlation(dict::Dict)
 #transform corr values in a 3x3 ones and zeros matrix
end