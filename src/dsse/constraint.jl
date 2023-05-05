"""
Allows to incorporate line-to-line voltage magnitude measurements into the ACR and IVR formulations, by mapping them
to phase voltage variables
"""
function constraint_line_to_line_voltage(pm::Union{_PMD.AbstractUnbalancedACRModel, _PMD.AbstractUnbalancedIVRModel}, i::Int; nw::Int=_PMD.nw_id_default)
    
    vd = _PMD.var(pm,nw,:vd,i)
    vr = _PMD.var(pm,nw,:vr,i)
    vi = _PMD.var(pm,nw,:vi,i)

    JuMP.@constraint(pm.model,
        vd[1]^2 == vr[2]^2+vr[1]^2-2*vr[1]*vr[2]+vi[2]^2+vi[1]^2-2*vi[1]*vi[2] 
        )
    JuMP.@constraint(pm.model,
        vd[2]^2 == vr[2]^2+vr[3]^2-2*vr[3]*vr[2]+vi[2]^2+vi[3]^2-2*vi[3]*vi[2]
        )
    JuMP.@constraint(pm.model,
        vd[3]^2 == vr[1]^2+vr[3]^2-2*vr[3]*vr[1]+vi[1]^2+vi[3]^2-2*vi[3]*vi[1]
        )

end
"""
Allows to incorporate three-phase power measurements into the ACR formulation, by mapping them
to per-phase power variables. Works for both loads and generators.
"""
function constraint_total_power(pm::_PMD.AbstractUnbalancedACRModel, i::Int, s::Symbol; nw::Int=_PMD.nw_id_default)
    
    stt = _PMD.var(pm,nw,s,i)
    sym = Symbol(string(s)[1:2])
    spp = _PMD.var(pm,nw,sym,i)

    JuMP.@constraint(pm.model,
        stt == spp[1]+spp[2]+spp[3] 
        )

end
"""
Allows to incorporate three-phase power measurements into the IVR formulation, by mapping them
to per-phase power variables. Works for both loads and generators.
"""
function constraint_total_power(pm::_PMD.AbstractUnbalancedIVRModel, i::Int, s::Symbol; nw::Int=_PMD.nw_id_default)
    
    stt = _PMD.var(pm,nw,s,i)

    if occursin("g", String(s)) 
        b = _PMD.ref(pm,nw,:gen,i)["gen_bus"]
        cr = _PMD.var(pm,nw,:crg,i)
        ci = _PMD.var(pm,nw,:cig,i)    
    elseif occursin("d", String(s)) 
        b = _PMD.ref(pm,nw,:gen,i)["load_bus"]
        cr = _PMD.var(pm,nw,:crd,i)
        ci = _PMD.var(pm,nw,:cid,i)    
    else
        error("variable $s for cmp_id $i not defined. Cmp is neither load nor gen.")
    end

    vr = _PMD.var(pm,nw,:vr,b)
    vi = _PMD.var(pm,nw,:vi,b)
    
    if occursin("p", String(s))
        JuMP.@constraint(pm.model, stt[id] == cr[1]*vr[1]+ci[1]*vi[1]+cr[2]*vr[2]+ci[2]*vi[2]+cr[3]*vr[3]+ci[3]*vi[3])
    elseif occursin("q", String(s))
        JuMP.@constraint(pm.model, stt[id] == -ci[1]*vr[1]+cr[1]*vi[1]-ci[2]*vr[2]+cr[2]*vi[2]-ci[3]*vr[3]+cr[3]*vi[3])
    end

end
"""
Bounds the (square) voltage magnitude when rectangular voltage variables are used 
"""
function constraint_vr_vi_squaresum(pm::Union{_PMD.AbstractUnbalancedACRModel, _PMD.AbstractUnbalancedIVRModel}, i::Int; nw::Int=_PMD.nw_id_default)::Nothing

    bus = _PMD.ref(pm, nw, :bus, i)

    vr = _PMD.var(pm, nw, :vr, i)
    vi = _PMD.var(pm, nw, :vi, i)

    vm_max = bus["vmax"]
    vm_min = bus["vmin"]

    for c in 1:3
        JuMP.@constraint(pm.model, vr[c]^2+vi[c]^2 <= vm_max[c]^2)
        JuMP.@constraint(pm.model, vm_min[c]^2 <= vr[c]^2+vi[c]^2)
    end
end

