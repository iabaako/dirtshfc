*! version 0.0.0 Ishmail Azindoo Baako (IPA) Jan, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will make corrections to the DIRTS HFC file and prep it for the dirtshfc_run.ado
*/ 

/* Define sytax for program. 
*/

	program define dirtshfc_clean
	
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

			destring *_id, replace
			save `corr_data'
		
			/*******************************************************************
			Import the SCTO generated dataset. This dataset is what is created 
			after dirtshfc_clean.ado is runned
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
		
			/*******************************************************************
			Drop Observations. Drop observations that have been marked in the 
			correct sheet to be dropped
			********************************************************************/
		
			/*******************************************************************
			Mark Flagged observations as okay. Some observatios may be flagged as 
			outliers or suspicious but upon investigation may be deemed as okay.
			********************************************************************/
			
			
			/*******************************************************************
			Replacements
			********************************************************************/
	}
	
	
end






