Linear model of the SEND network voltage magnitudes in powers.

- the files starting with "mv_" refer only to the medium voltage buses/connections.
- those without this prefix refer to the whole network.

The linear model is of the form:
    V = Ax + b
where V are the voltage magnitudes (in V), x are the real and reactive 
power flows (in W / VAr), A is the sensivitiy matrix mapping real and 
reactive power flows to changes in voltage magnitude, and b is the no-load 
voltage. The linearization is developed using  the 'First Order Taylor' 
approach [1] (i.e., power flow Jacobian) linearized at the no-load solution.

File descriptions
---
A - sensivitiy matrix (in V/VA) with dimension n_V x 2*n_P (or n_V x n_X)
b - voltages (in V) for the linear model with dimension n_V
x0 - the power injection vector at full-load (NB +ve as generation)
vbase - vector of voltage bases in b to convert to pu (11 kV or 0.4 kV)
power_index - the power index in x0 (NB: see note below)
voltage_index - the bus index for V (or b, vbase)
readme - this file

Notes
---
- The convention used is that x0 has dimension 2 x n_P, where there are 
    n_P nodes with power injections, with the real injections in the first
    n_P nodes, then the second n_P nodes the reactive injections. The second
    half of x0 are zeros, as the full-load solution nominally is assumed to
    have unity power factor loads and injections. This follows the convention
    of [1].

- x0 is not strictly needed to run the model, and is included for illustrative
    purposes.

- To convert a voltage in 'V' to 'pu', divide through by vbase (e.g., 
    b/vbase gives b in per unit).


References
---
[1] Bernstein, Andrey, et al. "Load flow in multiphase distribution networks:
Existence, uniqueness, non-singularity and linear models." IEEE Transactions on 
Power Systems 33.6 (2018): 5832-5843.


Contact: Matthew Deakin, Newcastle University, e: matthew.deakin@newcastle.ac.uk
