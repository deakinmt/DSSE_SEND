SEND distribution network model, created July / August 2022.

Based on documents:
- Keele HV SLD
- MPN Fault level + Load flow


There is a script, .../miscScripts/send_demo/send_model/create_send_dss.py
used to create some of these DSS files.

Notes. 
- linecodes - created manually. A few weird things going on in here with
  differences for the same cable type (from lines table in MPN)
- lines - from the script above
- xfmrs - from the script above
- master - created manually
- generators - created manually