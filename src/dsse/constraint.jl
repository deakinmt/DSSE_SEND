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