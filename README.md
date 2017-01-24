# dirtshfc
Stata Files for High Frequency Checks, Annual Survey 2017

The repository will a do file **00_dirtshfc_master** and 5 ado files. The ado files will include:

## dirtshfc_prep
  * Prepare dataset and bc dataset from surveycto for hfc and bc. A file **dirts_annual_17_preped.dta** will be saved
  
## dirtshfc_correct
  * Check the correction sheet for data and make the neccesary changes to the data if there are corrections. A smcl log file **dirts_corr_log_*hfcdate*** will be saved with details of corrections made to the data.

## dirtshfc_run
  * Will run the various checks and bc comparisons on the data and produce a logfile **dirtshfc_log_*hfcdate*** 
  
## dirtshfc_err_rates
  * Will calculate HFC and BC error rates

## dirtshfc_clean
  * Do final cleaning on data. Also save a non pii version of the dataset 


## Install
`net install dirtshfc, all replace from(https://raw.githubusercontent.com/iabaako/dirtshfc/master)`
