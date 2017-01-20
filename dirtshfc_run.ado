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
		
		tab team_id
		
		levelsof team_id, loc (team_ids) clean
		loc team_cnt: word count `team_ids'
		
		foreach t in `team_ids' {
			levelsof team_name if team_id == `t', loc(team_`t') clean			
		}
		
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
				replace team_id == 0
			}
			
			else {
				loc team_name "`team_`t''"
			}
			
			// Genarate a dummy var for date of hfc
			gen hfc = datestr == "`hfcdate'"
			
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
			HFC CHECK #1: SUBMISSION DETAILS
			*******************************************************************/
			
			// Create headers for check
			check_headers, checknu(1) checkna("SUBMISSIONS PER ENUMERATOR")
			noi di  
			noi di as title "enum_id" _column(10) as title "enum_name" _column(20) ///
				as title "`hfcdate'" _column(30) as title "`all_submission'"
			
			levelsof enum_id if team_id == `i', loc (enum_itc) clean
			foreach enum in `enum_itc' {
				levelsof enum_name if enum_id == `enum', loc(name) clean
				
				count if enum_id == `enum' & hfc
				loc day_sub `r(N)'
				
				count if enum_id == `enum'
				loc all_sub `r(N)'
				
				noi di "`enum'" _column(10) "`name'" _column(20) "`day_sub'" _column(30) "`all_sub'"
				
				
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
				count if dups
				noi di "There are `r(N)' duplicates on hhid and resp_type, details are as follows"
				
				sort hhid resp_type
				noi di as title "s_key" _column(13) as title "enum_id" _column(18) as title "enum_name" _column(30) ///
				as title "hhid" _column(38) as title "resp_type" _column(35) as title "resp_name" _column(50) "date_of_interview"
				
				levelsof key if dups, loc (keys) clean
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
			
			/*******************************************************************
			HFC CHECK #3: AUDIO CONSENT RATE
			*******************************************************************/

		
		
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







