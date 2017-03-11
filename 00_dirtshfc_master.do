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

qui {
	clear all							// Clear all 
	cls									// Clear Results
	vers 			13					// Set to Stata version 13
	set 	maxvar	32000, perm			// Allow up to 20,000 vars
	set 	matsize 11000, perm			// Set Matsize
	set		more 	off					// Set more off
	loc		hfcdate	"27_feb_17"			// Set date of interest (format: dd_mm_yy)

	* Set the neccesary directories

	loc main "../08_HFC"
	loc logs "`main'/01_hfc_logs/01_bench_test"
	loc csv "`main'/02_scto_csv/01_bench_test/02"	// SCTO csv folder
	loc dta "`main'/03_scto_dta/01_bench_test/02"	// SCTO dta folder
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
/*
/*******************************************************************************
IMPORT DATASET
*******************************************************************************/

qui {
	noi di "Importing Data ..."
	forval r = 1/1 {
		do "`dta'/r`r'/import_dirts_annual_r`r'_wip.do"
		do "`main'/00_reserve/01_code/r`r'_reshape_and_merge_bench_test.do"
	}
}

/*******************************************************************************
PREPARE DATASET FOR HFC
*******************************************************************************/

qui {
	noi di "Preparing Data for HFCs ... "
	forval r = 1/1 {
		#d;
		dirtshfc_prep using "`dta'/r`r'/DIRTS Annual R`r' WIP_WIDE.dta", 
			enumv(enum_id enum_name) 															
			enumd("`main'/dirtshfc_2017_inputs.xlsx") 													
			sav("`dta'/r`r'/dirts_annual_2017_r`r'_preped")	
			type("r1")
			;
		#d cr
	}	
}

/*******************************************************************************
MAKE CORRECTIONS TO DATA
*******************************************************************************/
*/

forval r = 1/1 {
	#d;
	dirtshfc_correct fprimary using "`dta'/r`r'/dirts_annual_2017_r`r'_preped.dta", 
		enumv(enum_id enum_name) 															
		corrf("`main'/dirtshfc_2017_inputs.xlsx")
		logf("`logs'/`hfcdate'/corrections_log_r`r'_`hfcdate'")
		sav("`dta'/r`r'/dirts_annual_2017_r`r'_post_correction")
		;
	#d cr
}

/*******************************************************************************
RUN HFCs
*******************************************************************************/

forval r = 1/1 {
	#d;
	dirtshfc_run fprimary using "`dta'/r`r'/dirts_annual_2017_r`r'_post_correction.dta", 
		date("`hfcdate'")
		ssdate("10_FEB_17")
		sedate("28_FEB_17")
		enumv(enum_id enum_name)
		enumd("`main'/dirtshfc_2017_inputs.xlsx")
		dispv(district community r`r'_name)
		logf("`logs'")
		sav("`dta'/dirts_annual_2017_r`r'_post_hfc")
		type("r`r'")
		;
	#d cr
}

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
