# Guide to the examples folder

## Running examples based on DSSE_SEND

The files in `DSSE_SEND/src`, `DSSE_SEND/Project.toml` constitute the core of the `DSSE_SEND` julia package.

This folder has a separate environment, which can be activated from a Julia REPL by:
```julia
cd("examples")
import Pkg
Pkg.activate("..")
```
(or with the package manager as an alternative to using `Pkg`).

The `DSSE_SEND` module/package is part of this environment, as the goal of the examples in this folder is to illustrate what type of analyses could be performed with the SEND digital twin.
The dependencies of the `examples` are reported in the `examples/Project.toml` file. These can include plotting packages, etc., that are not part of the core of `DSSE_SEND` but could
be used for visualisation, etc.

### Known set-up issue
After the examples environment is activated, try to run the following
```julia
import DSSE_SEND
``` 
if an error is returned, please do:
```julia
Pkg.rm("DSSE_SEND")
Pkg.develop("DSSE_SEND")
```
this should be needed only the first time you download/use the package on your machine.

### Additional issues
Note that the files in this folder are meant for illustration/inspiration for users that want to use the SEND_DSSE package, and there may not be seamless integration /consistent naming across the different files here.
However, should any relevant problem occur, please raise an issue on github or send us an e-mail.

## List of examples
- `linear_model`
    - `linear_model_max_gen.jl` shows the use of the linear DSSE_SEND model to calculate the maximum power generation allowable on 17/09/2022 (see section V of the paper)
    - `linear_model_utils.jl` contains extra functions needed to run the above
- `state_estimation_and_power_flow`
    - `power_flow_to_create_synthetic_meas.jl` shows how to run power flows from "cleaned-up" SEND measurement-based powers (see the brief explanation of csv files below). These can be used as ground truth for DSSE
    - `state_estimation_synthetic_meas.jl` shows how to run DSSE with synthetic measurements (several options thereof)
    - `state_estimation_with_tap_settings_analysis.jl` shows how to parse network data with off or ok tap settings, and run DSSE on them (with actual measurements)
    - `utils.jl` contains helper functions for this folder
    - brief explanation of the csv files:
        - Generation values in `xmpl_load_flow_gen...` are in kW/kVAr , loads in `xmpl_load_flow_lds...` are in W/VAr.
            The powers come from 5' SEND measurements for a July day. Generation values are aggregated (sum of power across the three phases is given) as these are assumed to be balanced later on (same power per phase). Unbalance is included in the loads, with the following procedure:
            - the "residual" power flow (rpf) is calculated. This is the difference between the transfo supply at the PCC and the monitored loads
            - the rpf is allocated with a uniform random distribution between all loads
            - The voltages stem from power flow calculations with PowerModelsDistribution. Their type (line vs phase voltage, or angles) and unit (pu, volts, rads) are indicated in the file names.
            The power from the files explained above is used as input for the power flow calculations to generate these voltage results.
            The script with power flow calculations is `power_flow_to_create_synthetic_v.jl` in this directory.
            - `measured_devices.csv` contains a list of which substations have measurements in the real SEND systems (not all of them do), and is just used for mapping purposes for test cases, e.g., where we want to assign synthetic measurements only to subset of monitored substations in SEND (otherwise for synthetic measurements we assume that all substations are measured).
- `tap_plots`
    - `plot_function.jl` file containing the plot function used to generate the plots (as shown in `tap_plots.jl`)
    - `tap_analyses_aggr_2 minutes_oktaps.csv`  file with DSSE residual values with improved tap settings in the network model
    - `tap_analyses_aggr_2 minutes_offtaps.csv` file with DSSE residual values with wrong tap settings in the network model
    - `tap_plots.jl` shows how to use the function and csv files above to generate plots like Fig. 9 in the paper