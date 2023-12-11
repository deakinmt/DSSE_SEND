"""
imports vectors and matrix for the linear model from the folder they are stored in.
"""
function get_Abvvpx_mv()
    A = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mv_mdl_A.csv"), DataFrames.DataFrame, header=0))
    b = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mv_mdl_b.csv"), DataFrames.DataFrame,header=0))
    vbase = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mv_vbase.csv"), DataFrames.DataFrame, header=0))
    p_idx = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mv_power_index.csv"), DataFrames.DataFrame, header=0))
    x0 = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mv_x0.csv"), DataFrames.DataFrame, header=0))
    v_idx = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mv_voltage_index.csv"), DataFrames.DataFrame, header=0))
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
As in equation (6) of the paper
"""
function get_cpf_factor(A, vbase, p_idx)
    pf = 0.9
    cpf = sqrt(1-pf^2)/pf
    Apu = A#./vbase
    inj_idx_P = getindex.(findall(x->occursin("RMU2", x), p_idx), 1)
    inj_idx_Q = inj_idx_P .+ length(p_idx)
    A_p = Apu[:,inj_idx_P]*(ones(3)/3)
    A_q = Apu[:,inj_idx_Q]*(ones(3)/3*(-cpf))
    return (A_p + A_q) 
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