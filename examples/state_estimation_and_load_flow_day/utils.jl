import DSSE_SEND as _DS
import PowerModelsDistribution as _PMD
import DataFrames as _DF
import LinearAlgebra: diagm
import Random as _RAN
import Distributions as _DST
import StatsPlots as _SP

"""
Transforms string to complex number
"""
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
"""
`volts` is like CSV.read(raw"DSSE_SEND\\twin_data\\load_allocation_cases\\2022_7_15\\voltages_volts.csv") 
"""
function build_currents_df(volts::_DF.DataFrame, p_load, q_load, p_gen, q_gen, ntw, add_str)
    cur_gen_names = ["wt_01", "wt_02", "wt_03", "storage_01", "storage_02", "storage_03","solar_01", "solar_02", "solar_03"]
    cur_df = _DF.DataFrame([name => [] for name in vcat(names(p_load), cur_gen_names)])

    for idx in 1:length(eachrow(p_load))
        load_currents = []
        for c in 2:3:82
            p1 = p_load[idx, c]
            q1 = q_load[idx, c]
            p2 = p_load[idx, c+1]
            q2 = q_load[idx, c+1]
            p3 = p_load[idx, c+2]
            q3 = q_load[idx, c+2]
            s1 = abs(p1+im*q1)
            s2 = abs(p2+im*q2)
            s3 = abs(p3+im*q3)
            load_idx = [l for (l,load) in ntw["load"] if load["name"] == names(p_load)[c][1:end-2]][1]
            load_bus = ntw["load"][load_idx]["load_bus"] 
            bus_name = ntw["bus"]["$load_bus"]["name"]       
            volt_column = findfirst(x->occursin(bus_name, x), lowercase.(names(volts)))
            v1,v2,v3 = abs(strng2cmpx(volts[idx, volt_column])), abs(strng2cmpx(volts[idx, volt_column+1])), abs(strng2cmpx(volts[idx, volt_column+2]))      
            i1, i2, i3 = s1/v1, s2/v2, s3/v3
            push!(load_currents, [i1,i2,i3]) 
        end
        gen_currents = []
        for c in 2:4
            p = p_gen[idx, c]
            q = q_gen[idx, c]
            s = abs(p+im*q)
            load_idx = [l for (l,load) in ntw["load"] if load["name"] == names(p_load)[c][1:end-2]][1]
            load_bus = ntw["load"][load_idx]["load_bus"] 
            bus_name = ntw["bus"]["$load_bus"]["name"]       
            volt_column = findfirst(x->occursin(bus_name, x), lowercase.(names(volts)))
            v1,v2,v3 = abs(strng2cmpx(volts[idx, volt_column])), abs(strng2cmpx(volts[idx, volt_column+1])), abs(strng2cmpx(volts[idx, volt_column+2]))
            i1, i2, i3 = s/(3*v1), s/(3*v2), s/(3*v3)
            push!(gen_currents, [i1,i2,i3]*1000) 
        end
        push!(cur_df, vcat(p_load[idx, 1], load_currents..., gen_currents...))
    end
    CSV.write(add_str*"xmpl_load_current_A.csv", cur_df[:, 1:end-8])
    CSV.write(add_str*"xmpl_gen_current_A.csv", hcat(cur_df[:,1],cur_df[:, end-8:end]))
    return cur_df
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
    if isa(vs[2], String)
        μ = abs.(strng2cmpx.([vs[2], vs[3], vs[4]]))./(ntw["bus"]["135"]["vbase"]*1000)
    else
        μ = [vs[2], vs[3], vs[4]]
    end
    μ_err = []
    for μ_i ∈ μ
        push!(μ_err, _DST.rand(_DST.Normal(μ_i, σ)))
    end 
    dst = [_DST.Normal(μ_err[1], σ), _DST.Normal(μ_err[2], σ), _DST.Normal(μ_err[3], σ)]
    m = maximum(parse.(Int, collect(keys(ntw["meas"]))))+1
    ntw["meas"]["$m"] = Dict("var"=>v_sym, "cmp"=>:bus, "cmp_id"=>135, "dst"=>dst, "name"=>"SOURCEBUS", "crit"=>"rwlav")
end

function add_offset_at_source_bus!(data::Dict, offset::Float64)
    for (m,meas) in data["meas"]
        if meas["var"] ∈ [:vd, :vm] && data["bus"]["$(meas["cmp_id"])"]["bus_type"] == 3
            μ = _DST.mean.(data["meas"][m]["dst"])
            σ =  _DST.std.(data["meas"][m]["dst"])
            data["meas"][m]["dst"] = [_DST.Normal(μ[i]+offset, σ[i]) for i in 1:length(μ)]
        end
    end
end

function add_measurements_se_day!(options::Dict, ntw::Dict, row_idx::Int, p_load::_DF.DataFrame, q_load::_DF.DataFrame, p_gen::_DF.DataFrame, q_gen::_DF.DataFrame, volts::_DF.DataFrame, i_df_load::_DF.DataFrame, i_df_gen::_DF.DataFrame)
  
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
        if options["voltage"] == "line" && isa(volts[1,2], String) @assert abs(strng2cmpx(volts[1,2])) > 1.1 "You want vd but are giving vm as input in `volts`" end 
        v_sym = options["voltage"] == "line" ? :vd : :vm

        m_idx = isempty(ntw["meas"]) ? 1 : maximum(parse.(Int, collect(keys(ntw["meas"]))))+1
        name = lowercase(names(vs)[c])[1:end-2]
        for (_,bus) in ntw["bus"]
            if bus["name"] == name && bus["index"] ∈ vcat(loadbuses, genbuses) && (options["full_meas_set"] || name ∈ actually_measured_devices())    
                if isa(vs[c], String)      
                    μ = abs.(strng2cmpx.([vs[c], vs[c+1], vs[c+2]]))./(bus["vbase"]*1000)
                else
                    μ = [vs[c], vs[c+1], vs[c+2]] #this is for the case in which you read pmd-generated vm in pus
                end

                dst = options["add_error"] ? dst_with_error(μ, i_df_load[row_idx,:], c, ntw, v_sym, bus["index"]) : dst_without_error(μ, .01)
                
                ntw["meas"]["$m_idx"] = Dict("var"=>v_sym, "cmp"=>:bus, "cmp_id"=>bus["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")
            end
        end
    end

    v_sym = options["voltage"] == "line" ? :vd : :vm
    add_source_volt_meas!(ntw, .01, vs, v_sym)

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

                    cmp_id = load["load_bus"]
                    # σ = max_err/3*_DST.mean(μ) == 0 ? max_err/3*_DST.mean(μ) : 1e-5 #TODO change error definition?
                    
                    dst = options["add_error"] ? dst_with_error(μ, i_df_load[row_idx,:], c, ntw, qty, cmp_id) : dst_without_error(μ, 1e-5)
                    
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
                    
                    # σ = max_err/3*_DST.mean(μ) == 0 ? max_err/3*_DST.mean(μ) : 1e-5 #TODO change error definition?
                    
                    cmp_id = load["load_bus"]
                    dst = options["add_error"] ? dst_with_error(μ, i_df_gen[row_idx,:], c, ntw, qty, cmp_id) : dst_without_error(μ, 1e-5)

                    ntw["meas"]["$m_idx"] = Dict("var"=>qty, "cmp"=>:load, "cmp_id"=>load["index"], "dst"=>dst, "name"=>name, "crit"=>"rwlav")
                end
            end
        end
    end
end

function assign_powerflow_input!(ntw, row_idx, p_load, q_load, p_gen, q_gen, volts)
    pds = p_load[row_idx, :] 
    qds = q_load[row_idx, :] 
    pgs = p_gen[row_idx, :] 
    qgs = q_gen[row_idx, :] 
    ntw["bus"]["135"]["vm"] = [abs(strng2cmpx(volts[row_idx, "SOURCEBUS.1"])), 
                               abs(strng2cmpx(volts[row_idx, "SOURCEBUS.2"])),
                               abs(strng2cmpx(volts[row_idx, "SOURCEBUS.3"]))]
    for c in 2:3:82
        name = names(pds)[c][1:end-2]
        for (_,load) in ntw["load"] 
            if load["name"] == name
                load["pd"] = [pds[c], pds[c+1], pds[c+2]]./(ntw["settings"]["sbase"]*1000)
                load["qd"] = [qds[c], qds[c+1], qds[c+2]]./(ntw["settings"]["sbase"]*1000)
            end
            load["pmin"] = [-100., -100., -100.]
            load["pmax"] = [100., 100., 100.]
            load["qmin"] = load["pmin"]
            load["qmax"] = load["pmax"]
        end
    end

    for c in 2:4
        name = names(pgs)[c]
        for (_,load) in ntw["load"] 
            if load["name"] == name  
                load["pd"] = fill(-pgs[c]/3, 3)./(ntw["settings"]["sbase"])
                load["qd"] = fill(-qgs[c]/3, 3)./(ntw["settings"]["sbase"])
            end
            load["pmin"] = [-100., -100., -100.]
            load["pmax"] = [100., 100., 100.]
            load["qmin"] = load["pmin"]
            load["qmax"] = load["pmax"]
        end
    end
end

function plot_pf_vs_se(vm_pf_pu, se_pu, opt; pick_phase = 1, plt_type = "vmdiff")
    #_SP.scalefontsizes(2/3)
    p = _SP.plot()
    start_col = "solve_time" ∈ names(se_pu) ? 5 : 4
    diff_df = se_pu[:, (start_col+pick_phase):3:179].-vm_pf_pu[:, (1+pick_phase):3:175]
    if plt_type == "vmdiff"
        p = _SP.plot!(title="$opt, phase $(pick_phase)", ylabel = "Phase voltage differences [p.u.]",
                    xtickfontsize=4,ytickfontsize=7)
        for i in eachcol(diff_df)
            p=_SP.boxplot!(i)
        end
    elseif plt_type == "vline"
        p = _SP.plot!(title="$opt, phase $(pick_phase)", ylabel = "Line voltage differences [p.u.]",
                    xtickfontsize=4,ytickfontsize=7)
        for i in eachcol(diff_df)
            p=_SP.boxplot!(i)
        end
    end
    _SP.xticks!(1:1:58, names(diff_df), xrotation = -45, legend=false)
end

dst_without_error(μ, σ) = [_DST.Normal(μi, σ) for μi in μ]

function dst_with_error(μ, i_df, c, data, var, cmp_id)
    if var ∈ [:vd, :vm]
        σ = fill(sqrt(3)*0.005/3, 3)
    else
        σ = measurement_error_model_synthetic(i_df, c, data, var, cmp_id)
    end
    μ_err = []
    for i in 1:length(μ)
        isa(σ, Float64) ? push!(μ_err, _DST.rand(_DST.Normal(μ[i], σ))) : push!(μ_err, _DST.rand(_DST.Normal(μ[i], σ[i]))) 
    end 
    return [_DST.Normal(μ_err[i] , σ[i]) for i in 1:length(μ_err)]
end
"""
see `measurement_error_model`
"""
function measurement_error_model_synthetic(i_df, c::Int, data::Dict, var::Symbol, bus_id::Int)::Vector{Float64}
    if minimum([i_df[c],i_df[c+1], i_df[c+2]]) < 120
        if var ∈ [:pd, :pg]
           max_err = fill(0.01*120*(data["bus"]["$bus_id"]["vbase"]*1000)/1e5, 3)
        elseif var ∈ [:pdt, :pgt]
            max_err = [0.01*120*(data["bus"]["$bus_id"]["vbase"]*1000)/1e5]
        elseif var ∈ [:qd, :qg]
            max_err = fill(0.02*120*(data["bus"]["$bus_id"]["vbase"]*1000/1e5), 3)
        elseif var ∈ [:qdt, :qgt]
            max_err = [0.02*120*(data["bus"]["$bus_id"]["vbase"]*1000)/1e5]
        end
    else
        if var ∈ [:pd, :pg]
            max_err = [i_df[c], i_df[c+1], i_df[c+2]]*0.01*(data["bus"]["$bus_id"]["vbase"]*1000/1e5)
        elseif var ∈ [:pdt, :pgt]
            max_err = [i_df[c]+i_df[c+1]+i_df[c+2]]*0.01*(data["bus"]["$bus_id"]["vbase"]*1000/1e5)
        elseif var ∈ [:qd, :qg]
            max_err = [i_df[c], i_df[c+1], i_df[c+2]]*0.02*(data["bus"]["$bus_id"]["vbase"]*1000/1e5)
        elseif var ∈ [:qdt, :qgt]
            max_err = [i_df[c]+i_df[c+1]+i_df[c+2]]*0.02*(data["bus"]["$bus_id"]["vbase"]*1000/1e5)
        end
    end
    return max_err./(3*data["settings"]["sbase"]) #σs in per unit
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

function plot_residuals_simple(res::DataFrames.DataFrame, pick_phase = 3)
    df = res[:, [n for n in names(res) if occursin("_p$pick_phase", n)]]
    p=_SP.plot(title="Measurement residuals, phase $(pick_phase)", ylabel = "Line voltage differences [p.u.]",
                    xtickfontsize=4,ytickfontsize=7)
    for i in eachcol(df)
        _SP.boxplot!(i)
    end
    _SP.xticks!(1:1:length(names(df)), names(df), xrotation = -45, legend=false)
end