import DSSE_SEND as _DS
import PowerModelsDistribution as _PMD
import DataFrames as _DF
import LinearAlgebra: diagm
import Random as _RAN
import Distributions as _DST
import StatsPlots as _SP

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
                dst = [_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
                # dst = [_DST.Normal(μ[1], σ), _DST.Normal(μ[2], σ), _DST.Normal(μ[3], σ)]
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
                dst = [_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
                # dst = [_DST.Normal(μ[1], σ), _DST.Normal(μ[2], σ), _DST.Normal(μ[3], σ)]
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
                    dst = [_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
                    # no error: dst = [_DST.Normal(μ[1], σ), _DST.Normal(μ[2], σ), _DST.Normal(μ[3], σ)]
                    ntw["meas"]["$m_idx"] = Dict("var"=>qty, "cmp"=>:load, "cmp_id"=>load["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")
                end
            end
        end
    end
end

function aggregate_phase_meas!(ntw::Dict)

end

function vm2vd!(ntw::Dict)
    
end

function remove_synthetic_meas!(ntw::Dict)
    
end

function plot_pf_vs_se(vm_pf_pu, se_pu; pick_phase = 1, plt_type = "diff")
    if plt_type == "diff"
        diff_df = se_pu[:, (4+pick_phase):3:178].-vm_pf_pu[:, (1+pick_phase):3:175]
        p = _SP.plot(title="Differences - phase $(pick_phase)")
        for i in eachcol(diff_df)
            _SP.boxplot!(i)
        end
        _SP.xticks!(1:1:58, names(diff_df), xrotation = -45, legend=false)
        p
    end

end