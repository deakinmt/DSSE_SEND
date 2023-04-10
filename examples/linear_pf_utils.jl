function get_Abvvpx()
    A = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mdl_A.csv"), header=0))
    b = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mdl_b.csv"), header=0))
    vbase = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/vbase.csv"), header=0))
    p_idx = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/power_index.csv"), header=0))
    x0 = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/x0.csv"), header=0))
    v_idx = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/voltage_index.csv"), header=0))
    return A,b,vbase,v_idx,p_idx, x0
end
"""
All this does is add a a load corresponding to ss1
"""
function align_dsse_and_linear_model!(data::Dict)
    data["load"]["32"] = deepcopy(data["load"]["7"])
    data["load"]["32"]["load_bus"] = 108
    data["load"]["32"]["name"] = "ss01"
    data["load"]["32"]["source_id"] = "align_dsse_and_linear"
end

function map_p_idx2loadid()
    return Dict(
        "T02" => "5",
        "T01" => "27",
        "SS04" => "26",
        "SS03" => "11",
        "SS05" => "16",
        "SS14" => "19",
        "SS15" => "20",
        "SS16" => "7",
        "SS18" => "17",
        "SS19" => "13",
        "SS21" => "10",
        "SS24" => "12",
        "SS11" => "21",
        "SS33" => "24",
        "SS29" => "14",
        "SS27" => "15",
        "SS26" => "9",
        "SS28" => "25",
        "SS25" => "2",
        "TX3" => "31",
        "RMU2" => "29",
        "TX5" => "30",
        "SS01" => "32",
        "SS02" => "22",
        "SS06" => "8",
        "SS08" => "6",
        "T07" => "18",
        "T08" => "1",
        "SS17" => "3",
        "SS22" => "23",
        "SS12" => "4",
        "SS23" => "28"
    )
end
"""
Get vector of voltages calculated by state estimator, with their plotting indices
"""
function get_voltages_tidy(sol::Dict, data::Dict, xticks::Vector, vm_or_vd::String)
    # dmap = map_p_idx2loadid()
    vs = []
    for x in xticks
        for (m,meas) in data["meas"]
            if meas["var"] ∈ [:vd, :vm]
                if meas["name"][1] == x
                    push!(vs, sol["solution"]["bus"]["$(meas["cmp_id"])"][vm_or_vd])
                end
            end
        end
    end
    return vcat(vs...)
end
"""
Get vector of active power calculated by state estimator, in the order indicated by p_idx
and in W
"""
function get_powers_tidy(sol::Dict, p_idx::Matrix{String},p_or_q::String)
    dmap = map_p_idx2loadid()
    ps = []
    for i in p_idx
        for (k,v) in dmap
            if occursin(k, i) 
                if k ∈ ["RMU2", "TX5", "TX3"]
                    push!(ps, sol["solution"]["load"]["$v"][p_or_q].*1e3)
                else
                    push!(ps, sol["solution"]["load"]["$v"][p_or_q].*-1e3)
                end
            end
        end
    end
    return vcat(unique(ps)...)
end
"""
Perturbs the loads by a certain percentage
"""
perturb_powers(p::Vector{Float64}, perc::Float64) = p.*perc
"""
Creates a timestep's x0 for the v = A*x0+b linear model, from the measurement CSV
"""
function build_x0(p_idx::Matrix{String}, timestep::Dates.DateTime; power_partition::String="balanced")
    day = Dates.Day(timestep).value
    month = Dates.Month(timestep).value
    file = joinpath(_DS.BASE_DIR, "twin_data/telemetry/2022_$(month)_$(day)/all_measurements_$(month)_$(day).csv")
    df = CSV.read(file)
    df.p = df.p #* 1e3 #now in W
    df.q = df.q #* 1e3 #now in W
    ts_df = filter(x->x.IsoDatetime .== timestep, df)
    x0 = Matrix{Float64}(undef, length(p_idx)*2, 1)
    pseudos = _DS.get_max_ss_loads()
    for start_idx in [0, 96] # first 96/ indices are active power, rest is reactive
        for i in 1:3:Int(length(x0)/2) 
            idx = lowercase.(p_idx)[i]
            cmp = occursin("_lv", idx) ? idx[1:end-5] : idx[1:end-2]
            if cmp == "tx3"
                p = filter(x->x.Id .== "wt", ts_df).p[1]               
                q = filter(x->x.Id .== "wt", ts_df).q[1]               
                PQ1, PQ2, PQ3 = start_idx == 0 ? -1e3 .* subdivide_power(p, power_partition) : -1e3 .* subdivide_power(q, power_partition)
            elseif cmp == "tx5"
                p = filter(x->x.Id .== "storage", ts_df).p[1]               
                q = filter(x->x.Id .== "storage", ts_df).q[1]               
                PQ1, PQ2, PQ3 = start_idx == 0 ? -1e3 .* subdivide_power(p, power_partition) : -1e3 .* subdivide_power(q, power_partition)
            elseif cmp == "rmu2"
                p = filter(x->x.Id .== "solar", ts_df).p[1]               
                q = filter(x->x.Id .== "solar", ts_df).q[1]               
                PQ1, PQ2, PQ3 = start_idx == 0 ? -1e3 .* subdivide_power(p, power_partition) : -1e3 .* subdivide_power(q, power_partition)
            elseif cmp ∈ ts_df.Id
                usr_df = filter(x->x.Id .== cmp, ts_df)
                PQ1, PQ2, PQ3 = start_idx == 0 ? subdivide_power(usr_df.p[1], power_partition) : subdivide_power(usr_df.q[1], power_partition)
            elseif cmp ∈ collect(keys(pseudos))
                PQ1, PQ2, PQ3 = start_idx == 0 ? fill(pseudos[cmp]*1000/3, 3) : zeros(3) # x1000 so it's in Watts
            else
                PQ1, PQ2, PQ3 = zeros(3)
            end
            x0[start_idx+i]   = PQ1
            x0[start_idx+i+1] = PQ2
            x0[start_idx+i+2] = PQ3
        end
    end
    return replace(x0, NaN=>0)
end

function subdivide_power(P::Float64, power_partition::String)
    if power_partition == "balanced"
        P1, P2, P3 = P/3, P/3, P/3
    end
    return P1, P2, P3
end