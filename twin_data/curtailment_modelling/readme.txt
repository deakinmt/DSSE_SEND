Data for modelling curtailment for the SEND demonstrator
M. Deakin, June 2023, e: matthew.deakin@newcastle.ac.uk

Accurate modelling of curtailment is complex. SEND does not have a module for 
estimating the quantity of solar power built-in, and it is beyond the scope of
this work to develop a detailed model for this task. (NB, what is known is days
when there *has* been curtailment.) The files here are intended to support 
estimating what this curtailment could have plausibly been (i.e., a 
counterfactual). Future work could develop this modelling more completely, e.g., 
taking into account the direction of the panels, panel temperature, weather
forecasts at Keele, losses, performance on similar days, etc.

The solar is of size 5.5 MW behind a 4.4 MW inverter. National embedded solar 
capacity factors from [1] have been normalised then scaled according to these 
factors to create a 'base' profile; a heuristic scaling and shifting of the
difference between the base profile and the measured data have then been added
to take into account non-ideal matching between those profiles to derive
the curtailment estimate in solar_curt_model. The paper describing this work
will include the by-eye validation of these curtailment estimates.

solar_model.csv [in MW]:
 - The 'base' profile, as a 5.5 MW PV plant behind a 4.4 MVA grid connection. 
    Each row corresponds to a 30 second period of the day, hence has length
    2 x 60 x 24 = 2880.

solar_curt_model.csv [in MW]:
 - The modelled curtailment, also in MW. The tows are also each 30 second 
    period.


Reference:
[1] Grant Wilson, & Noah Godfrey. (2021). Electrical half hourly raw and cleaned 
datasets for Great Britain from 2009-11-05 (4.0.0) [Data set]. Zenodo. 
DOI: https://doi.org/10.5281/zenodo.4573715