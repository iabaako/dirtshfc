*! version 0.0.0 Ishmail Azindoo Baako (IPA) Jan, 2016

/* 
	This stata program is part of the HFC for the DIRTS Annual Survey 2017. 
	
	This will run Checks on data that is saved from dirtshfc_run.ado

	Define sytax for program. 
	varname		: ID variable for survey
	using		: .dta file saved from dirtshfc_run
	bcsheet		: sheet name of back check errors
	weightsheet	: xlsx sheet containing the weights of errors
	enumvars	: Enumerator variables. The enumerator id and then enumerator name
					variables are espected here. eg. enumv(enum_id enum_name)
	bcervars	: Back Checker variable. The Bcers id and bcers name vars are
					espected. eg (bcer_id bcer_name
	logfile		: Name for saving data after hfc is run

*/	

	prog def dirtshfc_err_rates
	
		syntax varname using/,
		BCSheet(string)
		WEIGHTSHeet(string)
		ENUMVars(varname min=2 max=2)
		BCERVars(varname min=2 max=2)
		LOGFile(string)
	
	qui {	
		
		/***********************************************************************
		Set the stage
		***********************************************************************/
		* Check that the directory specified as is encrypted with Boxcryptor
		loc pathx = substr("`directory'", 1, 1)
		if `pathx' != "X" & `pathx' != "." {
			noi di as err "dirtshfc_err_rates: Hello!! Using Data must be in a BOXCRYPTED folder"
			exit 601
		}
		
		* Get the enumerator related vars from arg enumvars
		token `enumvars'
		loc enum_id "`1'"				// Enumerator ID
		loc enum_name "`2'"				// Enumerator Name
		
		* Get the back check related vars from arg enumvars
		token `bcervars'
		loc bcer_id "`1'"				// Back Checker ID
		loc bcer_name "`2'"				// Back Checker Name
	
		* Represent the id var with the local id
		loc id `varlist'
		
		/***********************************************************************
		Calculate HFC Error Rates
		***********************************************************************/

		
		
		/***********************************************************************
		Calculate BC Error Rates
		***********************************************************************/

		
	}
	
end




