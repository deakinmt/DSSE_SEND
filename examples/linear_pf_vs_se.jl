import DSSE_SEND as _DS
import CSV
import Dates, Ipopt

include("linear_pf_utils.jl")

A,b,vbase,v_idx,p_idx, x0 = get_Abvvpx()

x1 = build_x0(p_idx, timestep)

data  = _DS.default_network_parser(;adjust_tap_settings=true)
_DS.assign_se_settings!(data)
_DS.assign_voltage_bounds!(data , vmin=0.8, vmax=1.3)

time_step_begin = Dates.DateTime(2022, 07, 15, 12, 14, 30)
time_step_end = time_step_begin+Dates.Minute(10)
time_step_step = Dates.Minute(2)
aggregation = time_step_step

exclude = ["ss02", "ss17"]
_DS.add_measurements!(time_step_begin, data , aggregation, exclude = exclude, add_ss13=true) # this is just to initialize the result dataframe
meas_names = [meas["name"] isa Vector ? meas["name"][1] : meas["name"] for (_,meas) in data["meas"]]

cols = vcat("timestep", "termination_status", "objective", 
            [name*"_p1" for name in unique(meas_names)], [name*"_p2" for name in unique(meas_names)], [name*"_p3" for name in unique(meas_names)])

# perturbation percentage 
pperc = 1.01

align_dsse_and_linear_model!(data)

plot_indices = []
plot_xticks = []
for (m, meas) in data["meas"]
    if meas["name"][1] ∉ vcat(plot_xticks, 's')
        if meas["name"][1] ∈ ["storage", "wt", "solar"]
            if meas["name"][1] == "solar" 
                push!(plot_indices, findfirst(x->occursin("RMU2", x), v_idx))
            elseif meas["name"][1] == "wt" 
                push!(plot_indices, findfirst(x->occursin("TX3", x), v_idx))
            else
                push!(plot_indices, findfirst(x->occursin("TX5", x), v_idx))
            end
            push!(plot_xticks, meas["name"][1])
        else
            push!(plot_indices, findfirst(x->occursin(uppercase(meas["name"][1]), x), v_idx))
            push!(plot_xticks, meas["name"][1])
        end
    end
end

for ts in time_step_begin:time_step_step:time_step_end

    _DS.add_measurements!(ts, data, aggregation, exclude = exclude, add_ss13=true) 
    
    se_sol  = _DS.solve_acr_mc_se(data, Ipopt.Optimizer)
    
    _DS.post_process_dsse_solution!(se_sol)

    vs = get_voltages_tidy(se_sol, data, plot_xticks, "vd")
    ps =  get_powers_tidy(se_sol, p_idx, "pd")
    qs =  get_powers_tidy(se_sol, p_idx, "qd")
    pp = perturb_powers(ps, pperc)
    vp = (A*vcat(pp, qs)+b)./vbase


    #TODO plot voltages for laod with measurement only

end

# the phase voltages are floating, so comparing the ones from the lpf to those of the state estimation does not make sense!
# what we could do is run state estimation and then use the derived powers to estimate vm 

ρ  = _DS.get_voltage_residuals_one_ts(data, se_sol, in_volts=false)

vp_idx_p1 = [vp[i] for i in plot_indices]
vp_idx_p2 = [vp[i[1]+1] for i in plot_indices]
vp_idx_p3 = [vp[i[1]+2] for i in plot_indices]

scatter(vs[2:3:end])
scatter!(vp_idx_p1)