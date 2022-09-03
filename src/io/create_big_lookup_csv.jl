function create_all_measurements_csv(;filename::String="all_measurements.csv")

    colnames = [:Id, :IsoDatetime, :v1, :v2, :v3, :i1, :i2, :i3, :p, :q, :pf, :v1_qos, :v2_qos, :v3_qos, :i1_qos, :i2_qos, :i3_qos, :p_qos, :q_qos, :pf_qos]
    all_measurements = DataFrames.DataFrame(repeat([[]], 20), colnames)

    csv_dir = joinpath(_DS.BASE_DIR, joinpath("matts_files", "data220812_out"))
    filename_begin = [filename[begin:end-9] for filename in readdir(csv_dir) if !occursin("qos", filename)]

    for csv_file in filename_begin
        data_df = CSV.read(joinpath(csv_dir, csv_file*"_data.csv"))
        qos_df =  CSV.read(joinpath(csv_dir, csv_file*"_qos.csv"))
        filedf = DataFrames.DataFrame([repeat([csv_file], size(data_df)[1]), data_df.IsoDatetime, data_df.v1, data_df.v2, data_df.v3, data_df.i1, data_df.i2, data_df.i3,
                                       data_df.p, data_df.q, data_df.pf, qos_df.v1, qos_df.v2, qos_df.v3, qos_df.i1, qos_df.i2, qos_df.i3,
                                       qos_df.p, qos_df.q, qos_df.pf], colnames)
        all_measurements = vcat(all_measurements, filedf)
    end

    CSV.write(filename, all_measurements)
    return all_measurements
end