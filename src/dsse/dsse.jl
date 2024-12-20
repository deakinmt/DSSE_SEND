"solves the AC state estimation in rectangular coordinates (ACR formulation)"
function solve_acr_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return solve_mc_se(data, _PMD.ACRUPowerModel, solver; kwargs...)
end

"solves the state estimation in current and voltage rectangular coordinates (IVR formulation)"
function solve_ivr_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    error("Currently, only ACR and ACP formulations are available. We are working on it. 
           If you would like this feature, please open an issue.")
    return solve_mc_se(data, _PMD.IVRUPowerModel, solver; kwargs...)
end

"generic state estimation solver function"
function solve_mc_se(data::Union{Dict{String,<:Any},String}, model_type::Type, solver; kwargs...)
    if haskey(data["se_settings"], "criterion")
        _PMDSE.assign_unique_individual_criterion!(data)
    end
    if !haskey(data["se_settings"], "rescaler")
        data["se_settings"]["rescaler"] = 1
        @warn "Rescaler set to default value, edit data dictionary if you wish to change it."
    end
    if !haskey(data["se_settings"], "number_of_gaussian")
        data["se_settings"]["number_of_gaussian"] = 10
        @warn "Estimation criterion set to default value, edit data dictionary if you wish to change it."
    end
    return _PMD.solve_mc_model(data, model_type, solver, build_mc_send_dsse; kwargs...)
end

"specification of the state estimation problem for a bus injection model - ACP and ACR formulations"
function build_mc_send_dsse(pm::_PMD.AbstractUnbalancedPowerModel)

    # Variables
    variable_line_to_line_voltage_magnitude(pm; bounded = false)
    _PMDSE.variable_mc_bus_voltage(pm; bounded = true)
    _PMD.variable_mc_branch_power(pm; bounded = false)
    _PMD.variable_mc_transformer_power(pm; bounded = false, report=false)
    _PMD.variable_mc_generator_power(pm; bounded = false)
    _PMDSE.variable_mc_load(pm; report = true)
    _PMDSE.variable_mc_residual(pm; bounded = true)
    _DS.variable_aggregated_power(pm; bounded = false)
    _DS.variable_mc_measurement(pm; bounded = false)

    # Constraints
    for (i,gen) in _PMD.ref(pm, :gen)
        _PMD.constraint_mc_generator_power(pm, i)
    end
    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
    end
    for (i,bus) in _PMD.ref(pm, :bus)
        constraint_vr_vi_squaresum(pm, i)
    end
    for (i,bus) in _PMD.ref(pm, :bus)
        _PMDSE.constraint_mc_power_balance_se(pm, i)
        bus_with_vd_meas = [meas["cmp_id"] for (i, meas) in _PMD.ref(pm, 0, :meas) if meas["var"] == :vd]
        if i ∈ bus_with_vd_meas
            _DS.constraint_line_to_line_voltage(pm,i)
        end
    end
    for (i,branch) in _PMD.ref(pm, :branch)
        _PMD.constraint_mc_ohms_yt_from(pm, i)
        _PMD.constraint_mc_ohms_yt_to(pm,i)
    end
    for (i, meas) in _PMD.ref(pm, :meas)
        _DS.constraint_mc_residual(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    # Objective
    _PMDSE.objective_mc_se(pm)

end