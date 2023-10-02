For every day (which corresponds to a subfolder), the following files are available:
- gen_kVAr_q
- gen_kW_p
are the generated power post load-allocation. lds_... are the same for the voltages.
`srcv_pu.csv` is the voltage magnitude at the slackbus.
These are used to generate `vm_pf`, i.e., phase voltage magnitudes, with power flow calculations in PowerModelsDistribution.jl.
`gen_current_A` and `load_current_A` are also derived from the power flow results, although they are used only to define the measurement noise in state estimation calculations.
State estimation can be run where the data above is the ground truth (to which noise is added).
State estimation voltages are used, e.g., as input to the solar curtailment analysis. 
Voltage results from SE are given in `twin_data/curtailment_modelling`
