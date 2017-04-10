*! version 1.0.0 Ishmail Azindoo Baako (IPA) Mar, 2016

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
	
		#d;
		syntax name using/,			
		ENUMVars(namelist min=2 max=2)	
		CORRFile(string)				
		LOGfile(string)					
		SAVing(string)
		RTYpe(string)
		;
		#d cr

	qui {	
		
		/***********************************************************************
		Set the stage
		***********************************************************************/
		* Check that the data specified is in a boxcrypted folder
		loc pathx = substr("`using'", 1, 1)
		if "`pathx'" != "X" & "`pathx'" != "." {
			noi di as err "dirtshfc_correct: Hello!! Using Data must be in a BOXCRYPTED folder"
			exit 601
		}
		
		* Check that type is valid
		loc rtype = lower("`rtype'")
		if "`rtype'" != "r1d1" & "`rtype'" != "r1d2" & "`rtype'" != "r2" {
			noi di as err "{p}dirtshfc_prep: SYNTAX ERROR!! Option `type' not allowed. Specify r1d1, r1d2 or r2 with type{p_end}"
			exit 601
		}

		
		* Represent the id var with the local id
		loc id `namelist'
		
		/***********************************************************************
		Import corrections file details and save it in a tempfile
		***********************************************************************/
		tempfile corr_data 
		import exc using "`corrfile'", sh(corrections) case(l) first clear
		tostring rtype, replace
		keep if rtype == "`rtype'"
		
		* Trim all string vars
		ds, has(type string)
		foreach vtt in `r(varlist)' {
			replace `vtt' = trim(`vtt')
		}
		
		* Check that the dataset contains some data. If not skip correctiosn
		count if !mi(skey)
		if `r(N)' == 0 {
			noi di in green "dirtshfc_correct: Hurray!! No need for corrections for survey `rtype'"
			
			* If there is need for corrections. Load the data into memory
			* Create a variable to mark all constraint vars as not okay
			cap confirm file "`using'"
			if !_rc {
				* Save constarint vars in a local
				import exc using "`corrfile'", sh(constraints) case(l) first clear
				tostring rtype, replace
				keep if rtype == "`rtype'" 
				levelsof variable, loc (vars) clean
				
				use "`using'", clear
				unab vars: `vars'
				foreach var in `vars' {
					gen `var'_ok = 0
				}
			}
			
			* Throw and error if file does not exist
			else {
				noi di as err "dirtshfc_correct: File `using' not found"
				exit 601
			}

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
			log using "`logfile'_`rtype'", replace text 
			
			
			* Create Header
			noi di "{hline 82}"
			noi di _dup(82) "-"
			noi di _dup(82) "*"
	
			noi di "{bf: HIGH FREQUENCY CHECKS FOR DIRTS ANNUAL SURVEY 2017}"
			noi di _column(10) "{bf:CORRECTIONS LOG - `rtype'}" 
			noi di
			noi di "{bf: Date: `c(current_date)'}"
	
			noi di _dup(82) "*"
			noi di _dup(82) "-"
			noi di "{hline 82}"
		
			use "`using'", clear
			/*******************************************************************
			Mark Flagged observations as okay. Some observatios may be flagged as 
			outliers or suspicious but upon investigation may be deemed as okay.
			********************************************************************/
			
			if `hfc_okay' > 0 {
			
				use `corr_data', clear
			
				noi di "{bf: Marking `hfc_okay' flagged issues as okay, Details are as follows:}"
				noi di
				noi di "skey" _column(15) "`id'" _column(30) "variable" _column(60) "value"
				noi di "{hline 82}"
				
				keep if action == 0
				
				* Save skeys, id, variable names and values in locals
				forval i = 1/`hfc_okay' {
					loc skey_`i' = skey[`i']
					loc `id'_`i' = `id'[`i']
					loc variable_`i' = variable[`i']
					loc value_`i' = value[`i']
				}

				* Load dataset and mark as okay. For each var, create a var *_ok
				use "`using'", clear
				forval i = 1/`hfc_okay' {
					
					* set trace on
					* Check that the skey and ids entered are in the dataset
					cap assert skey != "`skey_`i''"						
					if !_rc {
						noi di as err "dirtshfc_correct: Wrong skey(`skey_`i'') specified in correction sheet"
						exit 9
					}
					
					cap assert `id' != "``id'_`i''"						
					if !_rc {
						noi di as err "dirtshfc_correct: Wrong `id'(``id'_`i'') specified in correction sheet"
						exit 9
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
						replace `variable_`i''_ok = 1 if skey == "`skey_`i''" & `id' == "``id'_`i''" ///
							& `variable_`i'' == `value_`i''
					}
					
					* Display some details about the var been marked as okay
					noi di "`skey_`i''" _column(15) "``id'_`i''" _column(30) "`variable_`i''" _column(60) "`value_`i''"
				}
				
				* drop macros
				macro drop _skey_* _`id'_* _variable_* _value_*
	
			}
			
			* save dataset
			save "`saving'", replace
	
			noi di
	
			/*******************************************************************
			Drop Observations. Drop observations that have been marked in the 
			correction sheet to be dropped
			********************************************************************/
			
			if `hfc_drop' > 0 {
				use `corr_data', clear
				noi di "{bf: Dropped `hfc_drop' observations from the dataset, Details are as follows:}"
				noi di "skey" _column(15) "`id'"
				noi di "{hline 82}"
				
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
					
					cap assert skey != "`skey_`i''"						
					if !_rc {
						noi di as err "dirtshfc_correct: Wrong skey(`skey_`i'') specified in correction sheet"
						exit 9
					}
					
					cap assert `id' != "``id'_`i''"						
					if !_rc {
						noi di as err "dirtshfc_correct: Wrong `id'(``id'_`i'') specified in correction sheet"
						exit 9
					}

					drop if skey == "`skey_`i''" & `id' == "``id'_`i''"
					noi di "`skey_`i''" _column(15) "``id'_`i''"
				}
				
				* drop macros
				macro drop _skey_* _`id'_* _variable_* _value_*
			}
			
			* save dataset
			save "`saving'", replace
			noi di 
			
			/*******************************************************************
			Replacements
			********************************************************************/
		
			if `hfc_rep' > 0 {
				use `corr_data', clear
				noi di "{bf: Replaced `hfc_rep' flagged issues, Details are as follows:}"
				noi di "skey" _column(15) "`id'" _column(30) "variable" _column(60) "value" _column(70) "new_value" 
				noi di "{hline 82}"
				
				keep if action == 2
				
				* set trace on
				* Save skeys, hhids, variable names and values in locals
				forval i = 1/`hfc_rep' {
					loc skey_`i' = skey[`i']
					loc `id'_`i' = `id'[`i']
					loc variable_`i' = variable[`i']
					loc value_`i' = value[`i']
					loc new_value_`i' = new_value[`i']
				}
				
				use "`saving'", clear
				
				forval i = 1/`hfc_rep' {
					
					* Check that skey and id vars specified are correct
					cap assert skey != "`skey_`i''"						
					if !_rc {
						noi di as err "dirtshfc_correct: Wrong skey(`skey_`i'') specified in correction sheet"
						exit 9
					}
				
					cap assert `id' != "``id'_`i''"						
					if !_rc {
						noi di as err "dirtshfc_correct: Wrong `id'(``id'_`i'') specified in correction sheet"
						exit 9
					}
				
					cap confirm string var `variable_`i'' 
					if !_rc {
						replace `variable_`i'' = "`new_value_`i''" if skey == "`skey_`i''" & `id' == "``id'_`i''" ///
							& `variable_`i'' == "`value_`i''"
					}
					
					else {
						replace `variable_`i'' = `new_value_`i'' if skey == "`skey_`i''" & `id' == "``id'_`i''" ///
							& `variable_`i'' == `value_`i''
					}
						
					noi di "`skey_`i''" _column(15) "``id'_`i''" _column(30) "`variable_`i''" ///
						_column(60) "`value_`i''" _column(70) "`new_value_`i''"
				}
			}
		}
		noi di
		
		/***********************************************************************
		Save a copy of the data ready for hfc checks
		***********************************************************************/
		
		* Close log
		cap log close
		
		* Save file
		save "`saving'", replace		
	}
	
	
end






