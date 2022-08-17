parse_send_ntw_eng()::Dict =
 _PMD.parse_file(joinpath(BASE_DIR, "matts_files/send_network_220812/master.dss"), data_model=_PMD.ENGINEERING)

 parse_send_ntw_math()::Dict = 
 _PMD.parse_file(joinpath(BASE_DIR, "matts_files/send_network_220812/master.dss"), data_model=_PMD.MATHEMATICAL)