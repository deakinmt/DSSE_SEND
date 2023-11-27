Notes to the measurements:
- ss02 exist and has measurements, but these are broken
- ss30 will be installed but does not exist yet. measurements are NaN


Notes on xfmr_loading.csv:
- this is a file that contains the estimated utilization (column loading_%) of each substation. Where this value is NaN, no estimate is available.
- column "meas" indicates whether measurements are available for this substation (yes =1, no=0)
- rating_kva is the substation rating
- a rough way to create pseudo-measurements/estimated on load for non-measured substations is the multiply loading and rating


The network model is originally from M. Deakin et al ["Network Model for a Smart Energy Network Digital Twin"](https://doi.org/10.25405/data.ncl.21618342.v1), provided there under a CC BY-4.0 licence, DOI: 10.25405/data.ncl.21618342
