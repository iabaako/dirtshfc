*! version 0.0.0 Ishmail Azindoo Baako (IPA) Jan, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will run all neccesary checks to the DIRTS HFC file and prep it for the dirtshfc_run.ado
*/ 

/* Define sytax for program. 
*/

	program define dirtshfc_run
	
		syntax,
		DIRECTory(string)
		DATAset(string)
		LOGFolder(string)
		HFCDate(string)
		MISSFile(string)

	qui {	
		
		/***********************************************************************
		Set the stage
		***********************************************************************/
		// Save the name of the present working directory
		loc hfcpwd = c(pwd)
		
		// Check that the directory specified as is encrypted with Boxcryptor
		loc pathx = substr("`directory'", 1, 1)
		if `pathx' != "X" {
			noi di as err "dirtshfc_run: Hello!! Folder specified with directory must be BOXCRYPTED"
			exit 601
		}
		
		/**********************************************************************
		Import team details sheet and get the names of the teams
		***********************************************************************/			
		import excel using "`enumdetails'", sh(enum_details) case(l) first clear
		destring *_id, replace
		
		levelsof team_id, loc (team_ids) clean
		loc team_cnt: word count `team_ids'
		
		foreach t in `team_ids' {
			levelsof team_name if team_id == `t', loc(team_`t') clean			
		}
		
		/**********************************************************************
		Import constraint values
		***********************************************************************/			
		import excel using "`constraint'", sh(enum_details) case(l) first clear
		
		count if !mi(variable)
		loc v_cnt `r(N)'
		
		forval i = 1/`v_cnt' {
			loc v_name = variable[`i']
			
			loc s_ch = substr("`v_name'", -1, .)
			if "`s_ch'" == "*" {
				foreach var of varlist `v_name' {
					loc `var'_hmin = hard_min[`i']
					loc `var'_smin = soft_min[`i']
					loc `var'_smax = soft_max[`i']
					loc `var'_hmax = hard_max[`i']
					loc `var'_lab = var_label[`i']
				}
			}
			
			else {
				loc `v_name'_hmin = hard_min[`i']
				loc `v_name'_smin = soft_min[`i']
				loc `v_name'_smax = soft_max[`i']
				loc `v_name'_hmax = hard_max[`i']
				loc `v_name'_lab = var_label[`i']
			}
		}
		
		levelsof variable if !mi(variable), loc (v_names) clean
		
		/**********************************************************************
		Import the SCTO generated dataset. This dataset is what is created 
		after dirtshfc_correct.ado is runned
		***********************************************************************/	
	
	
		// Confirm that string specified with directory is an actual directory
		cap confirm file "`directory'/nul"
		if !_rc {
			
			// Change working directory to the data directory if directory exist
			cd "`directory'"
		
			cap confirm file "`dataset'"
			if !_rc {
				use "`dataset'", clear
				
				// Genarate a dummy var for date of hfc
				gen hfc = datestr == "`hfcdate'"
			}
			
			// Throw an error if file does not exist
			else {
			
				noi di as err "dirtshfc_run: File `dataset' not found in `directory'"
				exit 601
			}
		}
		
		// If directory does not exist
		else {
			
			noi di as err "`directory' does not found"
			exit 601
		}
		
		
		// Check if log folder exist, else creat it
		
		cap confirm file "`logfolder'/`hfcdate'/nul"
		if _rc == 601 {
			mkdir "`logfolder'/`hfcdate'"
		}
		
		
		/***********************************************************************
		HIGH FREQUENCY CHECKS
		
		A log sheet will be produced for each team and another log sheet will be
		produced for all teams.
		***********************************************************************/
		
		forval i in 0 `team_ids' {
			
			// Load dataset 
			use "`dataset'", clear
			if `i' == 0 {
				loc team_name "All"
				gen team_id_keep == team_id
				replace team_id == 0
			}
			
			else {
				loc team_name "`team_`t''"
			}
						
			// start log
			cap log
			log using "`logfolder'/`hfcdate'/dirtshfc_log_TEAM_`team_name'"
			
			// Create Header
			noi di "{hline 82}"
			noi di _dup(82) "-"
			noi di _dup(82) "*"
	
			noi di "{bf: HIGH FREQUENCY CHECKS FOR DIRTS ANNUAL SURVEY 2017}"
			noi di _column(10) "{bf:HFC LOG: TEAM `team_name'}" 
			noi di
			noi di "{bf: Date: `c(current_date)'}"
	
			noi di _dup(82) "*"
			noi di _dup(82) "-"
			noi di "{hline 82}"
			
			
			/*******************************************************************
			HFC CHECK #1: SUBMISSION DETAILS AND CONSENT RATES
			*******************************************************************/
			
			// Create headers for check
			check_headers, checknu(1) checkna("SUBMISSIONS PER ENUMERATOR")
			noi di  
			noi di as title "enum_id" _column(10) as title "enum_name" _column(20) ///
				as title "hfcdate" _column(30) as title "all_sub" _column(38) as title "consent_rate" 
			
			levelsof enum_id if team_id == `i', loc (enum_itc) clean
			foreach enum in `enum_itc' {
				levelsof enum_name if enum_id == `enum', loc(name) clean
				
				count if enum_id == `enum' & hfc
				loc day_sub `r(N)'
				
				count if enum_id == `enum'
				loc all_sub `r(N)'
				
				count if enum_id == `enum' & consent == 1
				loc consent_rate `r(N)'
				
				noi di "`enum'" _column(10) "`name'" _column(20) "`day_sub'" _column(30) ///
					"`all_sub'" _column(38) "`consent_rate'"
			}
			
			
			/*******************************************************************
			HFC CHECK #2: DUPLICATES
			*******************************************************************/

			check_headers, checknu(2) checkna("DUPLICATES ON HHID AND RESPONDENT TYPE")
			noi di  
			
			cap isid hhid resp_type
			if !_rc {
				noi di "Congratulations, Your Team has no duplicates on hhid and resp_type"
			}
			
			else {
				duplicates tag hhid resp_type, gen (dups)
				count if dups & team_id == `i'
				if `r(N)' > 0 {
					noi di in red "There are `r(N)' duplicates on hhid and resp_type, details are as follows"
				
					sort hhid resp_type
					noi di as title "s_key" _column(13) as title "enum_id" _column(18) as title "enum_name" _column(30) ///
					as title "hhid" _column(38) as title "resp_type" _column(35) as title "resp_name" _column(50) "date_of_interview"
				
					levelsof key if dups & team_id == `i', loc (keys) clean
					foreach k in `s_keys' {
						levelsof s_key if key == `k', loc (s_key) clean
						levelsof enum_id if key == `k', loc (enum_id) clean
						levelsof enum_name if key == `k', loc (enum_name) clean
						levelsof hhid if key == `k', loc (hhid) clean
						levelsof resp_type if key == `k', loc (resp_type) clean
						levelsof resp_name if key == `k', loc (resp_name) clean
						levelsof startdate_str if key == `k', loc (date_of_interview) clean
					
						noi di "`s_key'" _column(13) "`enum_id'" _column(18) "`enum_name'" _column(30) ///
						"`hhid'" _column(38) "`resp_type'" _column(35) "`resp_name'" _column(50) "`date_of_interview'"	
					}
				}
				
				else {
					noi di "Congratulations, Your Team has no duplicates on hhid and resp_type"
				}
			}
			
			/*******************************************************************
			HFC CHECK #3: AUDIO CONSENT RATE
			*******************************************************************/
			
			check_headers, checknu(3) checkna("AUDIO CONSENT RATE")
			noi di  
			
			noi di "Audio consent rates for your team are as follows:"
			noi di as title "enum_id" _column(8) as title "enum_name" _column(30) ///
			as title "ac_rate" _column(34) as title "all_sub" 
			
			foreach enum of `enum_itc' {
				
				levelsof enum_name if enum_id == `enum', loc (name) clean
				
				count if enum_id == `enum'
				loc all_sub `r(N)'
				
				count if audio_consent == 1 & enum_id == `enum' 
				loc ac_rate = round(`all_sub'/`r(N)', 2)
			
				noi di "`enum_id'" _column(8) "`enum_name'" _column(30) "`ac_rate'%" _column(34) "`all_sub'" 
			}
			
			/*******************************************************************
			HFC CHECK #4: FORM VERSIONS
			*******************************************************************/
			check_headers, checknu(4) checkna("FORM VERSIONS")
			noi di  
			
			su formdef_version if hfc
			loc form_vers `r(max)'
			
			cap assert formdef_version == `form_vers' if team_id == `i' & hfc
			if !_rc {
				noi di "Congratulations, all team members are using the latest form version for `hfcdate'" 
				noi di "Form Version for `hfcdate': " as result "`form_vers'"
			}
			
			else {
				
				noi di in red "Some members of your team may be using the wrong form version for `hfcdate'" 
				noi di in red "Form Version for `hfcdate': " as result "`form_vers'"	
				
				noi di as title "enum_id" _column(8) as title "enum_name" _column(30) as title "form_version"

				
				levelsof enum_id if formdef_version != `form_vers' & team_id == `i' & hfc, loc (enum_rfv) clean
				foreach enum in `enum_rfv' {
					levelsof enum_name if enum_id == `enum', loc (enum_name) clean
					levelsof formdef_version if enum_id == `enum' & formdef_version != `form_version', loc (form_version) clean
					
					noi di "`enum_id'" _column(8) "`enum_name'" _column(30) "`form_version'"
				}
			}	
			
			/*******************************************************************
			HFC CHECK #5: CHECK SURVEY DATES
			Check that survey dates fall with reasonabel minimum and maximum dates
			*******************************************************************/
			check_headers, checknu(5) checkna("DATES")
			noi di  
			
			gen start_date = dofc(starttime)
			gen end_date = dofc(endtime)
			
			loc survey_start 42795
			loc survey_end 42839
			
			loc start_date_str "01_03_17" 
			loc end_date_str "14_04_17"
			
			gen valid_date = start_date < `survey_start' | end_date > `survey_end'
			count if valid_date & team_id == `i'
			
			if `r(N)' == 0 {
				noi di "Congratulations, start and end dates for all surveys are with the expected range"
			}
			
			else {
				noi di in red "Some interview dates are outside the expected range `start_date_str' and `end_date_str', details: "
				noi di as title "s_key" _column(13) as title "enum_id" _column(18) as title "enum_name" _column(30) ///
					as title "hhid" _column(38) as title "resp_type" _column(35) as title "resp_name" _column(50) as title "start_date" ///
					_column(56) as title "end_date"
				
				levelsof key if !valid_date & team_id == `i', loc (keys) clean
				foreach k in `keys' {
					levelsof s_key if key == "`k'", loc (s_key) clean
					levelsof enum_id if key == "`k'", loc (enum_id) clean
					levelsof enum_name if key == "`k'", loc (enum_name) clean
					levelsof hhid if key == "`k'", loc (hhid) clean
					levelsof resp_type if key == "`k'", loc (resp_type) clean
					levelsof resp_name if key == "`k'", loc (resp_name) clean
					levelsof startdate_str if key == "`k'", loc (start_date) clean
					levelsof enddate_str if key == "`k'", loc (end_date) clean
					
					noi di "`s_key'" _column(13) "`enum_id'" _column(18) "`enum_name'" _column(30) ///
						"`hhid'" _column(38) "`resp_type'" _column(35) "`resp_name'" _column(50) "`start_date'" ///
						_column(56) "`end_date'"
					
				}
			}
			
			drop valid_date
			
			/*******************************************************************
			HFC CHECK #6: DURATION OF SURVEY
			*******************************************************************/
			check_headers, checknu(6) checkna("DURATION OF SURVEY")
			noi di  
			
			su dur_min
			loc dur_mean `r(mean)'
			loc valid_dur = `dur_mean' - 60
			gen invalid_dur = dur_min < `valid_dur'
			
			count if invalid_dur & hfc & team_id == `i'
			if `r(N)' == 0 {
				noi di "Congratulations, all members of your team administered the survey within an acceptable duration"
				noi di "Average time per survey is: `dur_mean'"
			
			}
			
			else {
				noi di in red "Durations for the following surveys are too short, average time per survey is `dur_mean'"
				
				noi di "s_key" _column(13) "enum_id" _column(18) "enum_name" _column(30) ///
				"hhid" _column(38) "resp_type" _column(35) "resp_name" _column(50) "duration" ///
					_column(56) "start_date"

				levelsof key if invalid_dur & hfc & team_id == `i', loc (keys) clean
				foreach k in `keys' {
					levelsof s_key if key == "`k'", loc (s_key) clean
					levelsof enum_id if key == "`k'", loc (enum_id) clean
					levelsof enum_name if key == "`k'", loc (enum_name) clean
					levelsof hhid if key == "`k'", loc (hhid) clean
					levelsof resp_type if key == "`k'", loc (resp_type) clean
					levelsof resp_name if key == "`k'", loc (resp_name) clean
					levelsof dur_min if key == "`k'", loc (dur_min) clean
					levelsof startdate_str if key == "`k'", loc (start_date) clean
					
					noi di "`s_key'" _column(13) "`enum_id'" _column(18) "`enum_name'" _column(30) ///
						"`hhid'" _column(38) "`resp_type'" _column(35) "`resp_name'" _column(50) "`dur_min'" ///
						_column(56) "`start_date'"
				}
				
			}	
			
			drop invalid_dur
			
			/*******************************************************************
			HFC CHECK #7: SOFT CONSTRAINT VIOLATIONS
			*******************************************************************/
			check_headers, checknu(7) checkna("SOFT CONSTRAINT")
			noi di  
			
			foreach var of varlist `v_names' {
				su `var'
				loc `var'_mean `r(mean)'
				gen flag = (`var' < ``var'_smin' | `var' > ``var'_smax') & team_id == `i'
				count if flag
				if `r(N)' == 0 {
					noi di "Congratulations, your team has no soft constraint violations"
				}
				
				else {
					noi di in red "The following are soft constraint violations on variable `var'"
					noi di "{p} Variable Description: ``var'_label' {smcl}"
					noi di "Expected Range: " _column(18) "``var'_smin' - ``var'_smax'"
					noi di "Average Value: " _column(18) "``var'_mean'"
					noi di
					
					noi di "s_key" _column(13) "enum_id" _column(18) "enum_name" _column(30) ///
					"hhid" _column(38) "resp_type" _column(35) "resp_name" _column(50) "value"
					
					levelsof key if flag, loc (keys) clean
					foreach k in `keys' {
						levelsof s_key if key == "`k'", loc (s_key) clean
						levelsof enum_id if key == "`k'", loc (enum_id) clean
						levelsof enum_name if key == "`k'", loc (enum_name) clean
						levelsof hhid if key == "`k'", loc (hhid) clean
						levelsof resp_type if key == "`k'", loc (resp_type) clean
						levelsof resp_name if key == "`k'", loc (resp_name) clean
						levelsof `var' if key == "`k'", loc (value) clean
					
						noi di "`s_key'" _column(13) "`enum_id'" _column(18) "`enum_name'" _column(30) ///
							"`hhid'" _column(38) "`resp_type'" _column(35) "`resp_name'" _column(50) "`value'"
					}				
				}
				
				drop flag
			}			
			
			if `i' == 0 {
			
				/***************************************************************
				THIS IS TO INCLUDE SOME FEW MORE CHECKS FOR PROGRAMMING ERRORS
				THESE WILL ONLY APPEAR IN THE MASTER LOG SHEET
				***************************************************************
				HARD CONSTRAINT VIOLATIONS
				****************************************************************/
				check_headers, checknu(8) checkna("HARD CONSTRAINT")
				noi di  
			
				foreach var of varlist `v_names' {
					su `var'
					loc `var'_mean `r(mean)'
					gen flag = `var' < ``var'_hmin' | `var' > ``var'_hmax'
					count if flag
					
					if `r(N)' == 0 {
						noi di "Congratilations, there are no hard constraint violations"
					}
					
					else {
						noi di in red "The following are hard constraint violations on variable `var'. Please check Survey programming"
						noi di "{p} Variable Description: ``var'_label' {smcl}"
						noi di "Expected Range: " _column(18) "``var'_hmin' - ``var'_hmax'"
						noi di "Average Value: " _column(18) "``var'_mean'"
						noi di
					
						noi di "s_key" _column(13) "enum_id" _column(18) "enum_name" _column(30) ///
						"hhid" _column(38) "resp_type" _column(35) "resp_name" _column(50) "value"
					
						levelsof key if flag, loc (keys) clean
						foreach k in `keys' {
							levelsof s_key if key == "`k'", loc (s_key) clean
							levelsof enum_id if key == "`k'", loc (enum_id) clean
							levelsof enum_name if key == "`k'", loc (enum_name) clean
							levelsof hhid if key == "`k'", loc (hhid) clean
							levelsof resp_type if key == "`k'", loc (resp_type) clean
							levelsof resp_name if key == "`k'", loc (resp_name) clean
							levelsof `var' if key == "`k'", loc (value) clean
					
							noi di "`s_key'" _column(13) "`enum_id'" _column(18) "`enum_name'" _column(30) ///
								"`hhid'" _column(38) "`resp_type'" _column(35) "`resp_name'" _column(50) "`value'"
						}				
					}
					drop flag
				}			

				/***************************************************************
				NO MISS:
				Check that certain critical values have no missing values
				***************************************************************/
				check_headers, checknu(9) checkna("NO MISS")
				noi di  

				
				#d;
					loc nm_var
							hhid
							resp_name
							resp_type
							;
				#d cr
				
				foreach var in `nm_vars' {
					loc nm_track 0
					
					cap assert !mi(`var')
					if _rc == 9 {
						loc ++nm_track
					}
					
					if `nm_track' == 0 {
						noi di "Congratulations, all critical variables do not have missing values"
					}
					
					else {
						noi di "{p} `nm_track' critical variables have missing values in some observations, check survey programming. Details are listed below: {smcl}"
						noi di as title "variable" _column(30) as title "variable_label"
					
						foreach var in `nm_vars' {
							cap assert !mi(`var')
							if _rc == 9 {
								loc var_lab: variable label `var'
								noi di "`var'" _column(30) "{p} `var_lab' {smcl}"
							}					
						}
					}
				}
				
				/***************************************************************
				ALL MISS. 
				Display variables that have all missing values
				****************************************************************/
				check_headers, checknu(10) checkna("ALL MISS")
				noi di  
				
				foreach var in `nm_vars' {
					loc am_track 0
					
					cap assert mi(`var')
					if !_rc {
						loc ++am_track
					}
					
					if `am_track' == 0 {
						noi di "Congratulations, There are no variables with all missing values"
					}
					
					else {
						noi di "{p} `am_track' variables have all missing values , check survey programming. Details are listed below: {smcl}"
						noi di as title "variable" _column(30) as title "variable_label"
					
						foreach var in `nm_vars' {
							cap assert mi(`var')
							if !_rc {
								loc var_lab: variable label `var'
								noi di "`var'" _column(30) "{p} `var_lab' {smcl}"
							}					
						}
					}
				}
				
			}
		
		}
		
		/***********************************************************************
		Save a copy of the data ready for hfc checks
		***********************************************************************/
		// Close log
		log close
		
		// Save file
		save "`saving'", replace

		
		/**********************************************************************
		MISSING RATE PER VARIABLE
		Check for rate at which each variable is missing per enumerator
		and export the answeres to a an excel sheet
		***********************************************************************/
		
		#d;
			ds
				deviceid
				enum_*
				,
				not
			;
		#d cr
		
		loc mr_vars "`r(varlist)'"
		foreach var of `ma_vars' {
			cap assert string var `var' 
			if !_rc {
				replace `var' = "1" if mi(`var')
				replace `var' = "0" if mi(`var')
			}
			
			else {
				replace `var' = 1 if mi(`var')
				replace `var' = 0 if mi(`var')
			}
			
			destring `var', replace
			su `var'
			replace `var' = `r(mean)'
		}
		
		format %5.2 `mr_vars'
		
		export excel `mr_vars' using "`missfile'", first(var) sheetmod
		
		// return to starting directory
		cd "`hfcpwd'"
	}
	
	
end

program define check_headers

	syntax, ///
	CHECKNUmber(numeric)
	CHECKNAme(string)
	
	noi di _dup(82) "*"
	noi di _dup(82) "-"
	noi di "CHECK #`checknumber': `checkname'"
	noi di _dup(82) "-"
	noi di _dup(82) "*"
	
end







