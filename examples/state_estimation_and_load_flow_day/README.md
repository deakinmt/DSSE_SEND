This directory contains files with power generation/demand, and scripts to run state estimation and/or power flow.
The .jl scripts are commented/explained at their top.
The csv files are explained below:
- Generation values in `xmpl_load_flow_gen...` are in kW/kVAr , loads in `xmpl_load_flow_lds...` are in W/VAr.
  The powers come from 5' SEND measurements for a July day. Generation values are aggregated (sum of power across the three phases is given) as these are assumed to be balanced later on (same power per phase). Unbalance is included in the loads, with the following procedure:
  - the "residual" power flow (rpf) is calculated. This is the difference between the transfo supply at the PCC and the monitored loads
  - the rpf is allocated with a uniform random distribution between all loads
- The voltages stem from power flow calculations with PowerModelsDistribution. Their type (line vs phase voltage, or angles) and unit (pu, volts, rads) are indicated in the file names.
  The power from the files explained above is used as input for the power flow calculations to generate these voltage results.
  The script with power flow calculations is `power_flow_to_create_synthetic_v.jl` in this directory.
- `measured_devices.csv` contains a list of which substations have measurements in the real SEND systems (not all of them do), and is just used for mapping purposes for test cases, e.g., where we want to assign synthetic measurements only to subset of monitored substations in SEND (otherwise for synthetic measurements we assume that all substations are measured).