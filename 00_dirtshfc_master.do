/*******************************************************************************
# Title		: HIGH FREQUENCY CHECKS
# Projects	: DIRTS
# Purpose	: Run High Frequency Checks for DIRTS Annual Survey 2017. Outputs are 
#				logged in .xlsx and smcl formats and disaggregated by teams
# Authors	: Ishmail Azindoo Baako (iabaako@poverty-action.org)
#				Survey Coordinator, IPA-Ghana	
#			  Vincent Armentano (varmentano@poverty-action.org)
#				Research Analyst, IPA - NH			
# Date		: February, 2017
********************************************************************************
SETTING THE STAGE
*******************************************************************************/
* set rmsg on

qui {
	clear all							// Clear all 
	cls									// Clear Results
	vers 			13					// Set to Stata version 13
	set 	maxvar	32000, perm			// Allow up to 32,000 vars
	set 	matsize 11000, perm			// Set Matsize
	set		more 	off					// Set more off
	loc		hfcdate	"27_feb_17"			// Set date of interest (format: dd_mm_yy)

	* Set the neccesary directories

	gl main "../08_HFC"								// Main Folder
	gl logs "$main/01_hfc_logs/02_field_pilot/02"	// Log Folder
	gl csv "$main/02_scto_csv/02_field_pilot/02"	// SCTO csv folder
	gl dta "$main/03_scto_dta/02_field_pilot/02"	// SCTO dta folder
}

/*******************************************************************************
INSTALL HFC ADO FILE
*******************************************************************************/	

/*
qui {
	cap net install dirtshfc, all replace from(https://raw.githubusercontent.com/iabaako/dirtshfc/master)
	if _rc == 631 {
		noi di in red "You do not have internet connectivity, skipping check for updates"
	}
	
	else {
		noi di "Checked for updates"
	}
}
*/

net install dirtshfc, all replace force from("D:/Box Sync/GitHub/dirtshfc")

/*******************************************************************************
IMPORT DATASET
*******************************************************************************/
/*
qui {
	noi di "Importing Data ..."
	foreach r in r1d1 r1d2 r2 {
		do "$dta/`r'/import_dirts_annual_`r'.do"
		gl ur "`r'"
		do "$main/00_reserve/01_code/reshape_and_merge_field_pilot.do"
	}
}
*/
/*******************************************************************************
PREPARE DATASET FOR HFC
*******************************************************************************/

foreach r in r1d1 r1d2 r2 {
	#d;
	dirtshfc_prep using "$dta/`r'/dirts_annual_2017_fpv_`r'_wide.dta", 
		enumv(researcher_id researcher_name) 															
		enumd("$main/dirtshfc_2017_inputs.xlsx") 													
		sav("$dta/`r'/dirts_annual_2017_fpv_`r'_preped")	
		rty("`r'")
		;
	#d cr
}	
stop_prep
/*******************************************************************************
MAKE CORRECTIONS TO DATA
*******************************************************************************/

foreach r in r1d1 r1d2 r2 {
	#d;
	dirtshfc_correct fprimary using "$dta/dirts_annual_2017_fpv_`r'_preped.dta", 
		enumv(enum_id enum_name) 															
		corrf("$main/dirtshfc_2017_inputs.xlsx")
		logf("$logs/`hfcdate'/corrections_log_`r'_`hfcdate'")
		sav("$dta/`r'/dirts_annual_2017_fpv_`r'_post_correction")
		rty("`r'")
		;
	#d cr
}
stop_correct
/*******************************************************************************
RUN HFCs
*******************************************************************************/

foreach r in r1d1 r1d2 r2 {
	loc rnv = substr("`r'", 1, 2)
	#d;
	dirtshfc_run fprimary using "$dta/dirts_annual_2017_fpv_`r'_post_correction.dta", 
		date("`hfcdate'")
		ssdate("10_FEB_17")
		sedate("28_FEB_17")
		enumv(enum_id enum_name)
		enumd("$main/dirtshfc_2017_inputs.xlsx")
		dispv(district community `rnv'_name)
		logf("$logs")
		sav("$dta/`r'/dirts_annual_2017_fpv_`r'_post_hfc")
		rtype("`r'")
		;
	#d cr
}

stop_run
/*******************************************************************************
RUN BACK CHECK ANALYSES
*******************************************************************************/



/*******************************************************************************
CALCULATE HFC AND BC ERROR RATES
*******************************************************************************/




/*******************************************************************************
RENAME AUDIO FILES
*******************************************************************************/
// Use remedia to rename files
//

/*******************************************************************************
CLEAN DATASET
*******************************************************************************/
if "`c(username)'" == "Vinny" {
	// enter code for cleaning data
}

/*******************************************************************************
BACK-UP DATA
*******************************************************************************/
if "`c(username)'" != "Vinny" {
	* Back Up Data
}
