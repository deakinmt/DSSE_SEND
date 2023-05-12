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
        return -re-img*im
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

function get_va_in_rads(volts::_DF.DataFrame)
    va_r = DataFrames.DataFrame([name => [] for name in names(volts)])
    for row in eachrow(volts)
        n = [strng2cmpx(row[c]) for c in 2:length(row)]
        va = [atan(imag(j),real(j)) for j in n]
        push!(va_r, vcat(row.IsoDatetime, va))
    end
    return va_r
end

function get_vd_in_pus(vm_pu::_DF.DataFrame, va::_DF.DataFrame)
    vd_r = DataFrames.DataFrame([name => [] for name in names(va)])
    for idx in 1:size(va)[1]
        varow = va[idx,:]
        vmrow = vm_pu[idx,:]
        vd = []
        for col in 2:3:length(vmrow)
            vd1 = sqrt(vmrow[col]^2+vmrow[col+1]^2-2*vmrow[col+1]*vmrow[col]*cos(varow[col+1]-varow[col]))
            vd2 = sqrt(vmrow[col+2]^2+vmrow[col+1]^2-2*vmrow[col+1]*vmrow[col+2]*cos(varow[col+1]-varow[col+2]))
            vd3 = sqrt(vmrow[col]^2+vmrow[col+2]^2-2*vmrow[col+2]*vmrow[col]*cos(varow[col+2]-varow[col]))
            push!(vd, [vd1,vd2,vd3])
        end
        push!(vd_r, vcat(va.IsoDatetime[idx], vd...))
    end
    return vd_r
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

function add_source_volt_meas!(ntw, σ, vs, v_sym) 
    μ = abs.(strng2cmpx.([vs[2], vs[3], vs[4]]))./(ntw["bus"]["135"]["vbase"]*1000)
    μ_err = []
    for μ_i ∈ μ
        push!(μ_err, _DST.rand(_DST.Normal(μ_i, σ)))
    end 
    dst = [_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
    m = maximum(parse.(Int, collect(keys(ntw["meas"]))))+1
    ntw["meas"]["$m"] = Dict("var"=>v_sym, "cmp"=>:bus, "cmp_id"=>135, "dst"=>dst, "name"=>"SOURCEBUS", "crit"=>"rwlav")
end


function add_measurements_se_day!(options::Dict, ntw::Dict, max_err::Float64, row_idx::Int, p_load::_DF.DataFrame, q_load::_DF.DataFrame, p_gen::_DF.DataFrame, q_gen::_DF.DataFrame, volts::_DF.DataFrame)
  
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
        if options["voltage"] == "line" @assert abs(strng2cmpx(volts[1,2])) > 1.1 "You want vd but are giving vm as input in `volts`" end 
        v_sym = options["voltage"] == "line" ? :vd : :vm

        m_idx = isempty(ntw["meas"]) ? 1 : maximum(parse.(Int, collect(keys(ntw["meas"]))))+1
        name = lowercase(names(vs)[c])[1:end-2]
        for (_,bus) in ntw["bus"]
            if bus["name"] == name && bus["index"] ∈ vcat(loadbuses, genbuses) && (options["full_meas_set"] || name ∈ actually_measured_devices())             
                μ = abs.(strng2cmpx.([vs[c], vs[c+1], vs[c+2]]))./(bus["vbase"]*1000)
                σ = 0.002
                μ_err = []
                for μ_i ∈ μ
                    push!(μ_err, _DST.rand(_DST.Normal(μ_i, σ)))
                end 
                dst = [_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
                
                ntw["meas"]["$m_idx"] = Dict("var"=>v_sym, "cmp"=>:bus, "cmp_id"=>bus["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")
            end
        end
    end

    σ = 0.002
    v_sym = options["voltage"] == "line" ? :vd : :vm
    add_source_volt_meas!(ntw, σ, vs, v_sym)

    p_sym = options["power"] == "per_phase" ? :pd : :pdt  
    q_sym = options["power"] == "per_phase" ? :qd : :qdt  

    for c in 2:3:82
        name = names(pds)[c][1:end-2]

        for (_,load) in ntw["load"]
            if load["name"] == name && (options["full_meas_set"] || name ∈ actually_measured_devices())
                for (p, qty) in zip([pds, qds], [p_sym, q_sym])

                    ############################
                    ##### ADD P MEASUREMENTS
                    ############################
                    m_idx = isempty(ntw["meas"]) ? 1 : maximum(parse.(Int, collect(keys(ntw["meas"]))))+1   
                    
                    if options["power"] == "per_phase"
                        μ = [p[c], p[c+1], p[c+2]]./(ntw["settings"]["sbase"]*1000)
                    else
                        μ = [sum([p[c], p[c+1], p[c+2]])]./(ntw["settings"]["sbase"]*1000)
                    end

                    σ = max_err/3*_DST.mean(μ) == 0 ? max_err/3*_DST.mean(μ) : 1e-5 #TODO change error definition?
                    
                    μ_err = []
                    for μ_i ∈ μ push!(μ_err, _DST.rand(_DST.Normal(μ_i, σ))) end
                    dst = [_DST.Normal(i, σ) for i in μ_err]
                    
                    ntw["meas"]["$m_idx"] = Dict("var"=>qty, "cmp"=>:load, "cmp_id"=>load["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")

                end
            end
        end
    end

    for c in 2:4
        name = names(pgs)[c]
        for (_,load) in ntw["load"] # remember you are passing generators as loads
            if load["name"] == name  
                for (p, qty) in zip([pgs, qgs], [p_sym, q_sym])
                    m_idx = isempty(ntw["meas"]) ? 1 : maximum(parse.(Int, collect(keys(ntw["meas"]))))+1        

                    if options["power"] == "per_phase"
                        μ = fill(-p[c]/3, 3)./(ntw["settings"]["sbase"]) # not divided by 1000 because gen is measured in kW/kVAr
                    else
                        μ = [-sum(p[c])]./(ntw["settings"]["sbase"])
                    end
                    
                    σ = max_err/3*_DST.mean(μ) == 0 ? max_err/3*_DST.mean(μ) : 1e-5 #TODO change error definition?
                    
                    μ_err = []
                    for μ_i ∈ μ push!(μ_err, _DST.rand(_DST.Normal(μ_i, σ))) end 
                    dst = [_DST.Normal(i, σ) for i in μ_err]

                    ntw["meas"]["$m_idx"] = Dict("var"=>qty, "cmp"=>:load, "cmp_id"=>load["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")
                end
            end
        end
    end
end

function plot_pf_vs_se(vm_pf_pu, se_pu; pick_phase = 1, plt_type = "diff")
    if plt_type == "diff"
        start_col = "solve_time" ∈ names(se_pu) ? 5 : 4
        diff_df = se_pu[:, (start_col+pick_phase):3:178].-vm_pf_pu[:, (1+pick_phase):3:175]
        p = _SP.plot(title="Differences - phase $(pick_phase)")
        for i in eachcol(diff_df)
            _SP.boxplot!(i)
        end
        _SP.xticks!(1:1:58, names(diff_df), xrotation = -45, legend=false)
        p
    end
end

function actually_measured_devices()
    return ["solar",
            "ss02",
            "ss03",
            "ss04",
            "ss05",
            "ss11",
            "ss12",
            "ss13_1",
            "ss13_2",
            "ss14",
            "ss15",
            "ss16",
            "ss17",
            "ss18",
            "ss19",
            "ss21",
            "ss24",
            "ss25",
            "ss29",
            "ss30",
            "storage",
            "t01",
            "t02",
            "wt"
        ]    
end