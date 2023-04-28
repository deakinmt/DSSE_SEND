import DSSE_SEND as _DS
import PowerModelsDistribution as _PMD
import DataFrames as _DF
import LinearAlgebra: diagm
import Random as _RAN
import Distributions as _DST

function parse_unbal_loadflowday_network()
    eng = _DS.parse_send_ntw_unbal()  # get the ENGINEERING network data dictionary
    _DS.update_tap_setting!(eng)
    math = _PMD.transform_data_model(eng)
    _DS.model_generators_as_loads!(math)
    adjust_voltage_source!(math)
    for (l,load) in math["load"]
        for k in ["pmin", "pmax", "qmin", "qmax"]
            if haskey(load, k)
                delete!(load, k)
            end
        end
    end
    math["gen"]["1"]["pg"] = [0.0146667, 0.0146667, 0.0146667]
    math["gen"]["1"]["qg"] = [0.0002, 0.0002, 0.0002]
    math["gen"]["1"]["pmax"] = [1., 1., 1.]
    math["gen"]["1"]["qmax"] = [1., 1., 1.]
    math["gen"]["1"]["pmin"] = [-1., -1., -1.]
    math["gen"]["1"]["qmin"] = [-1., -1., -1.]
    math["gen"]["1"]["control_mode"] = _PMD.FREQUENCYDROOP

    return math
end

function adjust_voltage_source!(ntw::Dict)
    g = deepcopy(ntw["gen"]["4"])
    empty!(ntw["gen"])
    ntw["gen"]["1"] = g 
    ntw["gen"]["1"]["connections"] = [1,2,3]
    ntw["gen"]["1"]["vg"] = [0.001, 0.001, 0.001] 
    ntw["gen"]["1"]["pmin"] = [-Inf, -Inf, -Inf] 
    ntw["gen"]["1"]["pmax"] = [Inf, Inf, Inf] 
    ntw["gen"]["1"]["gen_bus"] = 56
    for b in ["137", "136", "135"]
        delete!(ntw["bus"], b)
    end
    ntw["branch"]["13"]["br_r"]+=diagm(fill(ntw["branch"]["99"]["br_r"][1], 3)) #add vsource impedance
    ntw["branch"]["13"]["br_x"]+=diagm(fill(ntw["branch"]["99"]["br_x"][1], 3)) #add vsource impedance
    for br in ["101", "100", "99"]
        delete!(ntw["branch"], br)
    end

    ntw["bus"]["56"]["bus_type"] = 3
    ntw["bus"]["56"]["vmin"] = [0.7, 0.7, 0.7]
    ntw["bus"]["56"]["vmax"] = [1.3, 1.3, 1.3]
    ntw["bus"]["56"]["va"] = [0.0, -2.0944, 2.0944]

end

function strng2cmpx(s::String)
    mins = count("-", s)
    if mins == 0
        spl = split(s, "+")
        re = parse(Float64, spl[1][2:end])
        img = parse(Float64, spl[2][1:end-2])
    elseif mins == 2
        spl = split(s, "-")
        re = parse(Float64, spl[2])
        img = parse(Float64, spl[3][1:end-2])
    else # 1 minus sign
        spl = split(s, "+")
        if length(spl) == 2
            img = parse(Float64, spl[2][1:end-2])
        else
            spl = split(s, "-")
            img = -parse(Float64, spl[2][1:end-2])
        end
        re = parse(Float64, spl[1][2:end])
    end
    return re+img*im
end

function add_measurements_se_day!(ntw::Dict, max_err::Float64, row_idx::Int, p_load::_DF.DataFrame, q_load::_DF.DataFrame, p_gen::_DF.DataFrame, q_gen::_DF.DataFrame, volts::_DF.DataFrame)
    if haskey(ntw, "meas") empty!(ntw["meas"]) end
    pds = p_load[row_idx, :] 
    qds = q_load[row_idx, :] 
    pgs = p_gen[row_idx, :] 
    qgs = q_gen[row_idx, :] 
    vs = volts[row_idx, :]
    
    ntw["meas"] = Dict{String, Any}()

    loadbuses = unique([load["load_bus"] for (_, load) in ntw["load"]])
    genbuses = unique([gen["gen_bus"] for (_, gen) in ntw["gen"]])

    for c in 2:3:175
        m_idx = isempty(ntw["meas"]) ? 1 : maximum(parse.(Int, collect(keys(ntw["meas"]))))+1
        name = lowercase(names(vs)[c])[1:end-2]
        for (_,bus) in ntw["bus"]
            if bus["name"] == name && bus["index"] ∈ vcat(loadbuses, genbuses)              
                μ = abs.(strng2cmpx.([vs[c], vs[c+1], vs[c+2]]))./(bus["vbase"]*1000)
                σ = max_err/3
                μ_err = []
                for μ_i ∈ μ
                    push!(μ_err, _DST.rand(_DST.Normal(μ_i, σ)))
                end 
                dst = [_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
                ntw["meas"]["$m_idx"] = Dict("var"=>:vm, "cmp"=>:bus, "cmp_id"=>bus["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")
            end
        end
    end

    for c in 2:1:82
        name = names(pds)[c]
        for (_,load) in ntw["load"]
            if load["name"] == name  
                for (p, qty) in zip([pds, qds], [:pd, :qd])
                    m_idx = isempty(ntw["meas"]) ? 1 : maximum(parse.(Int, collect(keys(ntw["meas"]))))+1   
                            
                    # μ = [p[c], p[c+1], p[c+2]]./ntw["settings"]["sbase"]
                    μ = [p[c]]./ntw["settings"]["sbase"]

                    for i in 1:length(μ)
                        if isnan(μ[i])
                            μ[i] = 0.
                        end
                    end

                    σ = max_err/3*_DST.mean(μ) == 0 ? max_err/3*_DST.mean(μ) : 1e-7 #TODO change error definition?
                    μ_err = []
                    for μ_i ∈ μ
                        push!(μ_err, _DST.rand(_DST.Normal(μ_i, σ)))
                    end 
                    dst = [_DST.Normal(μ_err[1], σ)]#[_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
                    ntw["meas"]["$m_idx"] = Dict("var"=>qty, "cmp"=>:load, "cmp_id"=>load["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")
                end
            end
        end
    end

    for c in 2:4
        name = names(pgs)[c]
        for (_,load) in ntw["load"] # remember you are passing loads as generators
            if load["name"] == name  
                for (p, qty) in zip([pgs, qgs], [:pd, :qd])
                    m_idx = isempty(ntw["meas"]) ? 1 : maximum(parse.(Int, collect(keys(ntw["meas"]))))+1            
                    μ = fill(-p[c]/3, 3).*(1000/ntw["settings"]["sbase"]) # times 1000 because gen is measured in kW/kVAr
                    σ = max_err/3*_DST.mean(μ) == 0 ? max_err/3*_DST.mean(μ) : 1e-7 #TODO change error definition?
                    μ_err = []
                    for μ_i ∈ μ
                        push!(μ_err, _DST.rand(_DST.Normal(μ_i, σ)))
                    end 
                    dst = [_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
                    ntw["meas"]["$m_idx"] = Dict("var"=>qty, "cmp"=>:load, "cmp_id"=>load["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")
                end
            end
        end
    end
end

function get_vm_df(volts::_DF.DataFrame)
    v_vm = DataFrames.DataFrame([name => [] for name in names(volts)])
    for row in eachrow(volts)
        n = [strng2cmpx(row[c]) for c in 2:length(row)]
        vm = abs.(n)
        push!(v_vm, vcat(row.IsoDatetime, vm))
    end
    return v_vm
end

function get_bus_vbase(ntw::Dict, v_vm::_DF.DataFrame)
    v_pu = DataFrames.DataFrame([name => [] for name in names(v_vm)])
    vpu = []
    for r in 2:3:length(names(v_pu))
        for (b, bus) in ntw["bus"]
            if bus["name"] == lowercase(names(v_pu)[r][1:end-2])
                push!(vpu, fill(ntw["bus"][b]["vbase"]*1000,3))
            end
        end
    end
    return push!(v_pu, vcat(v_vm.IsoDatetime[1], vcat(vpu...)))
end

function get_vm_in_pu(v_pu::_DF.DataFrame, v_vm::_DF.DataFrame)
    vm_pu = DataFrames.DataFrame([name => [] for name in names(v_vm)])
    for row in eachrow(v_vm)
        vpu = [row[r]/v_pu[1, r] for r in 2:length(names(v_vm))]
        push!(vm_pu, vcat(row.IsoDatetime, vpu))
    end
    return vm_pu
end

function add_measurements_se_day_old_ntw!(ntw::Dict, max_err::Float64, row_idx::Int, p_load::_DF.DataFrame, q_load::_DF.DataFrame, p_gen::_DF.DataFrame, q_gen::_DF.DataFrame, volts::_DF.DataFrame)
    if haskey(ntw, "meas") empty!(ntw["meas"]) end
    pds = p_load[row_idx, :] 
    qds = q_load[row_idx, :] 
    pgs = p_gen[row_idx, :] 
    qgs = q_gen[row_idx, :] 
    vs = volts[row_idx, :]
    
    ntw["meas"] = Dict{String, Any}()

    loadbuses = unique([load["load_bus"] for (_, load) in ntw["load"]])
    genbuses = unique([gen["gen_bus"] for (_, gen) in ntw["gen"]])

    for c in 2:3:175
        m_idx = isempty(ntw["meas"]) ? 1 : maximum(parse.(Int, collect(keys(ntw["meas"]))))+1
        name = lowercase(names(vs)[c])[1:end-2]
        for (_,bus) in ntw["bus"]
            if bus["name"] == name && bus["index"] ∈ vcat(loadbuses, genbuses)              
                μ = abs.(strng2cmpx.([vs[c], vs[c+1], vs[c+2]]))./(bus["vbase"]*1000)
                σ = 0.002
                μ_err = []
                for μ_i ∈ μ
                    push!(μ_err, _DST.rand(_DST.Normal(μ_i, σ)))
                end 
                # dst = [_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
                dst = [_DST.Normal(μ[1], σ), _DST.Normal(μ[2], σ), _DST.Normal(μ[3], σ)]
                ntw["meas"]["$m_idx"] = Dict("var"=>:vm, "cmp"=>:bus, "cmp_id"=>bus["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")
            end
        end
    end

    for c in 2:3:82
        name = names(pds)[c][1:end-2]
        for (_,load) in ntw["load"]
            if load["name"] == name  
                # add ps!
                m_idx = isempty(ntw["meas"]) ? 1 : maximum(parse.(Int, collect(keys(ntw["meas"]))))+1   
                        
                μ = [pds[c], pds[c+1], pds[c+2]]./(ntw["settings"]["sbase"]*1000)
                
                for i in 1:length(μ)
                    if isnan(μ[i])
                        μ[i] = 0.
                    end
                end

                σ = max_err/3*_DST.mean(μ) == 0 ? max_err/3*_DST.mean(μ) : 1e-5 #TODO change error definition?
                μ_err = []
                for μ_i ∈ μ
                    push!(μ_err, _DST.rand(_DST.Normal(μ_i, σ)))
                end 
                # dst = [_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
                dst = [_DST.Normal(μ[1], σ), _DST.Normal(μ[2], σ), _DST.Normal(μ[3], σ)]
                ntw["meas"]["$m_idx"] = Dict("var"=>:pd, "cmp"=>:load, "cmp_id"=>load["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")

                # add qs!
                m_idx = isempty(ntw["meas"]) ? 1 : maximum(parse.(Int, collect(keys(ntw["meas"]))))+1   
                        
                μ = [qds[c], qds[c+1], qds[c+2]]./(ntw["settings"]["sbase"]*1000)
                
                for i in 1:length(μ)
                    if isnan(μ[i])
                        μ[i] = 0.
                    end
                end

                σ = max_err/3*_DST.mean(μ) == 0 ? max_err/3*_DST.mean(μ) : 1e-5 #TODO change error definition?
                μ_err = []
                for μ_i ∈ μ
                    push!(μ_err, _DST.rand(_DST.Normal(μ_i, σ)))
                end 
                # dst = [_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
                dst = [_DST.Normal(μ[1], σ), _DST.Normal(μ[2], σ), _DST.Normal(μ[3], σ)]
                ntw["meas"]["$m_idx"] = Dict("var"=>:qd, "cmp"=>:load, "cmp_id"=>load["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")

            end
        end
    end

    for c in 2:4
        name = names(pgs)[c]
        for (_,load) in ntw["load"] # remember you are passing loads as generators
            if load["name"] == name  
                for (p, qty) in zip([pgs, qgs], [:pd, :qd])
                    m_idx = isempty(ntw["meas"]) ? 1 : maximum(parse.(Int, collect(keys(ntw["meas"]))))+1            
                    μ = fill(-p[c]/3, 3)./(ntw["settings"]["sbase"]) # times 1000 because gen is measured in kW/kVAr
                    σ = max_err/3*_DST.mean(μ) == 0 ? max_err/3*_DST.mean(μ) : 1e-5 #TODO change error definition?
                    μ_err = []
                    for μ_i ∈ μ
                        push!(μ_err, _DST.rand(_DST.Normal(μ_i, σ)))
                    end 
                    # dst = [_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
                    dst = [_DST.Normal(μ[1], σ), _DST.Normal(μ[2], σ), _DST.Normal(μ[3], σ)]
                    ntw["meas"]["$m_idx"] = Dict("var"=>qty, "cmp"=>:load, "cmp_id"=>load["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")
                end
            end
        end
    end
end
