*! version 0.0.1 Ishmail Azindoo Baako (IPA) Jan, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will make corrections to the DIRTS HFC file and prep it for the dirtshfc_run.ado

	Define sytax for program. 
	varname		: ID variable for survey
	using		: .dta file saved from dirtshfc_prep
	enumvars	: Enumerator variables. The enumerator id and then enumerator name
					variables are espected here. eg. enumv(enum_id enum_name)
	logfile		: Name for saving a log file in smcl format
	saving		: Name for saving data after correction

*/

	prog def dirtshfc_correct
	
		syntax varname using/,			///
		ENUMVars(varlist min=2 max=2)	///
		CORRFile(string)				///
		LOGfile(string)					///
		SAVing(string)

	qui {	
		
		/***********************************************************************
		Set the stage
		***********************************************************************/
		* Check that the data specified is in a boxcrypted folder
		loc pathx = substr("`directory'", 1, 1)
		if `pathx' != "X" & `pathx' != "." {
			noi di as err "dirtshfc_correct: Hello!! Using Data must be in a BOXCRYPTED folder"
			exit 601
		}
		
		* Represent the id var with the local id
		loc id `varlist'
		
		/***********************************************************************
		Import corrections file details and save it in a tempfile
		***********************************************************************/
		tempfile corr_data 
		import exc using "`corrections'", sh(enum_details) case(l) first clear
		
		* Check that the dataset contains some data. If not skip correctiosn
		if (_N==0) {
			noi di in green "dirtshfc_correct: Hurray!! No need for corrections"
		}
		
		* Running correction code if corrfile has some data
		else {
			* Check that enum_id and action do not contain non-numeric vars
			destring *_id, replace
			foreach var of varlist enum_id action {
				cap assert string variable `var'	
				if !_rc {
					noi di as error ///
						"{dirtshfc_correct: `var' has string values, only numeric values expected}"
					exit 111
				}	
			}
			
			* Get the number of corrections expected
			count if action == 0
			loc hfc_okay `r(N)'
			
			count if action == 1
			loc hfc_drop `r(N)'
			
			count if action == 2
			loc hfc_rep `r(N)'
			
			save `corr_data'
		
			/*******************************************************************
			Import the SCTO generated dataset. This dataset is what is created 
			after dirtshfc_prep.ado is runned
		    ******************************************************************/
	
			* Confirm that string specified with directory is an actual directory
			cap confirm file "`using'"
			if !_rc {
				use "`using'", clear
			}
			
			* Throw and error if file does not exist
			else {
				noi di as err "dirtshfc_correct: File `using' not found"
				exit 601
			}
		
			cap log close
			log using "`logfile'", replace
			
			
			* Create Header
			noi di "{hline 82}"
			noi di _dup(82) "-"
			noi di _dup(82) "*"
	
			noi di "{bf: HIGH FREQUENCY CHECKS FOR DIRTS ANNUAL SURVEY 2017}"
			noi di _column(10) "{bf:CORRECTIONS LOG}" 
			noi di
			noi di "{bf: Date: `c(current_date)'}"
	
			noi di _dup(82) "*"
			noi di _dup(82) "-"
			noi di "{hline 82}"
		
			use `corr_data', clear
			/*******************************************************************
			Mark Flagged observations as okay. Some observatios may be flagged as 
			outliers or suspicious but upon investigation may be deemed as okay.
			********************************************************************/
			
			if `hfc_drop' > 0 {
			
				use `corr_data', clear
			
				noi di as title "{bf: Marked `hfc_okay' flagged issues as okay, Details are as follows:"
				noi di as title "s_key" _column(15) as title "`id'" _column(25) as title "variable" _column(40) as title "value"
				
				keep if action == 0
				
				* Save s_keys, id, variable names and values in locals
				forval i = 1/`hfc_okay' {
					loc skey_`i' = skey[`i']
					loc `id'_`i' = `id'[`i']
					loc variable_`i' = variable[`i']
					loc value_`i' = value[`i']
				}

				* Load dataset and mark as okay. For each var, create a var *_ok
				use "`using'", clear
				forval i = 1/`hfc_okay' {
				
					* Check that the entries in the correction sheets are valid
					foreach name in "`skey_`i''" "``id'_`i''" "`variable_`i''" "`value'_`i'" {
						* Get the actual name of the variable
						loc name = substr("`name'", 1, length(`name') - length(`i')) 
						
						* Check that value is in the dataset before dropping
						cap assert `name' != "``name'_`i''"
						if !_rc {
							noi di as err "dirtshfc_correct: Wrong skey(``name'_`i'') specified in correction sheet"
							exit 9
						}
					}
				
					* Check if the variable marker exist, else create it
					cap confirm var `variable_`i''_ok 
					if _rc == 111 {
						gen `variable_`i''_ok = 0
					}
				
					cap confirm string var `variable_`i'' 
					if !_rc {
						replace `variable_`i''_ok = 1 if skey == "`skey_`i''" & `id' == "``id'_`i''" ///
							& `variable_`i'' == "`value_`i''"
					}
					
					else {
						replace `variable_`i''_ok = 1 if skey == "`skey_`i''" & hhid == "``id'_`i''" ///
							& `variable_`i'' == `value_`i''
					}
					
					* Display some details about the var been marked as okay
					noi di as title "`skey_`i''" _column(15) as title "``id'_`i''" _column(25) ///
						as title "`variable_`i''" _column(40) as title "`value_`i''"
				}
				
				* save dataset
				save "`saving'", replace
				
				* drop macros
				macro drop _skey_* _`id'_* _variable_* _value'_*
	
			}
			
			noi di
			
			/*******************************************************************
			Drop Observations. Drop observations that have been marked in the 
			correction sheet to be dropped
			********************************************************************/
			
			if `hfc_drop' > 0 {
				use `corr_data', clear
				noi di as title "{bf: Dropped `hfc_drop' observations from the dataset, Details are as follows:"
				noi di as title "skey" _column(15) as title "`id'"
				
				*keep only observations in corr sheet that will be dropped
				keep if action == 1
				
				* Save skeys and hhids in locals
				forval i = 1/`hfc_drop' {
					loc skey_`i' = skey[`i']
					loc `id'_`i' = `id'[`i']
				}
				
				* Load the dataset, loop through and drop the obs with matching keys and hhids
				use "`saving'", clear
				forval i = 1/`hfc_drop' {
					* Check that the entries in the correction sheets are valid
					foreach name in "`skey_`i''" "``id'_`i''" {
						* Get the actual name of the variable
						loc name = substr("`name'", 1, length(`name') - length(`i')) 
						
					
						* Check that value is in the dataset before dropping
						cap assert `name' != "``name'_`i''"
						if !_rc {
							noi di as err "dirtshfc_correct: Wrong skey(``name'_`i'') specified in correction sheet"
							exit 9
						}
					}

					
					drop if skey == "`skey_`i''" & `id' == "``id'_`i''"
					noi di as "`skey_`i'" _column(15) "``id'_`i''"
				}
				
				* save dataset
				save "`saving'", replace
				
				* drop macros
				macro drop _skey_* _`id'_* _variable_* _value'_*
			}
			
			noi di 
			
			/*******************************************************************
			Replacements
			********************************************************************/
		
			if `hfc_rep' > 0 {
				use `corr_data', clear
				noi di as title "{bf: Replaced `hfc_rep' flagged issues, Details are as follows:"
				noi di as title "skey" _column(15) as title "`id'" _column(25) ///
					as title "variable" _column(40) as title "value" _column(55) as title "new_value" 
				
				keep if action == 2
				
				* Save s_keys, hhids, variable names and values in locals
				forval i = 1/`hfc_rep' {
					loc skey_`i' = skey[`i']
					loc `id'_`i' = `id'[`i']
					loc variable_`i' = variable[`i']
					loc value_`i' = value[`i']
					loc new_value_`i' = new_value[`i']
				}
				
				use "`saving'", cllear
				
				* Check that the entries in the correction sheets are valid
				foreach name in "`skey_`i''" "``id'_`i''" "`variable_`i''" "`value'_`i'" "`new_value_`i''" {	
					* Get the actual name of the variable
					loc name = substr("`name'", 1, length(`name') - length(`i')) 
						
					* Check that value is in the dataset before dropping
					cap assert `name' != "``name'_`i''"
					if !_rc {
						noi di as err "dirtshfc_correct: Wrong skey(``name'_`i'') specified in correction sheet"
						exit 9
					}
				}
								
				cap confirm string var `variable_`i'' 
				if !_rc {
					replace `variable_`i'' = "`new_value'" if s_key == "`skey_`i''" & `id' == "``id'_`i''" ///
						& `variable_`i'' == "`value_`i''"
				}
					
				else {
					replace `variable_`i'' = `new_value' if skey == "`skey_`i''" & `id' == "`hhid'" ///
						& `variable_`i'' == `value_`i''
				}
						
				noi di as title "`skey_`i''" _column(15) as title "``id'_`i''" _column(25) ///
					as title "`variable_`i''" _column(40) as title "`value_`i''" _column(55) as title "`new_value_`i''"
			}
		}
		noi di
		
		/***********************************************************************
		Save a copy of the data ready for hfc checks
		***********************************************************************/
		
		* Close log
		log close
		
		* Save file
		save "`saving'", replace		
	}
	
	
end






