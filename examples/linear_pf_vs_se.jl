import DSSE_SEND as _DS
import CSV
import Dates

A = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mdl_A.csv"), header=0))
b = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/mdl_b.csv"), header=0))

vbase = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/vbase.csv"), header=0))

p_idx = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/power_index.csv"), header=0))

timestep = Dates.DateTime(2022, 05, 13, 12, 00, 00)

x1 = build_x0(p_idx, timestep)
x0 = Matrix(CSV.read(joinpath(_DS.BASE_DIR, "twin_data/linear_send_network_model/x0.csv"), header=0))

v = A*x1+b

v./vbase

function build_x0(p_idx::Matrix{String}, timestep::Dates.DateTime; power_partition::String="balanced")
    day = Dates.Day(timestep).value
    month = Dates.Month(timestep).value
    file = joinpath(_DS.BASE_DIR, "twin_data/telemetry/2022_$(month)_$(day)/all_measurements_$(month)_$(day).csv")
    df = CSV.read(file)
    df.p = df.p * 1000 #now in W
    df.q = df.q * 1000 #now in W
    ts_df = filter(x->x.IsoDatetime .== timestep, df)
    x0 = Matrix{Float64}(undef, length(p_idx)*2, 1)
    pseudos = _DS.get_max_ss_loads()
    for start_idx in [0, 96] # first 96/ indices are active power, rest is reactive
        for i in 1:3:Int(length(x0)/2) 
            idx = lowercase.(p_idx)[i]
            # phase = Int(idx[end])
            cmp = occursin("_lv", idx) ? idx[1:end-5] : idx[1:end-2]
            if cmp == "tx3"
                p = filter(x->x.Id .== "wt", ts_df).p[1]               
                q = filter(x->x.Id .== "wt", ts_df).q[1]               
                PQ1, PQ2, PQ3 = start_idx == 0 ? subdivide_power(p, power_partition) : subdivide_power(q, power_partition)
            elseif cmp == "tx5"
                p = filter(x->x.Id .== "storage", ts_df).p[1]               
                q = filter(x->x.Id .== "storage", ts_df).q[1]               
                PQ1, PQ2, PQ3 = start_idx == 0 ? subdivide_power(p, power_partition) : subdivide_power(q, power_partition)
            elseif cmp == "rmu2"
                p = filter(x->x.Id .== "solar", ts_df).p[1]               
                q = filter(x->x.Id .== "solar", ts_df).q[1]               
                PQ1, PQ2, PQ3 = start_idx == 0 ? subdivide_power(p, power_partition) : subdivide_power(q, power_partition)
            elseif cmp ∈ ts_df.Id
                usr_df = filter(x->x.Id .== cmp, ts_df)
                PQ1, PQ2, PQ3 = start_idx == 0 ? subdivide_power(usr_df.p[1], power_partition) : subdivide_power(usr_df.q[1], power_partition)
            elseif cmp ∈ collect(keys(pseudos))
                PQ1, PQ2, PQ3 = start_idx == 0 ? fill(pseudos[cmp]*1000/3, 3) : zeros(3) # x1000 so it's in Watts
            else
                PQ1, PQ2, PQ3 = zeros(3)
            end
            x0[start_idx+i]   = PQ1
            x0[start_idx+i+1] = PQ2
            x0[start_idx+i+2] = PQ3
        end
    end
    return replace(x0, NaN=>0)
end

function subdivide_power(P::Float64, power_partition::String)
    if power_partition == "balanced"
        P1, P2, P3 = P/3, P/3, P/3
    end
    return P1, P2, P3
end