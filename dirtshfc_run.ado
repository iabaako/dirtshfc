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
			
			// Throw and error if file does not exist
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
		
			if `i' == 0 {
				loc team_name "All"
			}
			
			else {
				loc team_name "`team_`t''"
			}
		
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
	CHECKNUmber(string)
	CHECKNAme(string)
	
	noi di _dup(82) "*"
	noi di _dup(82) "-"
	noi di "CHECK #`checknumber': `checkname'"
	noi di _dup(82) "-"
	noi di _dup(82) "*"
	
end







