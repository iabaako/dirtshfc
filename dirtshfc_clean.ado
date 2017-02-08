*! version 0.0.0 Vincent Armentano (IPA) Jan, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will run Checks on data that is saved from dirtshfc_run.ado

	Define sytax for program. 
	varname		: ID variable for survey
	using		: .dta file saved from dirtshfc_correct
	enumvars	: Enumerator variables. The enumerator id and then enumerator name
					variables are espected here. eg. enumv(enum_id enum_name)
	saving		: Name for saving data after hfc is run

*/	

	prog def dirtshfc_clean
	
		syntax varname using/,
		ENUMVars(varlist min=2 max=2)
		SAVing(string)

	qui {	
		
		/***********************************************************************
		Set the stage
		***********************************************************************/
		* Check that the directory specified as is encrypted with Boxcryptor
		loc pathx = substr("`directory'", 1, 1)
		if `pathx' != "X" & `pathx' != "." {
			noi di as err "dirtshfc_clean: Hello!! Folder specified with directory must be BOXCRYPTED"
			exit 601
		}
		
		* Get the enumerator related vars from arg enumvars
		token `enumvars'
		loc enum_id "`1'"				// Enumerator ID
		loc enum_name "`2'"				// Enumerator Name
		
		* Represent the id var with the local id
		loc id `varlist'
		
		/***********************************************************************
		Import Dataset
		***********************************************************************/
		* Import dataset
		cap confirm file "`using'"
		if !_rc {
			use "`using'", clear
		}
			
		* Throw an error if file does not exist
		else {	
			noi di as err "dirtshfc_clean: File `dataset' not found"
			exit 601
		}
		
		/***********************************************************************
		Clean Dataset
		***********************************************************************/
		* drop unneeded variables
		#d;
			drop 
				*_ok
				*_sf
				*_hf
				;
		#d cr
		
		* Write cleaning code here
		
		
}
	
	
end


