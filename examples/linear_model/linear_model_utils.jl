"""
imports vectors and matrix for the linear model from the folder they are stored in.
"""
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
As above but for the MV-only case.
"""
function get_Abvvpx_mv()
    A = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mv_mdl_A.csv"), header=0))
    b = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mv_mdl_b.csv"), header=0))
    vbase = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mv_vbase.csv"), header=0))
    p_idx = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mv_power_index.csv"), header=0))
    x0 = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mv_x0.csv"), header=0))
    v_idx = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mv_voltage_index.csv"), header=0))
    return A,b,vbase,v_idx,p_idx, x0
end
"""
Builds x′ as indicated in the paper
"""
function build_xprime(p_idx)
    xpp = zeros(Float64, length(p_idx)*2) #multiplied by two to include reactive power
    pgen_idx = [cart_idx[1] for cart_idx in findall(x->occursin("RMU2", x),  p_idx)]
    for idx in pgen_idx xpp[idx] = 1/3 end
    return xpp
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
"""
simple dictionary to map substation names to matrix indices
"""
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
build the `b` vector for the linear model (for a single time step), starting from
    the voltage results of state estimation calculations stored in a csv file `vm_res`.
"""
function build_b_from_se_results(vm_res, v_idx, v_base, rowidx)
    v = vm_res[rowidx, 6:end]
    b = [v["SOURCEBUS.1"][1], v["SOURCEBUS.2"][1], v["SOURCEBUS.3"][1]].*v_base[1]
    for i in 4:3:length(v_idx)-2 # starts from idx 4 to skip voltage source
        vidx = v_idx[i]
        vb   = v_base[i] 
        col = findfirst(item -> item == vidx, names(v))
        push!(b, v[col][1]*vb)
        push!(b, v[col+1][1]*vb)
        push!(b, v[col+2][1]*vb)
    end
    return b
end
"""
builds V⁺ as explained in the paper
"""
function build_Vplus(v_idx, lv_lim::Float64=1.1, mv_lim::Float64=1.06)
    V⁺ = Array{Float64,1}(undef, length(v_idx))
    for (i,v) in enumerate(v_idx)
        V⁺[i] = occursin("LV", v) ? lv_lim : mv_lim
    end
    return V⁺
end