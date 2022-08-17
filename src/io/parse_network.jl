"""
    parse_send_ntw_eng()::Dict

Accesses the send network's dss files and parses them to a PowerModelsDistribution `ENGINEERING` data model
"""
parse_send_ntw_eng()::Dict =
 _PMD.parse_file(joinpath(_DS.BASE_DIR, "matts_files/send_network_220812/master.dss"), data_model=_PMD.ENGINEERING)

"""
 parse_send_ntw_math()::Dict

Accesses the send network's dss files and parses them to a PowerModelsDistribution `MATHEMATICAL` data model
"""
parse_send_ntw_math()::Dict = 
 _PMD.parse_file(joinpath(_DS.BASE_DIR, "matts_files/send_network_220812/master.dss"), data_model=_PMD.MATHEMATICAL)


