Notes to the measurements:
- ss02 exist and has measurements, but these are broken
- ss30 will be installed but does not exist yet. measurements are NaN


Notes on xfmr_loading.csv:
- this is a file that contains the estimated utilization (column loading_%) of each substation. Where this value is NaN, no estimate is available.
- column "meas" indicates whether measurements are available for this substation (yes =1, no=0)
- rating_kva is the substation rating
- a rough way to create pseudo-measurements/estimated on load for non-measured substations is the multiply loading and rating


The network model is originally from M. Deakin et al ["Network Model for a Smart Energy Network Digital Twin"](https://doi.org/10.25405/data.ncl.21618342.v1), provided there under a CC BY-4.0 licence, DOI: 10.25405\/data.ncl.21618342

Context for the models and it was created is described in \[1\].

\[1\] "Smart Energy Network Digital Twins: Findings from a UK-Based Demonstrator Project.", M. Deakin, M. Vanin, Z. Fan, D. Van Hertem, under review. [Preprint here.](https://arxiv.org/pdf/2311.11997)

In this directory there are various versions of these files for different 
purposes:
- Master files:
    - master_dsse.dss 
        - the main dss file used with the DSSE code [to check]
    - master_dsse_lin.dss
        - same as master_dsse.dss, except splits generators and adds a load 
            bus at the source (not used)
    - master_dsse_lin_mv_feeder.dss
        - as master_dsse_lin.dss, but with the 4.1 km line to the MV substation 
            included to model voltage drop
    - master_dsse_unbal.dss
        - as master_dsse except loads are split into three, so that in OpenDSS
            each load can be driven independently
    - master_dsse_vsrc3ph
        - as master_dsse, except has a three-phase source, for setting unbalance
            voltages in the source voltage.
- Transformers:
    - xfrms_pre_update are the transformer models before they were updated
        heuristically as described in the paper (Fig. 8 of \[1\])
- Generators:
    - generators_dsse_lin converters generators to loads (for convenience for 
    the code used for linearization)

