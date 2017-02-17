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

clear all							// Clear all 
cls									// Clear Results
vers 			13					// Set to Stata version 13
set 	maxvar	32000				// Allow up to 20,000 vars
set		more 	off					// Set more off
loc		hfcdate	"13_feb_17"			// Set date of interest (format: dd_mm_yy)

* Set the neccesary directories

loc main "../08_HFC"
loc logs "`main'/01_hfc_logs/02_field_pilot/01"
loc csv "`main'/02_scto_csv/02_field_pilot/01"	// SCTO csv folder
loc dta "`main'/03_scto_dta/02_field_pilot/01"	// SCTO dta folder

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

* Run SCTO auto generated do-files
qui {
/*
	noi di "Importing Data ..."
	do "`dta'/import_dirts_annual_survey_2017_full_WIPv2.do"
	noi di 
	noi di "Reshaping and merging in repeat groups ..."

	* Run do-file to reshape
	do "`main'/00_reserve/01_code/reshape_and_merge_field_pilot.do"
	noi di
	noi di "Hurray!! Data imported succesfully"
*/
}

/******
* Create Temp fix for enum_id and enum_name vars
use "`dta'/dirts_annual_survey_2017v2_WIDE.dta"
gen audio_consent = 1
gen enum = 11 in 1/3
replace enum = 12 in 4/5
gen surveyor = ""
replace surveyor = "Mohammed Abdul Manan" if enum == 11
replace surveyor = "Seidu Ahmed" if enum == 12
save "`dta'/dirts_annual_survey_2017v2_WIDE_2", replace
******/

/*******************************************************************************
PREPARE DATASET FOR HFC
*******************************************************************************/
use "`dta'/dirts_annual_survey_2017v2_WIDE_2.dta"


#d;
dirtshfc_prep using "`dta'/dirts_annual_survey_2017v2_WIDE_2.dta", 
	enumv(enum surveyor) 															
	enumd("`main'/dirtshfc_2017_inputs.xlsx") 													
	sav("`dta'/dirts_annual_2017_preped")	
	type("r1")
	;
#d cr

/*******************************************************************************
MAKE CORRECTIONS TO DATA
*******************************************************************************/

#d;
dirtshfc_correct fprimary using "`dta'/dirts_annual_2017_preped.dta", 
	enumv(enum surveyor) 															
	corrf("`main'/dirtshfc_2017_inputs.xlsx")
	logf("`logs'/corrections_log_`hfcdate'")
	sav("`dta'/dirts_annual_2017_post_correction")
	;
#d cr

/*******************************************************************************
RUN HFCs
*******************************************************************************/

#d;
dirtshfc_run fprimary using "`dta'/dirts_annual_2017_post_correction.dta", 
	date("`hfcdate'")
	ssdate("10_FEB_17")
	sedate("28_FEB_17")
	enumv(enum surveyor)
	enumd("`main'/dirtshfc_2017_inputs.xlsx")
	dispv(district community r1_name r2_name)
	logf("`logs'")
	sav("`dta'/dirts_annual_2017_post_hfc")
	type("r1")
	;
#d cr

stop_all
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
