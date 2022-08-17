# DSSE-SEND

## Annoying warnings
If you try to use the package in julia via `using DSSE_SEND`, you'll get a loooot of annoying warning messages during compilation.
Nothing to worry about but very annoying.
They come from a dependency of PowerModelsDistributionStateEstimation, their elimination is WIP.

## Changes w.r.t. the original .dss files in order to be "parseable":

- I had to replace `redirect linecodes` on master.dss line 13 with `redirect linecodes.dss`.
- I had to comment out line 31 of master.dss, there is a problem reading the buscoords. I guess it does not matter too much at this point (I plot the networks with PowerModelsAnalytics.plot_network, that kdoesn't need buscoords)
- I had to modify the `xfmrs.dss` file. The original is now kept as `xfmrs_original.dss`. The thing is basically that the parser didn't like the "bus2=" in the bus definition


