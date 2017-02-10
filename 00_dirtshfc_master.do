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

cls									// Clear Results
vers 			13					// Set to Stata version 13
set 	maxvar	20000				// Allow up to 20,000 vars
set		more 	off					// Set more off
loc		hfcdate	"24_Jan_17"			// Set date of interest (format: dd_mm_yy)

/*******************************************************************************
INSTALL HFC ADO FILE
*******************************************************************************/	

set r on
cap net install dirtshfc, all replace from(https://raw.githubusercontent.com/iabaako/dirtshfc/master)
if _rc == 631 {
	di in red "You do not have internet connectivity"
}

/*******************************************************************************
RUN SCTO IMPORT DO-FILES
*******************************************************************************/

do ""
do ""

/*******************************************************************************
PREPARE DATASET FOR HFC
*******************************************************************************/

dirtshfc_prep,
		direct("../03_scto_dta") 									///
		data("")													///
		enumd("")													///
		sav("")														///
		bcd("")														///
		bcs("")			

/*******************************************************************************
MAKE CORRECTIONS TO DATA
*******************************************************************************/




/*******************************************************************************
RUN HFCs
*******************************************************************************/




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
if c(username) == "Vinny" {
	// enter code for cleaning data
}

/*******************************************************************************
BACK-UP DATA
*******************************************************************************/
if c(username) != "Vinny" {
	* Back Up Data
}
