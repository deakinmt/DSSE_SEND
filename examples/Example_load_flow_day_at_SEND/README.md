Generation values are in kW/kVAr , loads in W/VAr.
The voltages stem from power flow calculations with OpenDSS.
Power input are 5' values for a day. 
Unbalance is included in the loads, with the following procedure:
- the "residual" power flow (rpf) is calculated. This is the difference between the transfo supply at the PCC and the monitored loads
- the rpf is allocated with a uniform random distribution between all loads
To include unbalance, two of the original .dss files had to be changed : `loads_dsse.dss` --> `loads_dsse_unbal.dss`, `master_dsse.dss` --> `master_dsse_unbal.dss`