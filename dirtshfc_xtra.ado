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
	prog def dirtshfc_xtra
		#d;
			syntax name,
			INPUTSheet(string)
			ENUMVars(namelist min=2 max=2)
			BCERVars(namelist min=2 max=2)
			LOGFile(string)
			;
		#d cr

	qui {	
		
		/***********************************************************************
		Set the stage
		***********************************************************************/
		
		* Get the enumerator related vars from arg enumvars
		token `enumvars'
		loc enum_id "`1'"				// Enumerator ID
		loc enum_name "`2'"				// Enumerator Name
		
		* Get the back check related vars from arg enumvars
		loc bcer_id 	"bcer_id"				// Back Checker ID
		loc bcer_name 	"bcer_name"				// Back Checker Name
	
		* Represent the id var with the local id
		loc id `namelist'
				
		* Import, clean and make datasets
		
		tempfile R1BC1 R1BC2 R2BC main mainr2 clean1 clean2 clean_all
		foreach data in R1BC1 R1BC2 R2BC {
			use "$bc/DIRTS Annual 2017 `data'.dta", clear
			gen bctype = "`data'"
			
			token `bcervars'
			ren(`1' `2') (bcer_id bcer_name)
			
			save ``data''
		}
		
		* Start Log
		cap log close
		log using "`logfile'/bc_log", replace text
		
		* Append datasets
		
		use "`R1BC1'", clear
			append using "`R1BC2'"
			
		#d;
			keep 
				fprimary
				bcer_id
				bctype
				resp_confirm
				respondent_agree
				a_staff_visit
				bc_memb_conf_rp*
				memb_inhh_rp*
				bc_not_memb_reason_rp*
				memb_1name_rp*
				memb_2name_rp*
				memb_pop_rp*
				memb_sex_rp*
				memb_age_rp*
				memb_rel_hhh_rp*
				memb_first_lan_rp*
				b_new_*
				c_*
				e_*
				h_*
				r1_plot_*
				acres_cultivated
				w_*
			;
		#d cr
		save `main'

		* Import r2bc 2 dataset and mark vars with r2b_
		use "`R2BC'", clear
		replace bctype = "R1BC1" if bc_type1_type2 == 1
		replace bctype = "R1BC2" if bc_type1_type2 == 2
		drop bc_type1_type2
		
		#d; 
			keep 
				bcer_*
				fprimary 
				bc_plot_conf_rp*
				h_plot_soil_desc_sm_rp*
				h_plot_soil_des_osp_rp*
				h_plot_acres_cult_rp*
				acres_cultivated*
				bctype
				respondent_agree
			;
		#d cr
		
		ren (*) (r2b_*)
		ren (r2b_fprimary r2b_bctype) (fprimary bctype)
		save `R2BC', replace
		
		use "`main'", clear
			merge 1:1 fprimary bctype using "`R2BC'", nogen
		save "$bc/dirts_bc_data_preped.dta", replace
		
		* Import and prepare main dataset for bc
		use "$dta/r1d2/dirts_annual_2017_r1d2_post_hfc.dta", clear
		* Remove duplicates
		duplicates tag fprimary, gen (dup0) 
		keep if !dup0
		gen rtype = "R1D2"
		save `clean1'
		
		use "$dta/r1d1/dirts_annual_2017_r1d1_post_hfc.dta", clear
		* Remove duplicates
		duplicates tag fprimary, gen (dup1) 
		keep if !dup1
		gen rtype = "R1D1"
	
		merge 1:1 fprimary using "`clean1'", nogen
		
		#d;
			keep 
				researcher*
				fprimary
				resp_confirm
				respondent_agree
				memb_inhh_rp*
				memb_1name_rp*
				memb_2name_rp*
				memb_pop_rp*
				memb_sex_rp*
				memb_age_rp*
				memb_rel_hhh_rp*
				memb_first_lan_rp*
				b_new_*
				c_*
				e_*
				h_*
				r1_plot_*
				acres_cultivated
				w_*
				rtype
			;
		#d cr
		save "$bc/dirts_annual_bc_ready.dta", replace
		
		* Append r2 data
		use "$dta/r2/dirts_annual_2017_r2_post_hfc.dta", clear
		
		* Remove duplicates
		duplicates tag fprimary, gen (dup2) 
		keep if !dup2

		#d; 
			keep 
				researcher*
				fprimary 
				h_plot_soil_desc_sm_rp*
				h_plot_soil_des_osp_rp*
				h_plot_acres_cult_rp*
				acres_cultivated*
				respondent_agree
			;
		#d cr
		
		ren (*) (r2b_*)
		ren (r2b_fprimary) (fprimary)
		save `mainr2'
		
		
		use "$bc/dirts_annual_bc_ready.dta", clear
			merge 1:1 fprimary using "`mainr2'"
			
			
		save "$bc/dirts_annual_bc_ready.dta", replace
		
		
		log close
	}
	
end




