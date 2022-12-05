function create_all_measurements_csv(path::String, filename::String)
    colnames = [:Id, :IsoDatetime, :v1, :v2, :v3, :i1, :i2, :i3, :p, :q, :pf]
    all_measurements = DataFrames.DataFrame(repeat([[]], 11), colnames)
    csv_dir = joinpath(_DS.BASE_DIR, path)
    for csv_file in readdir(csv_dir)
        data_df = CSV.read(joinpath(path, csv_file))
        filedf = DataFrames.DataFrame([repeat([csv_file[begin:end-4]], size(data_df)[1]), data_df.IsoDatetime, data_df.v1, data_df.v2, data_df.v3, data_df.i1, data_df.i2, data_df.i3,
                                       data_df.p, data_df.q, data_df.pf], colnames)
        all_measurements = vcat(all_measurements, filedf)
    end

    CSV.write(joinpath(path,filename), all_measurements)
    return all_measurements
end