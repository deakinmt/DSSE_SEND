"""
Creates auxiliary variable for line-to-line voltages
"""
function variable_line_to_line_voltage_magnitude(pm::_PMD.AbstractUnbalancedPowerModel; nw::Int=_PMD.nw_id_default, bounded::Bool=true)
    
    bus_with_vd_meas = [meas["cmp_id"] for (i, meas) in _PMD.ref(pm, nw, :meas) if meas["var"] == :vd]

    terminals = Dict(i => bus["terminals"] for (i,bus) in _PMD.ref(pm, nw, :bus))
    vd = _PMD.var(pm, nw)[:vd] = Dict(i => JuMP.@variable(pm.model,
            [t in terminals[i]], base_name="$(nw)_vd_$(i)"
        ) for i in _PMD.ids(pm, nw, :bus) if i ∈ bus_with_vd_meas
    )

    if bounded
        for (i,bus) in _PMD.ref(pm, nw, :bus) 
            if i ∈ bus_with_vd_meas
                for (idx, t) in enumerate(terminals[i])
                    if haskey(bus, "vmin")
                        JuMP.set_lower_bound(vd[i][t], bus["vmin"][idx])
                    end
                    if haskey(bus, "vmax")
                        JuMP.set_upper_bound(vd[i][t], bus["vmax"][idx])
                    end
                end
            end
        end
    end
end
"""
Variation of the namesake _PMDSE variable, that allows to recognise the :vd symbol that indicates line-to-line voltages.
:vd are currently not natively supported in the PowerModelsDistributionStateEstimation package
"""
function variable_mc_measurement(pm::_PMD.AbstractUnbalancedPowerModel; nw::Int=_PMD.nw_id_default, bounded::Bool=false)
    for i in _PMD.ids(pm, nw, :meas)
        msr_var = _PMD.ref(pm, nw, :meas, i, "var")
        cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
        cmp_type = _PMD.ref(pm, nw, :meas, i, "cmp")
        connections = _PMDSE.get_active_connections(pm, nw, cmp_type, cmp_id)
        if msr_var == :vd                                      # <- original to DSSE_SEND package 
            constraint_line_to_line_voltage(pm, cmp_id, nw=nw) # <- original to DSSE_SEND package
        else
            if _PMDSE.no_conversion_needed(pm, msr_var)
                #no additional variable is created, it is already by default in the formulation
            else
                cmp_type == :branch ? id = (cmp_id, _PMD.ref(pm,nw,:branch, cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch, cmp_id)["t_bus"]) : id = cmp_id
                if haskey(_PMD.var(pm, nw), msr_var)
                    push!(_PMD.var(pm, nw)[msr_var], id => JuMP.@variable(pm.model,
                        [c in connections], base_name="$(nw)_$(String(msr_var))_$id"))
                else
                    _PMD.var(pm, nw)[msr_var] = Dict(id => JuMP.@variable(pm.model,
                        [c in connections], base_name="$(nw)_$(String(msr_var))_$id"))
                end
                msr_type = _PMDSE.assign_conversion_type_to_msr(pm, i, msr_var; nw=nw)
                _PMDSE.create_conversion_constraint(pm, _PMD.var(pm, nw)[msr_var], msr_type; nw=nw)
            end
        end
    end
end