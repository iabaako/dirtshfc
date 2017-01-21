*! version 0.0.4 Ishmail Azindoo Baako (IPA) Jan, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will clean scto generated .dta file for the dirts annual survey and prep
	the data for HFC checks. A clean pre_hfc .dta file will be saved after this.
*/ 

/* Define sytax for program. varname will be the id var of the observation, for 
	cleaning stage of the hfc, the id var determined by the survey team is not
	expected to be unique as multiple submissions may cause duplication in the 
	id variables defined for the survey. We will be using the scto generated key
	instead. The NEWID will be a shorter version of the ID var that will be gened
	and saved in the new semi cleaned dataset
*/

	program define dirtshfc_prep
	
		syntax,
		DIRECTory(string) 			///
		DATAset(string)				///
		ENUMDetails(string)			///
		SAVing(string)				///
		[BCData(string)]			///
		[BCSsave(string)]

	qui {	
		
		/***********************************************************************
		Set the stage
		***********************************************************************/
		// Save the name of the present working directory
		loc hfcpwd = c(pwd)
		
		// Check that the directory specified as is encrypted with Boxcryptor
		loc pathx = substr("`directory'", 1, 1)
		if `pathx' != "X" {
			noi di as err "dirtshfc_prep: Hello!! Folder specified with directory must be BOXCRYPTED"
			exit 601
		}
		
		/***********************************************************************
		Import enumerator details and save it in a tempfile
		***********************************************************************/
		tempfile enum_data 
		
		import excel using "`enumdetails'", sh(enum_details) case(l) first clear
		destring *_id, replace
		save `enum_data'
		
		/***********************************************************************
		Import the SCTO generated dataset. This dataset is what is created after 
		running the SCTO generated import do-files
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
			
				noi di as err "dirtshfc_prep: File `dataset' not found in `directory'"
				exit 601
			}
		}
		
		// If directory does not exist
		else {
			
			noi di as err "`directory' does not found"
			exit 601
		}
		
		
		// Check that the dataset contains some data
		if (_N==0) {
			noi di as error "dirtshfc_prep: no observation"
			exit 2000
		}
		
		// Check that the dataset contains the key var. Generate s_key if yes or 
		// Stop if id does. 
		
		cap confirm var key
		if !_rc {
			
			// First confirm that s_key is unique for this dataset. It usually is
			cap isid key
			if !_rc {
				
				/* generate a shorter key. This will be easier for field teams 
				to work with. There is a chance that that the s_key may not be
				unique, but it should always be if combined with id var. */
				
				gen s_key = substr(key, -12, .)
			}
			
			else {
				noi di as err "dirtshfc_prep: variable key does not uniquely identify the observations"
				exit 459
			}
		}
		
		else {
			noi di as err "dirtshfc_prep: variable key not found"
			exit 111
		}
		
		/**********************************************************************
		Rename relevant variables, change var typesdrop unwanted vars and merge 
		in the enum_details dataset
		
		**ADD SOME MORE VARS TO REN AND DROP AFTER LOOKING AT THE ACTUAL DATA**
		***********************************************************************/
		
		// Rename relevant vars. 
		
		ren (FPrimary s_suv_name) ///
			(hhid 	  enum_id	)
			
		// Enusre that certain variables are numeric 
		#d;
			destring
				enum_id 
				deviceid 
				duration
				formdef_version
				,
				replace
				;
		#d cr
		
		// Drop unwanted vars (add more vars if neccesary)
		
		#d;
			drop 
				subscriberid 
				simid 
				devicephonenum 
				username 
				caseid
				;
		#d cr
		
		// Merge in enum_data 
		merge m:1 using "`enum_data'", nogen
		/***********************************************************************
		Format date and time variables and create a string date var in the format
		dd_mm_yy
		***********************************************************************/
		
		datestr submissiondate, newvar(subdate_str)
		datestr starttime, newvar(startdate_str)
		datestr endtime, newvar(enddate_str)
		
		
		/***********************************************************************
		Drop observations that are as a result of duplicate submission. In such 
		situatitions the duration and as hhid will be the same
		***********************************************************************/
		cap isid hhid duration
		if _rc == 459 {
			noi di in red "Dropping some duplicate submissions based on hhid and duration"
			duplicates drop hhid duration, force
		}
		
		// Generate a dur_min variable
		gen dur_min = floor(duration/60)
		
		
		/***********************************************************************
		Drop Unneeded observations in repeat groups. Sometimes repeat groups 
		may contain unneeded information because the surveyor mistakenly opened
		a repeat group and started entering some information into it before 
		realising that they didnt need it. IN some cases if the repeat group is
		closed without removing the information, it stays in the data. 
		
		** WORK ON THIS AFTER SEEING THE IMPORT DATA**
		** THERE MAY BE A NEED TO RESHAPE AND MERGE**
		***********************************************************************/
		
		
		/***********************************************************************
		Replace variables which were skipped due to relevance: In some situations
		The survey will be programmed to skip so that some questions are not 
		repeated. For instance if the respondent is the household head, there 
		will be no need to ask for details of the household head after the details
		of the respondent has already been taken. This is not mearnt to replace 
		sections that were skipped due to relevance because some surveyors may
		be answering questions in ways that let them skip certain questions and 
		it will be good to catch that
		
		** WORK ON THIS AFTER SEEING THE IMPORT DATA**

		***********************************************************************/

	
	
		/***********************************************************************
		Save a copy of the data ready for correction
		***********************************************************************/
		
		save `saving', replace
		
		
		/***********************************************************************
		Prepare backcheck data for analysis
		
		** WORK ON THIS AFTER SEEING THE BACK CHECK DATA**
		***********************************************************************/
		
		// Check that the bcdata option was specified and import bcdata if it was
		if !mi(`bcdata') {
			cap use "`bcdata'", clear
			if _rc == 601 {
				noi di as err "dirtshfc_prep: Back check dataset (`bcdata') not found"
				exit 601
			}
			
			// Write prep code for bcdata here
		}
	}
	
	
end


program define datestr

		syntax varname, newvar(string)
		
		qui {
		
			// Use a tempvar to save the dofc format of the date var
			gen dofc_temp = dofc(`varlist')
			
			gen `newvar'_day = day(`dofc_temp')
			gen `newvar'_mon = month(`dofc_temp')
			gen `newvar'_yr = year(`dofc_temp')
			
			tostring `newvar'_*, replace
			replace `newvar'_yr = substr(yr,3, .)
			
			foreach ds_var of varlist `newvar'_* {
				replace `ds_var' = 0 + `ds_var' if length(`ds_var') == 1
			}
			
			generate `newvar' = day + "_" + mon + "_" + year
			drop `newvar'_*

		}
end





