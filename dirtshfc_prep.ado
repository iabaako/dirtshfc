*! version 1.0.0 Ishmail Azindoo Baako (IPA) Mar, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will clean scto generated .dta file for the dirts annual survey and prep
	the data for HFC corrections(if neccesary). 

	Define sytax for program. 
	using		: SCTO generated .dta file for survey
	enumvars	: Enumerator variables. The enumerator id and then enumerator name
					variables are espected here. eg. enumv(enum_id enum_name)
	enumdetails	: Data Source for Enumerator Details
	saving		: Name for saving post preped survey dataset
	bcdata		: SCTO generated .dta file for BC data
	bcsave		: Name for saving post preped bc dataset
*/

	prog def dirtshfc_prep
		
		#d;
		syntax using/,
			ENUMVars(namelist min=2 max=2)
			ENUMDetails(string)			
			SAVing(string)
			RTYpe(string)
			[
			BCData(string)				
			BCSave(string)
			]
		;
		#d cr

	qui {	
		
		/***********************************************************************
		Set the stage
		***********************************************************************/
		* Check that the directory specified as is encrypted with Boxcryptor
		loc pathx = substr("`using'", 1, 1)
		if "`pathx'" != "X" & "`pathx'" != "." {
			noi di as err "dirtshfc_prep: Hello!! Using Data must be in a BOXCRYPTED folder"
			exit 601
		}
		
		* Get the enumerator related vars from arg enumvars
		token `enumvars'
		loc enum_id "`1'"				// Enumerator ID
		loc enum_name "`2'"				// Enumerator Name
		
		
		* Check that type is valid
		loc rtype = lower("`rtype'")
		if "`rtype'" != "r1d1" & "`rtype'" != "r1d2" & "`rtype'" != "r2" {
			noi di as err "{p}dirtshfc_prep: SYNTAX ERROR!! Option `rtype' not allowed. Specify r1d1, r1d2 or r2 with rtype{p_end}"
			exit 601
		}
		
		/***********************************************************************
		Import enumerator details and save it in a tempfile
		***********************************************************************/
		tempfile enum_data 
		
		import exc using "`enumdetails'", sh(enum_details) case(l) first clear
		destring *_id, replace
		ren (enum_id enum_name) (`enum_id' enum_name_keep)
		drop if mi(`enum_id')		
		cap isid `enum_id' 
		if _rc {
			duplicates tag `enum_id', gen(dup)
			sort `enum_id'
			noi di in red "dirtshfc_prep: Variable `enum_id' is not UNIQUE"
			noi di
			novarabbrev noi l `enum_id' enum_name_keep if dup, noo sepby(`enum_id')
			noi di
			noi di as err "{p} Please ensure that all Field Staff have one Unique _ID, " ///
				"if you added a new Field Staff assign a new ID to that field staff." ///
				"Re-run the master do-file when this is done.{p_end}"
			exit 459
		}
		
		* Save the dataset in a temp_file if there is no error
		else {
			save `enum_data'
		}
		
		/***********************************************************************
		Import the SCTO generated dataset. This dataset is what is created after 
		running the SCTO generated import do-files
		***********************************************************************/
	
		* Confirm that string specified with directory is an actual directory
		cap confirm file "`using'"
		if !_rc {
			use "`using'", clear
		}
			
		* Throw and error if file does not exist
		else {
			noi di as err "dirtshfc_prep: File `using' not found"
			exit 601
		}
		
		* Check that enum vars exist
		foreach v in `enum_id' `enum_name' {
			cap confirm var `v'
			if _rc == 111 {
				noi di as err "dirtshfc_prep: SYNTAX ERROR!! variable `v' not in data"
				exit 111
			}
		}

		
		* Check that the dataset contains some data
		if (_N==0) {
			noi di as error "dirtshfc_prep: Imported Data from SCTO has no observation"
			exit 2000
		}
		
		* Check that the dataset contains the key var and then generate skey
		cap confirm var key
		if !_rc {
			* First confirm that skey is unique for this dataset. It usually is
			cap isid key
			if !_rc {
				/* generate a shorter key. This will be easier for field teams 
				to work with. There is a chance that that the skey may not be
				unique, but it should always be if combined with id var. */
				
				gen skey = substr(key, -12, .)
			}
			
			* Stop running if key is not unique
			else {
				noi di as err "dirtshfc_prep: FATAL ERROR!! Variable KEY does not UNIQUELY identify the observations"
				noi di as err "Contact Ishmail or Vinny Immediately"
				exit 459
			}
		}
		
		else {
			noi di as err "dirtshfc_prep: FATAL ERROR!! variable KEY is MISSING from dataset"
			noi di as err "Contact Ishmail or Vinny Immediately"
			exit 111
		}
		
		/**********************************************************************
		Change var types, drop unwanted vars and merge with the enum_details dataset
		***********************************************************************/
			
		* Ensure that certain variables are numeric 
		#d;
			destring
				`enum_id' 
				deviceid 
				duration
				formdef_version
				,
				replace
				;
		#d cr
		
		* Drop unwanted vars (add more vars if neccesary)
		#d;
			drop 
				subscriberid 
				simid 
				devicephonenum 
				username 
				caseid *_helper*			
				;
		#d cr
		
		* Merge in enum_data 
		merge m:1 `enum_id' using "`enum_data'", nogen
	
		replace `enum_name' = enum_name_keep
		drop enum_name_keep
		
		* Drop the enum_data from memory
		macro drop _enum_data
		
		/***********************************************************************
		Format date and time variables and create a string date var in the format
		dd_mm_yy (06_Feb_17)
		***********************************************************************/
		
		datestr submissiondate, newvar(subdate_str)
		datestr starttime, newvar(startdate_str)
		datestr endtime, newvar(enddate_str)
	
		/***********************************************************************
		Rename duration var to dur and convert create a new duration varation 
		that contains the duration in minutes
		***********************************************************************/
		rename duration dur
		la var dur "Survey CTO generated duration in seconds"
		
		// Generate a dur_min variable
		gen duration = floor(dur/60)
		la var duration "Survey duration in full minutes. Estimated from variable dur"
		
		/***********************************************************************
		Drop Unneeded observations in repeat groups. Sometimes repeat groups 
		may contain unneeded information because the surveyor mistakenly opened
		a repeat group and started entering some information into it before 
		realising that they didnt need it. In some cases if the repeat group is
		closed without removing the information, it already entered information
		appears in the dataset.
		
		* First, remove excess repeat groups
		* Second, remove values in repeat groups that are not really needed
		***********************************************************************/
		drop if mi(key)
		save "`saving'", replace
		* Import data from imports sheet
		import exc using "`enumdetails'", sh(repeats) case(l) first clear
		levelsof rpt_grp_name if rtype == "`rtype'", loc (r_grps) clean
		
		* Generate locals to hold repeat trigger and var names
		foreach g in `r_grps' {
			levelsof rpt_trigger if rpt_grp_name == "`g'" & rtype == "`rtype'", loc (`g'_trig) clean
			levelsof rpt_vars if rpt_trigger == "``g'_trig'" & rpt_grp_name == "`g'" & rtype == "`rtype'", loc (`g'_vars) clean
		}
	
		* Reload data
		use "`saving'", clear
		
		loc N = _N
		foreach g in `r_grps' {
			cap confirm var ``g'_trig'
			if !_rc {
				* Loop through each repeat group and drop unneeded vars. For instance if we expect
				* a max of 25 repeats, drop all 
				destring ``g'_trig', replace
				su ``g'_trig'
				loc rp_max `r(max)'
				foreach gvar in ``g'_vars' {
					* Get the length of the string + 1 for the "_"
					cap unab var: `gvar'*
					if !_rc {
						foreach v in `var' {
							loc tmp_n = substr("`v'", length("`gvar'") + 2, .)
							if `tmp_n' > `rp_max' {
								drop `v'
								noi di "{bf:dropping variable `v'}"
							}
							
							* Now for each repeat group we want to drop the value if the var 
							* exceed what is expected for that observation. For instance if a farmer 
							* has 5 plots we want to drop all the values in variables that are based
							* on the repeat trigger and exceed the 5th count

							forval z = 1/`N' {
								loc tv = ``g'_trig'[`z'] + 1
								if !mi("`tv'") & "`tv'" != "." {
									foreach t in `tv' {
										cap replace `gvar'_`t' = . in `z'
										if _rc == 109 {
											replace `gvar'_`t' = "" in `z'
										}
									}
								}
							}
						}	
					}
					
				}
				
			}
			
			
			else {
				noi di "`g' not found'"
			}
			
		}
		
		/***********************************************************************
		Recode numeric variables
		***********************************************************************/
		ds, has(type numeric)
		loc numeric `r(varlist)'
		
		recode `numeric' (-222 = .o) (-888 = .r) (-999 = .d)
		
		/***********************************************************************
		Remove excess plot ids
		***********************************************************************/
		cap su plot_nbr
		if !_rc {
			loc plot_max = `r(max)' + 1
			forval z = `plot_max'/30 {
				drop plot`z'
			}
		}		
		/***********************************************************************
		Save data
		***********************************************************************/
		
		* drop empty observations
		drop if mi(key)
		save "`saving'", replace
		
		/***********************************************************************
		Prepare backcheck data for analysis
		
		** WORK ON THIS AFTER SEEING THE BACK CHECK DATA**
		***********************************************************************/
		
		* Check that the bcdata option was specified and import bcdata if it was		
		cap use "`bcdata'", clear
		if _rc == 601 {
			noi di as err "dirtshfc_prep: Back check dataset (`bcdata') not found"
			exit 601
		}
			
		else {
			* Write prep code for bcdata here
			
		}
	}
		
end


prog def datestr

	syntax varname, newvar(string)
		
	qui {

		gen dofc_temp = dofc(`varlist')
		gen `newvar'_day = day(dofc_temp)
		gen `newvar'_mon = month(dofc_temp)
		gen `newvar'_yr = year(dofc_temp)
		tostring `newvar'_*, replace
			
		* Change the month var to a short mon in word. For instance 2 to Feb
		loc it 1
		foreach dt in `c(Mons)' {
			replace `newvar'_mon = "`dt'" if `newvar'_mon == "`it'"
				loc ++it
		}

		replace `newvar'_yr = substr(`newvar'_yr,3, .)
			
		foreach dsv of varlist `newvar'_* {
			replace `dsv' = "0" + `dsv' if length(`dsv') == 1
		}
			
		generate `newvar' = `newvar'_day + "_" + `newvar'_mon + "_" + `newvar'_yr
		replace `newvar' = upper(`newvar')
		drop `newvar'_* dofc_temp

	}
end





