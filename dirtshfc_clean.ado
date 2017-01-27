*! version 0.0.0 Vincent Armentano (IPA) Jan, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will clean the post hfc data and make it ready for analysis
*/ 

/* Define sytax for program. 
*/

	program define dirtshfc_clean
	
		syntax,
		DIRECTory(string)
		DATAset(string)
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
			noi di as err "dirtshfc_run: Hello!! Folder specified with directory must be BOXCRYPTED"
			exit 601
		}
		
		/***********************************************************************
		Import Dataset
		***********************************************************************/
		use "`dataset'", clear
		
		
		/***********************************************************************
		Clean Dataset
		***********************************************************************/

		
		// Write cleanining code here
		
		
		
		
		// return to starting directory
		cd "`hfcpwd'"
	}
	
	
end


