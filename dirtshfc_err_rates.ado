*! version 0.0.0 Ishmail Azindoo Baako (IPA) Jan, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will calculate HFC and back check error rates
*/ 

/* Define sytax for program. 
*/

	program define dirtshfc_err_rates
	
		syntax,
		DIRECTory(string)
		DATAset(string)
		HFCFile(string)
		BCFile(string)
	
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
		
		
		
	}
	
end




