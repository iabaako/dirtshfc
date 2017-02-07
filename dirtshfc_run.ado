*! version 0.0.3 Ishmail Azindoo Baako (IPA) Jan, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will run Checks on data that is saved from dirtshfc_prep.ado

	Define sytax for program. 
	varname		: ID variable for survey
	date 		: Date of interest for HFC
	dispvars	: Variables to display at hh level excluding the hhid
	using		: .dta file saved from dirtshfc_correct
	enumvars	: Enumerator variables. The enumerator id and then enumerator name
					variables are espected here. eg. enumv(enum_id enum_name)
	logfolder	: Name of folder were logfiles are saved
	saving		: Name for saving data after hfc is run

*/	
	prog def dirtshfc_run
	
		syntax varname using/,
		DATE(string)
		DISPVars(varlist)
		ENUMVars(varlist min=2 max=2)
		LOGFolder(string)
		SAVing(string)

	qui {	
		
		/***********************************************************************
		Set the stage
		***********************************************************************/
		* Check that the directory specified as is encrypted with Boxcryptor
		loc pathx = substr("`directory'", 1, 1)
		if `pathx' != "X" & `pathx' != "." {
			noi di as err "dirtshfc_run: Hello!! Using Data must be in a BOXCRYPTED folder"
			exit 601
		}
		
		* Get the enumerator related vars from arg enumvars
		token `enumvars'
		loc enum_id "`1'"				// Enumerator ID
		loc enum_name "`2'"				// Enumerator Name
		
		* Make the local date an upper to avoid differnces in cases
		loc date = upper(`date')
		
		* Represent the id var with the local id
		loc id `varlist'

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
		foreach t in `team_ids' {
			levelsof team_name if team_id == `t', loc(team_`t') clean			
		}
		
		/**********************************************************************
		Import constraint values
		***********************************************************************/			
		* Import sheets containing constraint values
		import exc using "`constraint'", sh(enum_details) case(l) first clear
		
		count if !mi(variable)
		loc v_cnt `r(N)'
		
		* Loop through each variable and get the name 
		forval i = 1/`v_cnt' {
			loc v_name = variable[`i']
			unab v_name: `v_name'
			
			* Check that a wild card was used and loop through each var in local
			* and save the values in locals
			loc v_name_cnt: word count `v_name'
			if `v_name_cnt' > 1 {
				foreach var of varlist `v_name' {
					loc `var'_hmin = hard_min[`i']
					loc `var'_smin = soft_min[`i']
					loc `var'_smax = soft_max[`i']
					loc `var'_hmax = hard_max[`i']
				}
			}
			
			* get the soft and hard contraint values and save them in a local
			else {
				loc `v_name'_hmin = hard_min[`i']
				loc `v_name'_smin = soft_min[`i']
				loc `v_name'_smax = soft_max[`i']
				loc `v_name'_hmax = hard_max[`i']
			}
		}
		
		* Get the constrained vars and save the names in a local v_names
		levelsof variable if !mi(variable), loc (v_names) clean
		unab v_names: `v_names'
		
		/**********************************************************************
		Import the SCTO generated dataset. This dataset is what is created 
		after dirtshfc_correct.ado is runs
		***********************************************************************/	
		cap confirm file "`using'"
		if !_rc {
			use "`using'", clear
				
			*Genarate a dummy var for date of hfc
			gen hfc = datestr == "`date'"
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
		loc t1 0
		* Loop through each team and produce log sheets (Team 0 includes all enums)
		forval i in 0 `team_ids' {
			loc ++t1
			* For the 1st iteration, import data and set team to 0
			if `i' == 0 {
				use "`using'", clear
				loc team_name "All"
				gen team_id_keep = team_id
				replace team_id == 0
				
				* tag all duplicates on id var
				duplicates tag `id', gen(dup)
			}
			
			* 
			else if `i' == `2' {
				replace team_id = team_id_keep
				drop team_id_keep
				loc team_name "`team_`t''"
			}
			
			else {
				loc team_name "`team_`t''"
			}
						
			* start log
			cap log
			log using "`logfolder'/`date'/dirtshfc_log_TEAM_`team_name'"
			
			* Create Header
			noi di "{hline 82}"
			noi di _dup(82) "-"
			noi di _dup(82) "*"
	
			noi di "{bf: HIGH FREQUENCY CHECKS FOR DIRTS ANNUAL SURVEY 2017}"
			noi di _column(10) "{bf:HFC LOG: TEAM `team_name'}" 
			noi di
			noi di "{bf: HFC Date		: `date'}"
			noi di "{bf: Running Date	: `c(current_date)'}"
	
			noi di _dup(82) "*"
			noi di _dup(82) "-"
			noi di "{hline 82}"
			
			
			/*******************************************************************
			HFC CHECK #1: SUBMISSION DETAILS AND CONSENT RATES
			*******************************************************************/
			
			* Create headers for check
			check_headers, checknu(1) checkna("SUBMISSIONS PER ENUMERATOR")
			noi di  
			
			* Create column titles for submission details
			noi di as title "`enum_id'" _column(10) as title "`enum_name'" _column(20) ///
				as title "hfcdate" _column(30) as title "all_sub" _column(38) as title "consent_rate" 
			
			* Display submission details and consent rates for each field staff
			levelsof `enum_id' if team_id == `i', loc (enum_itc) clean
			foreach enum in `enum_itc' {
				levelsof enum_name if enum_id == `enum', loc(name) clean
				
				count if `enum_id' == `enum' & hfc
				loc day_sub `r(N)'
				
				count if `enum_id' == `enum'
				loc all_sub `r(N)'
				
				count if `enum_id' == `enum' & consent == 1
				loc consent_rate `r(N)'
				
				noi di "`enum'" _column(10) "`name'" _column(20) "`day_sub'" _column(30) ///
					"`all_sub'" _column(38) "`consent_rate'"
			}
			
			* drop unneeded macros
			macro drop _enum _name _day_sub _all_sub _consent_rate
			
			/*******************************************************************
			HFC CHECK #2: DUPLICATES
			*******************************************************************/
			* Create check header
			check_headers, checknu(2) checkna("DUPLICATES ON `id'")
			noi di  
			
			* Check that there are duplicates with this team
			count if dup & team_id == `i'
			if `r(N)' == 0 {
				noi di "Congratulations, Your Team has no duplicates on hhid and resp_type"
			}
			
			* List observations that are duplicate on on idvar
			else {		
				noi di in red "There are `r(N)' duplicates on `id', details are as follows"
				sort `id' `dispvars'
				noi l skey `id' `dispvars' if dup & team_id == `i', noo sepby(`id')	
			}
			
			/*******************************************************************
			HFC CHECK #3: AUDIO CONSENT RATE
			*******************************************************************/
			* Creat Check Header 
			check_headers, checknu(3) checkna("AUDIO CONSENT RATE (% of Consented Surveys Only)")
			noi di  
			
			* Create display column titles
			noi di "Audio consent rates (% of Consented Surveys Only) for your team are as follows:"
			noi di as title "`enum_id'" _column(8) as title "`enum_name'" _column(30) ///
			as title "ac_rate" _column(34) as title "tot_cons_surveys" 
			
			* For each enumerator, display audip consent rate and total consented surveys
			foreach enum of `enum_itc' {
				
				levelsof `enum_name' if `enum_id' == `enum', loc (name) clean
				
				count if `enum_id' == `enum' & consent == 1
				loc all_sub `r(N)'
				
				count if audio_consent == 1 & `enum_id' == `enum' and consent == 1 
				loc ac_rate = round(`all_sub'/`r(N)', 2)
			
				noi di "`enum'" _column(8) "`name'" _column(30) "`ac_rate'%" _column(34) "`all_sub'" 
			}
			
			* Drop unneeded macros
			macro drop _enum _name _ac_rate _all_sub
			
			/*******************************************************************
			HFC CHECK #4: FORM VERSIONS
			*******************************************************************/
			* Create check headers
			check_headers, checknu(4) checkna("FORM VERSIONS")
			noi di  
			
			* Get the latest form version used on submission date of interest
			su formdef_version if hfc
			loc form_vers `r(max)'
			
			* Check that all members are using the right form and display congrats
			cap assert formdef_version == `form_vers' if team_id == `i' & hfc
			if !_rc {
				noi di "Congratulations, all team members are using the latest form version for `date'" 
				noi di "Form Version for `date': " as res "`form_vers'"
			}
			
			* Display form version details if enum is using the wrong for
			else {
				* Display message and column titles
				noi di in red "Some members of your team may have used the wrong form version for `date'" 
				noi di in red "Form Version for `date': " as res `form_vers'	
				
				noi di as title "`enum_id'" _column(8) as title "`enum_name'" _column(30) as title "form_version"

				* For each enumerator in team with wrong form version, display the id, name and form version used
				levelsof `enum_id' if formdef_version != `form_vers' & team_id == `i' & hfc, loc (enum_rfv) clean
				foreach enum in `enum_rfv' {
					levelsof `enum_name' if `enum_id' == `enum', loc (name) clean
					levelsof formdef_version if `enum_id' == `enum' & formdef_version != `form_version', loc (form_version) clean
					
					noi di "`enum'" _column(8) "`name'" _column(30) "`form_version'"
				}
			}	
			
			/*******************************************************************
			HFC CHECK #5: CHECK SURVEY DATES
			Check that survey dates fall with reasonable minimum and maximum dates
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







