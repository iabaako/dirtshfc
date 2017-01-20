*! version 0.0.0 Ishmail Azindoo Baako (IPA) Jan, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will make corrections to the DIRTS HFC file and prep it for the dirtshfc_run.ado
*/ 

/* Define sytax for program. 
*/

	program define dirtshfc_prep
	
		syntax,
		DIRECTory(string)
		DATAset(string)
		CORRFile(string)
		LOGfile(string)
		SAVing(string)

	qui {	
		
		/***********************************************************************
		Set the stage
		***********************************************************************/
		// Save the name of the present working directory
		loc hfcpwd = c(pwd)
		
		// Check that the directory specified as is encrypted with Boxcryptor
		loc pathx = substr("`directory'", 1, 1)
		if `pathx' != "X" {
			noi di as err "dirtshfc_correct: Hello!! Folder specified with directory must be BOXCRYPTED"
			exit 601
		}
		
		/***********************************************************************
		Import corrections file details and save it in a tempfile
		***********************************************************************/
		tempfile corr_data 
		
		import excel using "`corrections'", sh(enum_details) case(l) first clear
		
		
		// Check that the dataset contains some data. If not skip correctiosn
		if (_N==0) {
			noi di in green "dirtshfc_correct: Hurray!! No need for corrections"
			
		}
		
		else {
			
			// Check that enum_id and action do not contain non-numeric vars
			destring *_id, replace
			
			foreach var of varlist enum_id action {
			cap assert string variable `var'	
				if !_rc {
					noi di as error ///
						"{dirtshfc_correct: `var' has string values, only numeric values expected}"
					exit 111
				}	
			}
			
			// Get the number of corrections needed to be made
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
	
			// Confirm that string specified with directory is an actual directory
			cap confirm file "`directory'/nul"
			if !_rc {
			
				// Change working directory to the data directory if directory exist
				cd "`directory'"
			
				cap confirm file "`dataset'"
				if !_rc {
					use "`dataset'", clear
				}
			
				// Throw and error if file does not exist
				else {
			
					noi di as err "dirtshfc_correct: File `dataset' not found in `directory'"
					exit 601
				}
			}
		
			// If directory does not exist
			else {
			
				noi di as err "`directory' does not found"
				exit 601
			}
		
			cap log close
			log using "`logfile'", replace
			
			
			// Create Header
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
				noi di as title "s_key" _column(15) as title "hhid" _column(25) as title "variable" _column(40) as title "value"
				
				keep if action == 0
				
				// Save s_keys, hhids, variable names and values in locals
				forval i = 1/`hfc_okay' {
					loc s_key_`i' = s_key[`i']
					loc hhid_`i' = hhid[`i']
					loc variable_`i' = variable[`i']
					loc value_`i' = value[`i']
				}

				// Load dataset and mark as okay. For eac var, create a var that *_ok
				use "`dataset'", clear
				forval i = 1/`hfc_okay' {
				
					// Check that the entries in the correction sheets are valid
					foreach name in "`s_key_`i''" "`hhid_`i''" "`variable_`i''" "`value'_`i'" {
						
						// Get the actual name of the variable
						loc name = substr("`name'", 1, length(`name') - length(`i')) 
						
					
						// Check that value is in the dataset before dropping
						cap assert `name' != "``name'_`i''"
						if !_rc {
							noi di as err "dirtshfc_correct: Wrong s_key(``name'_`i'') specified in correction sheet"
							exit 9
						}
					}
				
					// Check if the variable marker exist, else create it
					cap confirm var `variable_`i''_ok 
					if _rc == 111 {
						gen `variable_`i''_ok = 0
					}
				
					cap confirm string var `variable_`i'' 
					if !_rc {
						replace `variable_`i''_ok = 1 if s_key == "`s_key_`i''" & hhid == "`hhid'" ///
							& `variable_`i'' == "`value_`i''"
					}
					
					else {
						replace `variable_`i''_ok = 1 if s_key == "`s_key_`i''" & hhid == "`hhid'" ///
							& `variable_`i'' == `value_`i''
					}
						
					noi di as title "`s_key_`i''" _column(15) as title "`hhid_`i''" _column(25) ///
						as title "`variable_`i''" _column(40) as title "`value_`i''"
				
				}
			
			}
			
			noi di
			
			/*******************************************************************
			Drop Observations. Drop observations that have been marked in the 
			correction sheet to be dropped
			********************************************************************/
			
			if `hfc_drop' > 0 {
			
				use `corr_data', clear
				
				noi di as title "{bf: Dropped `hfc_drop' observations from the dataset, Details are as follows:"
				noi di as title "s_key" _column(15) as title "hhid"
				
				// keep only observations in corr sheet that will be dropped
				keep if action == 1
				
				// Save s_keys and hhids in locals
				forval i = 1/`hfc_drop' {
					loc s_key_`i' = s_key[`i']
					loc hhid_`i' = hhid[`i']
				}
				
				// Load the dataset, loop through and drop the obs with matching keys and hhids
				use "`dataset'", clear
				forval i = 1/`hfc_drop' {
				
					// Check that the entries in the correction sheets are valid
					foreach name in "`s_key_`i''" "`hhid_`i''" {
						
						// Get the actual name of the variable
						loc name = substr("`name'", 1, length(`name') - length(`i')) 
						
					
						// Check that value is in the dataset before dropping
						cap assert `name' != "``name'_`i''"
						if !_rc {
							noi di as err "dirtshfc_correct: Wrong s_key(``name'_`i'') specified in correction sheet"
							exit 9
						}
					}

					
					drop if s_key == "`s_key_`i''" & hhid == "`hhid_`i''"
					noi di as "`s_key_`i'" _column(15) "`hhid_`i'"
				}
				
			}
			
			noi di 
			
			/*******************************************************************
			Replacements
			********************************************************************/
		
			if `hfc_rep' > 0 {
			
				use `corr_data', clear
			
				noi di as title "{bf: Replaced `hfc_rep' flagged issues, Details are as follows:"
				noi di as title "s_key" _column(15) as title "hhid" _column(25) ///
					as title "variable" _column(40) as title "value" _column(55) as title "new_value" 
				
				keep if action == 2
				
				// Save s_keys, hhids, variable names and values in locals
				forval i = 1/`hfc_rep' {
					loc s_key_`i' = s_key[`i']
					loc hhid_`i' = hhid[`i']
					loc variable_`i' = variable[`i']
					loc value_`i' = value[`i']
					loc new_value_`i' = value[`i']
				}

				
				// Check that the entries in the correction sheets are valid
				foreach name in "`s_key_`i''" "`hhid_`i''" "`variable_`i''" "`value'_`i'" "`new_value_`i''" {
						
					// Get the actual name of the variable
					loc name = substr("`name'", 1, length(`name') - length(`i')) 
						
					
					// Check that value is in the dataset before dropping
					cap assert `name' != "``name'_`i''"
					if !_rc {
						noi di as err "dirtshfc_correct: Wrong s_key(``name'_`i'') specified in correction sheet"
						exit 9
					}
				}
								
				cap confirm string var `variable_`i'' 
				if !_rc {
					replace `variable_`i'' = "`new_value'" if s_key == "`s_key_`i''" & hhid == "`hhid'" ///
						& `variable_`i'' == "`value_`i''"
				}
					
				else {
					replace `variable_`i'' = `new_value' if s_key == "`s_key_`i''" & hhid == "`hhid'" ///
						& `variable_`i'' == `value_`i''
				}
						
				noi di as title "`s_key_`i''" _column(15) as title "`hhid_`i''" _column(25) ///
					as title "`variable_`i''" _column(40) as title "`value_`i''" _column(55) as title "`new_value_`i''"
			
			}
			
			noi di

		}
		
		/***********************************************************************
		Save a copy of the data ready for hfc checks
		***********************************************************************/

		
		// Close log
		log close
		
		// Save file
		save "`saving'", replace
		
		// return to starting directory
		cd "`hfcpwd'"
	}
	
	
end






