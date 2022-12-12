function update_tap_setting!(ntw_eng::Dict)
    xfmrs_file = joinpath(_DS.BASE_DIR, "twin_data/send_network_model/xfmrs_dsse.dss")
    f = open(xfmrs_file) 
    for line in readlines(f)
        spl = split(line, " ")
        tr = spl[2][13:end]
        if occursin("tap", spl[end])
            tapset = parse(Float64, spl[end][5:end]) 
            ntw_eng["transformer"][tr]["tm_set"] = [[1.0, 1.0, 1.0], [tapset, tapset, tapset]]
        end
    end
    close(f)
end

function drop_ss_meas!(math::Dict)
    

end