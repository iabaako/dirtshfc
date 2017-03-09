*! version 0.0.3 Ishmail Azindoo Baako (IPA) Jan, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will run Checks on data that is saved from dirtshfc_prep.ado

	Define sytax for program. 
	varname		: ID variable for survey
	date 		: Date of interest for HFC
	ssdate		: Survey start date in format "DD_MM_YY"
	sedate		: Survey enddate in format "DD_MM_YY"
	enumvars	: Enumerator variables. The enumerator id and then enumerator name
					variables are espected here. eg. enumv(enum_id enum_name)
	dispvars	: Variables to display at hh level excluding the hhid
	logfolder	: Name of folder were logfiles are saved
	saving		: Name for saving data after hfc is run

*/	
	prog def dirtshfc_run
		
		#d;
		syntax name using/, 
		DATE(string)			
		SSDate(string)			
		SEDate(string)
		ENUMDetails(string)
		ENUMVars(namelist min=2 max=2)
		DISPVars(namelist)			
		LOGFolder(string)			
		SAVing(string)
		type(string)
		;
		#d cr

	qui {	
		
		/***********************************************************************
		Set the stage
		***********************************************************************/
		* Check that the directory specified as is encrypted with Boxcryptor
		loc pathx = substr("`using'", 1, 1)
		if "`pathx'" != "X" & "`pathx'" != "." {
			noi di as err "dirtshfc_run: Hello!! Using Data must be in a BOXCRYPTED folder"
			exit 601
		}
		
		* Check that type is valid
		loc type = lower("`type'")
		if "`type'" != "r1" & "`type'" != "r2" {
			noi di as err "dirtshfc_prep: SYNTAX ERROR!! Specify r1 or r2 with type"
			exit 601
		}

		
		* Get the enumerator related vars from arg enumvars
		token `enumvars'
		loc enum_id "`1'"				// Enumerator ID
		loc enum_name "`2'"				// Enumerator Name
		
		* Make the local date an upper to avoid differnces in cases
		loc date = upper("`date'")
		
		* Represent the id var with the local id
		loc id `namelist'

		/**********************************************************************
		Import team details sheet and get the names of the teams
		***********************************************************************/			
		* Import data
		import exc using "`enumdetails'", sh(enum_details) case(l) first clear
		destring *_id, replace
		
		* Get the team ids
		levelsof team_id, loc (team_ids) clean
		loc team_cnt: word count `team_ids'
		
		* Loop through the team ids and for each id get the name and save it a local
		loc x 0
		foreach t in `team_ids' {
			loc ++x
			levelsof team_name if team_id == `t', loc(team_`x') clean			
		}
		
		
		/**********************************************************************
		Import constraint values
		***********************************************************************/			
		* Import sheets containing constraint values
		import exc using "`enumdetails'", sh(constraints) case(l) first clear
		
		count if !mi(variable)
		loc v_cnt `r(N)'
		
		* Loop through each variable and get the names and constraint values
		forval i = 1/`v_cnt' {
			
			loc con_`i'_var = variable[`i']
			loc con_`i'_vlab = var_lab[`i']
			loc con_`i'_hn = hard_min[`i']
			loc con_`i'_sn = soft_min[`i']
			loc con_`i'_sx = soft_max[`i']
			loc con_`i'_hx = hard_max[`i']
			
		}
		
		/**********************************************************************
		Import No Miss Variables
		***********************************************************************/			
		* Import sheets nomiss variables
		import exc using "`enumdetails'", sh(nomiss) case(l) first clear
		drop if mi(variable)
		count if !mi(variable)
		loc n_cnt `r(N)'
		
		if `n_cnt' > 0 {
			forval i = 1/`n_cnt' {
				loc nmv_`i' = variable[`i']
				loc nml_`i' = var_label[`i']
			}
		}
		/**********************************************************************
		Import the SCTO generated dataset. This dataset is what is created 
		after dirtshfc_correct.ado is runs
		***********************************************************************/	
		cap confirm file "`using'"
		if !_rc {
			use "`using'", clear
				
			*Genarate a dummy var for date of hfc
			gen hfc = subdate_str == "`date'"
			save "`saving'", replace
		}
			
		* Throw an error if file does not exist
		else {	
			noi di as err "dirtshfc_run: File `dataset' not found"
			exit 601
		}
		
		* Check if log folder exist, else create it
		cap confirm file "`logfolder'/`date'/nul"
		if _rc == 601 {
			mkdir "`logfolder'/`date'"
		}
		
		/***********************************************************************
		HIGH FREQUENCY CHECKS
		
		Run High Frequency Checks and produce 2 log sheets
			1. Team Logs: A log file for each team with information about team
				members only
			2. Master Log: A master log containing information for all field staff
		***********************************************************************/
		loc t1 -1
		* Loop through each team and produce log sheets (Team 0 includes all enums)
		foreach team in 0 `team_ids' {
			loc ++t1
			* For the 1st iteration, import data and set team to 0
			
			if `team' == 0 {
				use "`saving'", clear
				loc team_name "All"
				gen team_id_keep = team_id
				replace team_id = 0
				
				* tag all duplicates on id var
				duplicates tag `id', gen(dup)
			}
			
			* 
			else if `t1' == 1 {
				replace team_id = team_id_keep
				drop team_id_keep
				loc team_name "`team_`t1''"
			}
			
			else {
				loc team_name "`team_`t1''"
			}
						
			* start log
			cap log close
			log using "`logfolder'/`date'/dirtshfc_log_TEAM_`team_name'_`type'", replace
			
			* Create Header
			noi di "{hline 120}"
			noi di _dup(120) "-"
			noi di _dup(120) "*"
	
			noi di "{bf: HIGH FREQUENCY CHECKS FOR DIRTS ANNUAL SURVEY 2017}"
			noi di _column(10) "{bf:HFC LOG: TEAM `team_name'}" 
			noi di
			noi di "{bf: HFC Date		: `date'}"
			loc date_f = upper(subinstr("`c(current_date)'", " ", "_", .))
			noi di "{bf: Running Date	: `date_f'}"
	
			noi di _dup(120) "*"
			noi di _dup(120) "-"
			noi di "{hline 120}"
			
			
			/*******************************************************************
			HFC CHECK #1: SUBMISSION DETAILS AND CONSENT RATES
			*******************************************************************/
			
			* Create headers for check
			noi di
			noi check_headers, checknu("1") checkna("SUBMISSIONS PER ENUMERATOR")
			noi di  
			
			* Create column titles for submission details
			noi di "{hline 74}"
			noi di  "`enum_id'" _column(10)  "`enum_name'" _column(35) ///
				 "hfcdate" _column(47)  "all_sub" _column(58) "ac_rate" _column(70) "consent_rate(%)" 
			noi di "{hline 74}"
			noi di
			
			
			* Display submission details and consent rates for each field staff
			levelsof `enum_id' if team_id == `team', loc (enum_itc) clean
			foreach enum in `enum_itc' {
				levelsof `enum_name' if `enum_id' == `enum', loc(name) clean
				
				count if `enum_id' == `enum' & hfc
				loc day_sub `r(N)'
				
				count if `enum_id' == `enum'
				loc all_sub `r(N)'
				
				su respondent_agree if `enum_id' == `enum'
				loc consent_rate = `r(mean)' * 100
				loc consent_rate: di %3.0f `consent_rate'
				
				su audio_consent if respondent_agree & `enum_id' == `enum'
				loc ac_rate = `r(mean)' * 100
				loc ac_rate: di %3.0f `consent_rate'

				
				noi di "`enum'" _column(10) "`name'" _column(35) "`day_sub'" _column(47) ///
					"`all_sub'" _column(58) "`ac_rate'%" _column(70) "`consent_rate'%"
			}
			
			* drop unneeded macros
			macro drop _enum _day_sub _all_sub _consent_rate
			
			/*******************************************************************
			HFC CHECK #2: DUPLICATES
			*******************************************************************/
			* Create check header

			noi di
			noi check_headers, checknu("2") checkna("DUPLICATES ON `id'")
			noi di  
			
			* Check that there are duplicates with this team
			count if dup & team_id == `team'
			if `r(N)' == 0 {
				noi di "Congratulations, Your Team has no duplicates on `id'"
			}
			
			* List observations that are duplicate on on idvar
			else {		
				noi di in red "There are `r(N)' duplicates on `id', details are as follows"
				sort `id' `dispvars' `enum_name'
				noi l skey `enumvars' `id' `dispvars' if dup & team_id == `team', noo sepby(`id') abbrev(32)	
			}
			
			
			/*******************************************************************
			HFC CHECK #3: FORM VERSIONS
			*******************************************************************/
			
			* Create check headers
			noi di
			noi check_headers, checknu("3") checkna("FORM VERSIONS")
			noi di  
			
			* Get the latest form version used on submission date of interest
			su formdef_version if hfc
			loc form_vers `r(max)'
			
			* Check that all members are using the right form and display congrats
			cap assert formdef_version == `form_vers' if team_id == `team' & hfc
			if !_rc {
				noi di "Congratulations, all team members are using the latest form version for `date'" 
				noi di "Form Version for `date': " as res "`form_vers'"
			}
			
			
			* Display form version details if enum is using the wrong for
			else {
				* Display message and column titles
				noi di in red "Some members of your team may have used the wrong form version for `date'" 
				noi di
				noi di in red "Form Version for `date': " as res `form_vers'	
				
				noi di  "`enum_id'" _column(10)  "`enum_name'" _column(35)  "form_version"

				* For each enumerator in team with wrong form version, display the id, name and form version used
				levelsof `enum_id' if formdef_version != `form_vers' & team_id == `team' & hfc, loc (enum_rfv) clean
				foreach enum in `enum_rfv' {
					levelsof `enum_name' if `enum_id' == `enum', loc (name) clean
					levelsof formdef_version if `enum_id' == `enum' & formdef_version != `form_version' & hfc, loc (form_version) clean
					
					noi di "`enum'" _column(10) "`name'" _column(35) "`form_version'"
				}
			}	
		
			
			/*******************************************************************
			HFC CHECK #4: CHECK SURVEY DATES
			Check that survey dates fall with reasonable minimum and maximum dates
			*******************************************************************/
			* Create check headers
			noi di
			noi check_headers, checknu("4") checkna("DATES")
			noi di 
			
			if `team' == 0 {
				* Generate numeric date vars
				gen start_date = dofc(starttime)
				gen end_date = dofc(endtime)
			
				* Convert ssdate and sedate to numeric dates
				loc survey_start = subinstr("`ssdate'", "_", "", .)
				loc survey_start = date("`ssdate'", "DM20Y")
				loc survey_end = subinstr("`sedate'", "_", "", .)
				loc survey_end = date("`sedate'", "DM20Y")
				
				* Generate a dummy var = 1 if date for observation is valid
				gen valid_date = start_date >= `survey_start' | end_date <= `survey_end'
			}
			
			* Count the number of obs in team with invalid dates. Display messages
			count if !valid_date & team_id == `team'
			if `r(N)' == 0 {
				noi di "{p} Congratulations, start and end dates for all surveys are within the expected range of `ssdate' and `sedate' {p_end}"
			}
			
			* List observations with invalid dates
			else {
				noi di in red "Some interview dates are outside the expected range `ssdate' and `sedate', details: "
				sort `enum_id'
				noi l skey `enumvars' `id' `dispvars' if !valid_date & team_id == `team', noo sepby(`enum_id')	abbrev(32)
			}
			
			/*******************************************************************
			HFC CHECK #5: DURATION OF SURVEY
			*******************************************************************/
			noi di
			noi check_headers, checknu("5") checkna("DURATION OF SURVEY")
			noi di  
			
			* Check that var valid_dur exist. If no create var
			if `team' == 0 {
				su duration
				loc dur_mean = floor(`r(mean)')
				loc valid_dur = `dur_mean' - 60
				gen valid_duration = duration >= `valid_dur'
			}
			
			* Count the number of obs in team with invalid duration and display congrats
			count if !valid_duration & hfc & team_id == `team'
			if `r(N)' == 0 {
				noi di "{p} Congratulations, all members of your team administered " ///
						"their surveys within an acceptable duration. "				///
						"Average time per survey is: `dur_mean' minutes {smcl}"
			}
			
			* List surveys with suspicious durations
			else {
				sort `enum_id'
				noi di in red "Durations for the following surveys are too short, average time per survey is `dur_mean' minutes"
				noi l skey `enumvars' `id' `dispvars' duration if !valid_dur & team_id == `team', noo sepby(`enum_id')	abbrev(32)				
			}	
			
			/*******************************************************************
			HFC CHECK #6: SOFT CONSTRAINT VIOLATIONS
			*******************************************************************/
			noi di
			noi check_headers, checknu("6") checkna("SOFT CONSTRAINT")
			noi di  
			
			/* Generate soft flags during the first iteration based on the constraints 
				specified in the constraint sheet of the inputs workbook. The constraints 
				could generally be in 2 forms. 
				1. As a number eg. 0 or 100 
				2. As another variable
				
			*/
			
			* set trace on
			if `team' == 0 { 
				forval i = 1/`v_cnt' {
					unab con_v: `con_`i'_var'
					cap unab cv_omit: *_sf
					if _rc == 111 {
						loc cv_omit ""
					}
					loc con_v: list con_v - cv_omit
					destring `con_v', replace
					loc cnt_v: word count of `con_v'
				
					* Check that the soft minimum value is a number
					cap confirm n `con_`i'_sn'
					if !_rc {
						if `cnt_v' == 1 {
							gen `con_v'_sf = `con_v' < `con_`i'_sn'
						}
					
						else {
							foreach v in `con_v' {
								gen `v'_sf = `v' < `con_`i'_sn'
							}
						}
					}
				
					else {
						unab con_n: `con_`i'_sn'
						destring `con_n', replace
						loc cnt_n: word count of `con_n'
					
						if `cnt_n' == 1 {
							foreach v in `con_v' {
								gen `v'_sf = `v' < `con_n'
							}

						}
					
						else {
							loc cv = subinstr("`con_`i'_sx'", "*", "", .)
							loc j 1
							foreach v in `con_v' {
								gen `v'_sf = `v' < `cv'_`j'
								loc ++j
							}
						}
					}
				
					* Check that the soft max value is a number
					cap confirm n `con_`i'_sx'
					if !_rc {
						if `cnt_v' == 1 {
							replace `con_v'_sf = `con_v' > `con_`i'_sx' & !mi(`con_v')
						}
					
						else {
							foreach v in `con_v' {
								replace `v'_sf = `v' > `con_`i'_sx' & !mi(`v')
							}
						}
					}
					
					else {
						unab con_x: `con_`i'_sx'
						destring `con_x', replace
						loc cnt_x: word count of `con_x'
					
						if `cnt_x' == 1 {
							foreach v in `con_v' {
								gen `v'_sf = `v' > `con_x' & !mi(`v')
							}

						}
					
						else {
							loc cv = subinstr("`con_`i'_sx'", "*", "", .)
							loc j 1
							foreach v in `con_v' {
								replace `v'_sf = `v' > `cv'_`j' & !mi(`v')
								loc ++j
							}
						}
					}
				}
			}
			
			loc j 0
			cap unab c_omit: *_sf *_hf
			if _rc == 111 {
				unab c_omit: *_sf
			}
			
			forval i = 1/`v_cnt' {
				unab con_v: `con_`i'_var'
				loc con_v: list con_v - c_omit
				foreach var in `con_v' {
					count if `var'_sf & team_id == `team'
					loc c_trg `r(N)'
					if `c_trg' > 0 {
						noi di in red "The following are soft constraint violations on variable `var'"
						noi di "{synopt: Variable Description: }" "`con_`i'_vlab' {p_end}"
						noi di "Expected Range	: " _column(18) "`con_`i'_sn' - `con_`i'_sx'"				
							
						sort `enum_id'
						cap confirm var `var'_ok
						if !_rc {
							cap noi l skey `enumvars' `id' `dispvars' `var' if `var'_sf & !`var'_ok, noo sepby(`enum_id') abbrev(32)
						}
						else {
							noi l skey `enumvars' `id' `dispvars' `var' if `var'_sf, noo sepby(`enum_id') abbrev(32)
						}
						loc ++j
					}
				}
			}
			
			if `j' == 0 {
				noi di "Congratulation, your team has no soft constraint violation"
			}
			
			if `team' == 0 {
			
				/***************************************************************
				CHECK 7:
				THIS IS TO INCLUDE SOME FEW MORE CHECKS FOR PROGRAMMING ERRORS
				THESE WILL ONLY APPEAR IN THE MASTER LOG SHEET
				***************************************************************
				HARD CONSTRAINT VIOLATIONS
				****************************************************************/
				noi di
				noi check_headers, checknu("7") checkna("HARD CONSTRAINT")
				noi di  
				
				forval i = 1/`v_cnt' {
					unab con_v: `con_`i'_var'
					cap unab cv_omit: *_sf *_hf
					if _rc == 111 {
						unab cv_omit: *_sf
					}
					loc con_v: list con_v - cv_omit
					destring `con_v', replace
					loc cnt_v: word count of `con_v'
				
					* Check that the soft minimum value is a number
					cap confirm n `con_`i'_hn'
					if !_rc {
						if `cnt_v' == 1 {
							gen `con_v'_hf = `con_v' < `con_`i'_hn'
						}
					
						else {
							foreach v in `con_v' {
								gen `v'_hf = `v' < `con_`i'_hn'
							}
						}
					}
				
					else {
						unab con_n: `con_`i'_hn'
						destring `con_n', replace
						loc cnt_n: word count of `con_n'
					
						if `cnt_n' == 1 {
							foreach v in `con_v' {
								gen `v'_hf = `v' < `con_n'
							}

						}
						
						else {
							loc cv = subinstr("`con_`i'_hn'", "*", "", .)
							loc j 1
							foreach v in `con_v' {
								gen `v'_hf = `v' < `cv'_`j'
								loc ++j
							}
						}

					}
					
					* Check that the soft max value is a number
					cap confirm n `con_`i'_hx'
					if !_rc {
						if `cnt_v' == 1 {
							replace `con_v'_hf = `con_v' > `con_`i'_hx' & !mi(`con_v')
						}
					
						else {
							foreach v in `con_v' {
								replace `v'_hf = `v' > `con_`i'_hx' & !mi(`v')
							}
						}
					}
					
					else {
						unab con_x: `con_`i'_hx'
						destring `con_x', replace
						loc cnt_x: word count of `con_x'
					
						if `cnt_x' == 1 {
							foreach v in `con_v' {
								gen `v'_hf = `v' > `con_x' & !mi(`v')
							}

						}
						
						else {
							loc cv = subinstr("`con_`i'_hx'", "*", "", .)
							loc j 1
							foreach v in `con_v' {
								replace `v'_hf = `v' > `cv'_`j' & !mi(`v')
								loc ++j
							}
						}
					}
				}
				
				loc j 0
				unab c_omit: *_sf *_hf
				forval i = 1/`v_cnt' {
					unab con_v: `con_`i'_var'
					loc con_v: list con_v - c_omit
					foreach var in `con_v' {
						count if `var'_hf & team_id == `team'
						loc c_trg `r(N)'
						if `c_trg' > 0 {
							noi di in red "The following are hard constraint violations on variable `var'"
							noi di "{synopt: Variable Description: }" "`con_`i'_vlab' {p_end}"
							noi di "Expected Range	: " _column(18) "`con_`i'_hn' - `con_`i'_hx'"				
							
							sort `enum_id'
							cap confirm var `var'_ok
							if !_rc {
								cap noi l skey `enumvars' `id' `dispvars' `var' if `var'_hf & !`var'_ok, noo sepby(`enum_id') abbrev(32)
							}
							else {
								noi l skey `enumvars' `id' `dispvars' `var' if `var'_hf, noo sepby(`enum_id') abbrev(32)
							}
							loc ++j
						}
					}
				}
				
				/***************************************************************
				CHECK 8: NO MISS
				Check that certain critical values have no missing values
				***************************************************************/
				noi di
				noi check_headers, checknu("8") checkna("NO MISS")
				noi di  

				* Save the vars to check for missing values 
				
				* Check the number of critical vars with missing values
				
				* set trace on
				loc q 0
				forval i = 1/`n_cnt' {
					cap assert !mi(`nmv_`i'')
					if _rc == 9 {
						loc ++q
					}
				}
				
				if `q' == 0 {
					noi di "Hurray!! all critical variables do not have missing values"
				}
				
				else {
				
					* Displays column headers
					
					noi di "{p} `q' Critical variables have missing values in some observations, check survey programming. Details are listed below: {p_end}"
					noi di "{hline 80}" 
					noi di  "variable" _column(30) "var_label"
					noi di "{hline 80}" 

					forval i = 1/`n_cnt' {
						* Check for missing values in var if survey has consent 
						cap assert !mi(`nmv_`i'') if respondent_agree
						if _rc == 9 {
							noi di "{synopt:`nmv_`i''}" "`nml_`i'' {p_end}"
							noi di 
						}					
					}
				}
				
			
				/***************************************************************
				CHECK 9:
				ALL MISS. 
				Display variables that have all missing values
				****************************************************************/
				noi di
				noi check_headers, checknu("9") checkna("ALL MISS")
				noi di  
				
				/* Check that no variable has only missing alues
				loc am 0
				foreach var of varlist _all {
					cap assert mi(`var')
					if !_rc {
						loc ++am
					}
				}

				if `am' == 0 {
					noi di "Congratulations, There are no variables with ALL MISSING values"
				}

				* Display variables with all mising values
				else {
					noi di "{hline 80}"
					noi di "{p} `am' variables have all missing values, This may be caused by survey programming errors or surveyors skipping this section. Check survey programming. Details are listed below: {p_end}"
					noi di
					noi di  "variable" _column(30) "variable_label"
					noi di "{hline 80}"
			
					foreach var of varlist _all {			
						cap assert mi(`var')
						if !_rc {
							loc var_lab: var label `var'
							noi di "{synopt:`var'}" "`var_lab' {p_end}"
						}					
					}
				}
				
				*/
				
				* Save a copy after each loop
				save "`saving'", replace
			}
		}
		
		log close
		
		* Save a copy after each loop
		cap drop *_sf *_hf *_ok
		save "`saving'", replace
		
		/**********************************************************************
		Check 10:
		SKIPTRACE
		Check the responses to some questions
		and export the answeres to a an excel sheet
		***********************************************************************/
		
		import exc using "`enumdetails'", sh(skiptrace) case(l) first clear
		levelsof keepvars, loc (st_kvs) clean
		
		keep if type == "`type'"
		count if !mi(variable)
		loc v_cnt `r(N)'
		forval i = 1/`v_cnt' {
			loc trvar_`i' = variable[`i']
			loc vlab_`i' = var_lab[`i']
			loc trval_`i' = trace_values[`i']
		}
		
		use "`saving'", clear
		loc trvars ""
		* set trace on
		forval i = 1/`v_cnt' {
			unab vars: `trvar_`i''
			loc vals `trval_`i''
			loc trvars "`trvars' `vars'"
			foreach tv in `vars' {
				tostring `tv', replace force
				foreach v in `vals' {
					gen _tmp = "_" + subinstr(`tv', " ", "_", .) + "_"
					replace `tv' = ".y" if regexm(_tmp, "_`v'_")
					replace `tv' = ".n" if !regexm(_tmp, "_`v'_") & `tv' != ".y"
					drop _tmp
				}				
			} 
		} 
		
		keep `st_kvs' `trvars'
		order `st_kvs'
		destring `trvars', replace

		foreach tv in `trvars' {
			replace `tv' = 0 if `tv' == .y
			replace `tv' = 1 if `tv' == .n
			bysort `enum_id': egen _tmp = mean(`tv')
			replace `tv' = _tmp
			format `tv' %5.2f
			drop _tmp
		}
	
		bysort `enum_id': gen n = _n
		keep if n == 1
		drop n
		
		export exc using "`logfolder'/`date'/dirts_hfc_output_`type'.xlsx", sh("skiptrace") sheetmod first(var)
		/**********************************************************************
		Check 11:
		MISSING RESPONSE RATE
		Check the missing responses rate of some questions
		and export the answeres to a an excel sheet
		***********************************************************************/
		use "`saving'", clear
		
		#d;
		
		loc exc_vars 
				`id'
				`enumvars'
				`dispvars'
				respondent_agree
				audio_consent
				team_*
				deviceid
				submissiondate
				subdate
				startdate
				starttime
				endtime
				enddate
				dur 
				duration
				resp_confirm
				text_audit
				;
		#d cr
		
		ds `exc_vars', not
		loc vars `r(varlist)'
		foreach var in `vars' {
			* set trace on
			cap replace `var' = 1 if mi(`var') & `var' != .o
			if !_rc {
				replace `var' = 0 if !mi(`var') | `var' == .o
			}
			if _rc {
				replace `var' = "1" if mi(`var')
				replace `var' = "0" if !mi(`var')
			}
			
			destring `var', replace
			bysort `enum_id': egen _tmp = mean(`var')
			replace `var' = _tmp
			drop _tmp
			format `var' %5.2f 
		}
		
		bysort `enum_id': gen n = _n
		keep if n == 1
		keep `dispvars' `enumvars' `vars' 
		order `dispvars' `enumvars'
		
		export exc using "`logfolder'/`date'/dirts_hfc_output_`type'.xlsx", sh("missing_rate") sheetmod first(var) nol
		
		
		/**********************************************************************
		Check 12:
		DONT KNOW RESPONSE RATE
		Check the dont know responses rate of some questions
		and export the answeres to a an excel sheet
		***********************************************************************/

		foreach var in `vars' {
			* set trace on
			cap confirm str var `var' 
			if _rc == 7 {
				replace `var' = `var' == .d
			}
			
			else if !_rc {
				replace `var' = regexm(`var', "-999") 
			}
			
			destring `var', replace
			bysort `enum_id': egen `var' = mean(`var')
			format `var' %5.2f 
		}
		
		bysort `enum_id': gen n = _n
		keep if n == 1
		keep `dispvars' `enumvars' `vars' 
		order `dispvars' `enumvars'
		
		export exc using "`logfolder'/`date'/dirts_hfc_output_`type'.xlsx", sh("dontknow_rate") sheetmod first(var) nol
		
				/**********************************************************************
		Check 12:
		DONT KNOW RESPONSE RATE
		Check the dont know responses rate of some questions
		and export the answeres to a an excel sheet
		***********************************************************************/
		
		foreach var in `vars' {
			* set trace on
			cap confirm str var `var' 
			if _rc == 7 {
				replace `var' = `var' == .r
			}
			
			else if !_rc {
				replace `var' = regexm(`var', "-888") 
			}
			
			destring `var', replace
			bysort `enum_id': egen `var' = mean(`var')
			format `var' %5.2f 
		}
		
		bysort `enum_id': gen n = _n
		keep if n == 1
		keep `dispvars' `enumvars' `vars' 
		order `dispvars' `enumvars'
		
		export exc using "`logfolder'/`date'/dirts_hfc_output_`type'.xlsx", sh("refusal_rate") sheetmod first(var) nol

	}
	
	
end

prog def check_headers
	
	#d;
	syntax,					 
	CHECKNUmber(string)	
	CHECKNAme(string)
	;
	#d cr
	
	noi di _dup(82) "*"
	noi di "CHECK #`checknumber': `checkname'"
	noi di _dup(82) "*"
	
end







