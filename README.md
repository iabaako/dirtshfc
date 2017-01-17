# dirtshfc
Stata Files for High Frequency Checks, Annual Survey 2017

The repository will a do file **00_master** and 3 ado files. The ado files will include:

## dirtshfc_clean
  * Clean the data from surveycto and prepare it for hfc. A file **dirts_annual_17_prehfc_clean.dta** will be saved
  
## dirtshfc_correct
  * Check the correction sheet for data and make the neccesary changes to the data if there are corrections. A smcl log file **dirts_corr_log_*hfcdate*** will be saved with details of corrections made to the data.

## dirtshfc_run
  * Will run the various checks on the data and produce a logfile **dirtshfc_log_*hfcdate*** 
