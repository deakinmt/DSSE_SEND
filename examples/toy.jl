import DSSE_SEND as _DS
import Ipopt, Dates
import PowerModelsDistribution as _PMD
import CSV, DataFrames
import Distributions as _DST

toy = _DS.parse_send_ntw_eng("toy_net/dsse_xmple.dss")
toy_math = _PMD.transform_data_model(toy)

pf_sol = _PMD.solve_mc_pf(toy_math, _PMD.ACRUPowerModel, Ipopt.Optimizer)

# get vd to solution
for (b, bus) in pf_sol["solution"]["bus"]
    vi = bus["vi"]
    vr = bus["vr"]
    bus["vm"] = vi.^2+vr.^2
    bus["vd"] = [sqrt(vr[2]^2+vr[1]^2-2*vr[1]*vr[2]+vi[2]^2+vi[1]^2-2*vi[1]*vi[2]), sqrt(vr[2]^2+vr[3]^2-2*vr[3]*vr[2]+vi[2]^2+vi[3]^2-2*vi[3]*vi[2]), sqrt(vr[1]^2+vr[3]^2-2*vr[3]*vr[1]+vi[1]^2+vi[3]^2-2*vi[3]*vi[1])]
end

toy_math["meas"] = Dict{String,Any}()
m = 0
load_buses = ["$(load["load_bus"])" for (l,load) in toy_math["load"]]
gen_buses = ["$(gen["gen_bus"])" for (l,gen) in toy_math["gen"]]
for (b,bus) in pf_sol["solution"]["bus"]
    if b ∈ load_buses || b ∈ gen_buses
        m+=1
        toy_math["meas"]["$m"] = Dict{String,Any}("cmp"=>:bus,"var" => :vd, "cmp_id" => parse(Int, b), "dst" => [_DST.Normal(i, 1.0) for i in bus["vd"]], "name"=>"bus $b")
    end
end

for (l,load) in pf_sol["solution"]["load"]
    m+=1
    toy_math["meas"]["$m"] = Dict{String,Any}("cmp"=>:load,"var" => :pd, "cmp_id" => parse(Int, l), "dst" => [_DST.Normal(i, 1.0) for i in load["pd"]], "name"=>"load $l")
    m+=1
    toy_math["meas"]["$m"] = Dict{String,Any}("cmp"=>:load,"var" => :qd, "cmp_id" => parse(Int, l), "dst" => [_DST.Normal(i, 1.0) for i in load["qd"]], "name"=>"load $l")
end

for (l,gen) in pf_sol["solution"]["gen"]
    m+=1
    toy_math["meas"]["$m"] = Dict{String,Any}("cmp"=>:gen,"var" => :pg, "cmp_id" => parse(Int, l), "dst" => [_DST.Normal(i, 1.0) for i in gen["pg"]], "name"=>"gen $l")
    m+=1
    toy_math["meas"]["$m"] = Dict{String,Any}("cmp"=>:gen,"var" => :qg, "cmp_id" => parse(Int, l), "dst" => [_DST.Normal(i, 1.0) for i in gen["qg"]], "name"=>"gen $l")
end

toy_math["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler"=>1.0)

se_sol = _DS.solve_acr_mc_se(toy_math, Ipopt.Optimizer)

for (b,bus) in se_sol["solution"]["bus"]
    vi = bus["vi"]
    vr = bus["vr"]
    bus["vm"] = vi.^2+vr.^2
    bus["vd"] = [sqrt(vr[2]^2+vr[1]^2-2*vr[1]*vr[2]+vi[2]^2+vi[1]^2-2*vi[1]*vi[2]), sqrt(vr[2]^2+vr[3]^2-2*vr[3]*vr[2]+vi[2]^2+vi[3]^2-2*vi[3]*vi[2]), sqrt(vr[1]^2+vr[3]^2-2*vr[3]*vr[1]+vi[1]^2+vi[3]^2-2*vi[3]*vi[1])]
    bus["va"] = atan.(vi, vr)
end
