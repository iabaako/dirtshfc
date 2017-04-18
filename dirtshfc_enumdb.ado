*! version 1.0.0 Ishmail Azindoo Baako (IPA) April 9, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will produce enumdbs from data that is saved after HFC run

	Define sytax for program. 
	varname		: ID variable for survey
	enumvars	: Enumerator variables. The enumerator id and then enumerator name
					variables are espected here. eg. enumv(enum_id enum_name)
	dispvars	: Variables to display at hh level excluding the hhid
	logfolder	: Name of folder were logfiles are saved
	saving		: Name for saving data after hfc is run

*/	
	prog def dirtshfc_enumdb
		
		#d;
		syntax name using/, 
		DATE(string)
		INPUTSHeet(string)
		ENUMVars(namelist min=2 max=2)
		LOGFolder(string)			
		RTYpe(string)
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
		loc type = lower("`rtype'")
		if "`rtype'" != "r1d1" & "`rtype'" != "r1d2" & "`rtype'" != "r2" {
			noi di as err "dirtshfc_prep: SYNTAX ERROR!! Specify r1d1, r1d2 or r2 with type"
			exit 601
		}
		
		* Get the enumerator related vars from arg enumvars
		token `enumvars'
		loc enum_id "`1'"				// Enumerator ID
		loc enum_name "`2'"				// Enumerator Name
		
		* Represent the id var with the local id
		loc id `namelist'

		/**********************************************************************
		Import the SCTO generated dataset. This dataset is what is created 
		after dirtshfc_run.ado is run
		***********************************************************************/	
		cap confirm file "`using'"
		if !_rc {
			use "`using'", clear
		}
			
		* Throw an error if file does not exist
		else {	
			noi di as err "dirtshfc_run: File `using' not found"
			exit 601
		}
		
		* Check if log folder exist, else create it
		cap confirm file "`logfolder'/`date'/nul"
		if _rc == 601 {
			mkdir "`logfolder'/`date'"
		}
		
		/**********************************************************************
		SKIPCONTROL RATE
		Check the responses to some questions
		and export the answeres to a an excel sheet
		***********************************************************************/
		
		import exc using "`inputsheet'", sh(skipcontrol) case(l) first clear
		levelsof keepvars, loc (keepvars) clean
		replace rtype = lower(rtype)
		
		keep if rtype == "`rtype'"
		count if !mi(variable)
		loc v_cnt `r(N)'
		forval i = 1/`v_cnt' {
			loc trvar_`i' = variable[`i']
			loc vlab_`i' = var_lab[`i']
			loc trval_`i' = exp_values[`i']
		}
		
		use "`using'", clear
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
		
		keep `keepvars' `trvars'
		order `keepvars'
		destring `trvars', replace

		foreach tv in `trvars' {
			replace `tv' = 0 if `tv' == .y
			replace `tv' = 1 if `tv' == .n
			bysort `enum_id': egen _tmp = mean(`tv')
			replace `tv' = _tmp
			format `tv' %4.2f
			drop _tmp
		}
	
		bysort `enum_id': gen n = _n
		bysort `enum_id': gen submissions = _N
		keep if n == 1		
		order `keepvars' submissions
		sort team_id submissions
		
		drop n
		
		cap export exc using "`logfolder'/`date'/dirts_hfc_enumdb_`rtype'.xlsx", sh("skipcontrol_rate") sheetmod first(var)
		if _rc == 603 {
			noi di in red "PLEASE NOTE: Export File for `rtype' Crashed. ENUMDB is been skipped"
		}
		/**********************************************************************
		MISSING RESPONSE RATE
		Check the missing responses rate of some questions
		and export the answeres to a an excel sheet
		***********************************************************************/
		
		import exc using "`inputsheet'", sh(enumdb) case(l) first clear
		drop miss_*
		levelsof keepvars, loc (keepvars) clean
		
		foreach spec in missing dk ref {
			replace rtype_`spec' = lower(rtype_`spec') 
			levelsof exc_var_`spec' if rtype_`spec' == "`rtype'" | rtype_`spec' == "all", loc (exc_var_`spec') clean
		}
				
		use "`using'", clear
		cap drop *_sf *_hf *_ok
		drop hfc dup start_date end_date valid_date valid_duration

		ds `exc_var_missing', not
		loc vars `r(varlist)'
		loc ms_track 0
		loc miss_vars ""
		foreach var in `vars' {
			* set trace on
			cap assert !mi(`var') & !mi(key)
			if _rc == 9 {
				cap assert mi(`var') & !mi(key)
				if _rc == 9 {
					cap confirm str var `var'
					if _rc == 7 {
						replace `var' = .y if mi(`var') & `var' != .o
						replace `var' = .n if `var' != .y
						loc cnt 1
					}
					
					else if !_rc {
						replace `var' = ".y" if mi(`var')
						replace `var' = ".n" if `var' != ".y"
						loc cnt 1
					}
					
				}
				
				else if !_rc {
					drop `var'
					loc cnt 0
				}
			}
			
			else if !_rc {
				drop `var'
				loc cnt 0
			}
			
			if `cnt' == 1 { 
				loc miss_vars "`miss_vars' `var'"
				destring `var', replace
				replace `var' = `var' == .y
			
				bysort `enum_id': egen _tmp = mean(`var')
				replace `var' = _tmp
				drop _tmp
				format `var' %5.2f 
				loc ms_track = `ms_track' + `cnt'
			}
			
		}
		
		if `ms_track' > 0 {
			bysort `enum_id': gen n = _n
			bysort `enum_id': gen submissions = _N
			keep if n == 1
			keep `keepvars' submissions `miss_vars' 
			order `keepvars' submissions
			sort team_id submissions
			
			cap export exc using "`logfolder'/`date'/dirts_hfc_enumdb_`rtype'.xlsx", sh("missing_rate") sheetmod first(var) nol
			if _rc == 603 {
				noi di in red "PLEASE NOTE: Export File for `rtype' Crashed. ENUMDB is been skipped"
			}
		}
		
		/**********************************************************************
		DONT KNOW RESPONSE RATE
		Check the dont know responses rate of some questions
		and export the answeres to a an excel sheet
		***********************************************************************/
		
		* set trace on
		use "`using'", clear
		cap drop *_sf *_hf *_ok
		
		ds `exc_var_dk', not
		loc vars `r(varlist)'
		loc track_nm 0
		foreach var in `vars' {
			* set trace on
			cap confirm str var `var' 
			if _rc == 7 {
				cap assert `var' != .d
				if _rc == 9 {
					replace `var' = `var' == .d
					loc cnt 1
				}
				else if !_rc {
					drop `var'
					loc cnt 0
				}
			}
			
			else if !_rc {
				cap assert !regexm(`var', "-999")
				if _rc == 9 {
					replace `var' = ".y" if regexm(`var', "-999")
					replace `var' = ".n" if `var' != ".y"
					destring `var', replace 
					replace `var' = `var' == .y
					loc cnt 1
				}
				
				else if !_rc {
					drop `var' 
					loc cnt 0
				}
			}
			
			if `cnt' == 1 {
				bysort `enum_id': egen _tmp = mean(`var')
				replace `var' = _tmp
				format `var' %5.2f
				drop _tmp
				loc rate_vars "`rate_vars' `var'"
				loc track_nm = `track_nm' + `cnt'
			}
		}
		
		if `track_nm' > 0 {
			bysort `enum_id': gen n = _n
			bysort `enum_id': gen submissions = _N
			keep if n == 1
			keep `keepvars' submissions `rate_vars'
			order `keepvars' submissions
			sort team_id submissions
			
			cap export exc using "`logfolder'/`date'/dirts_hfc_enumdb_`rtype'.xlsx", sh("dontknow_rate") sheetmod first(var) nol
			if _rc == 603 {
				noi di in red "PLEASE NOTE: Export File for `rtype' Crashed. ENUMDB is been skipped"
			}
		}
		

		/**********************************************************************
		Check 13:
		REFUSAL RATE RESPONSE RATE
		Check for refusal responses rate of some questions
		and export the answeres to a an excel sheet
		***********************************************************************/
		
		use "`using'", clear
		cap drop *_sf *_hf *_ok
		
		ds `exc_var_ref', not
		loc track_nm 0
		loc rate_vars ""
		foreach var in `vars' {
			* set trace on
			cap confirm str var `var' 
			if _rc == 7 {
				cap assert `var' != .r
				if _rc == 9 {
					replace `var' = `var' == .r
					loc cnt 1
				}
				else if !_rc {
					drop `var'
					loc cnt 0
				}
			}
			
			else if !_rc {
				cap assert !regexm(`var', "-888")
				if _rc == 9 {
					replace `var' = ".y" if regexm(`var', "-888")
					replace `var' = ".n" if `var' != ".y"
					destring `var', replace 
					replace `var' = `var' == .y
					loc cnt 1
				}
				
				else if !_rc {
					drop `var' 
					loc cnt 0
				}
			}
			
			if `cnt' == 1 {
				bysort `enum_id': egen _tmp = mean(`var')
				replace `var' = _tmp
				format `var' %5.2f
				drop _tmp
				loc rate_vars "`rate_vars' `var'"
				loc track_nm = `track_nm' + `cnt'
			}
		}
		
		if `track_nm' > 0 {
			bysort `enum_id': gen n = _n
			bysort `enum_id': gen submissions = _N
			keep if n == 1
			keep `keepvars' submissions `rate_vars'
			order `keepvars' submissions
			sort team_id submissions
		
			cap export exc using "`logfolder'/`date'/dirts_hfc_enumdb_`rtype'.xlsx", sh("refusal_rate") sheetmod first(var) nol
			if _rc == 603 {
				noi di in red "PLEASE NOTE: Export File for `rtype' Crashed. ENUMDB is been skipped"
			}

		}
		
		
		/**********************************************************************
		SURVEY DURATIONS
		***********************************************************************/
		
		use "`using'", clear
		cap drop *_sf *_hf *_ok

		keep if !mi(key)
		keep `keepvars' `enum_id' `enum_name' duration
		
		bysort `enum_id': egen mean_dur = mean(duration)
		bysort `enum_id': gen n = _n
		bysort `enum_id': gen submissions = _N
		keep if n == 1
		replace duration = mean_dur
		drop n mean_dur
		order `keepvars' submissions duration
		sort team_id submissions
				
		cap export exc using "`logfolder'/`date'/dirts_hfc_enumdb_`rtype'.xlsx", sh("duration") sheetmod first(var) nol
		if _rc == 603 {
			noi di in red "PLEASE NOTE: Export File for `rtype' Crashed. ENUMDB is been skipped"
		}
	}
	
	
end




