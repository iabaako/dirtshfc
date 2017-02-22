* This adopted do-file will reshape and merge in repeat groups for r1 survey. 
* This do-file was modified to handle single nested repeat groups only

********************************************************************************
*set directory of all the repeat group datasets
global importdata "../08_HFC/03_scto_dta/01_bench_test/02/r1"

* Set the directory for the xls version of the questionaire
loc survey "../08_HFC/00_reserve/04_questionnaire/DIRTS Annual Survey R1 WIP"
loc surveyname "DIRTS Annual R1 WIP"

* Check through the questionnaire and list the names of repeat groups
import excel "`survey'.xlsx", sh("survey") case(l) first clear 
keep type name label
keep if regexm(type, "repeat")
gen nest = type[_n] == type[_n - 1]
keep if type == "begin repeat"
* Get the nested repeat groups
levelsof name if nest, loc(n_rpts) clean
loc n_rpts: list uniq n_rpts

* Get non-nested repeat groups 
levelsof name if !nest, loc (rpts) clean
loc rpts: list uniq rpts

* Put the list together listing nested first
loc all_rpts: list n_rpts | rpts
noi di "`all_rpts'"

*  Check in folder for repeat groups


loc sname = lower("`surveyname'")
loc loop ""
foreach r in `all_rpts' {
	loc name: dir "$importdata" files "*`r'.dta"
	if !mi(`"`name'"') {
		loc name = subinstr(`name', ".dta", "", .)
		loc name = subinstr("`name'", "`sname'-", "", 1)
		loc loop "`loop' `name'"
	}
}

********************************************************************************

*open and save main dataset with new name
local surveyname = "\" + "`surveyname'"
di "`surveyname'"
use "$importdata`surveyname'", clear
*This will be the name of hte final wide dataset
save "$importdata`surveyname'_WIDE", replace 

*save each of the repeated groups as tempfiles
local i = 1
foreach lp in $loop {
	use "$importdata/`surveyname'-`lp'", clear
	tempfile temp`i'
	save "`temp`i''", replace
	local i = `i'+1
}

*runs through each repeated group and see if it is nested.
*To do this it finds the setof... variable name, and then looks in
*all the other datasets for this variable.
local i = 1
foreach lp in $loop {
	loc lp = "`surveyname'" + "-" + "`lp'"
	local name = "\" + "`lp'"
	local namerev = reverse("`name'")
	local pos = strpos("`namerev'", "-")
	local setof`i' = lower(substr("`name'", 1-`pos', .))
	local j=1
	foreach lp2 in $loop {
		loc lp2 = "`surveyname'" + "-" + "`lp2'"
		if "`lp2'"=="`lp'" {
			local j = `j'+1
		}
		else if "`lp2'"!="`lp'" {
			use "`temp`j''", clear
			cap des setof`setof`i'', varlist
			if !_rc & "setof`setof`i''"=="`r(varlist)'" {
				local lp`i'isin=`j'
			}		
			local j= `j'+1
		}	
	}
	local i=`i'+1
}


*display which groups are nested
local i = 1
foreach lp in $loop {
	di "repeat group `setof`i'' is nested in repeat group: `setof`lp`i'isin''"
	local i = `i' +1
} 


*loop though each repeated group, reshape it and then merge it into
*the main dataset (if it is not nested) or the repeated group is sits in
*(if it is nested).
local i = 1
foreach lp in $loop {
	use "`temp`i''", clear
	by parent_key, s : gen num = _n
	drop key setof`set_of`i''
	rename parent_key key
	
	ds key num, not 
	loc rsvars `r(varlist)'

	
	
	* Varnames may be too long and may not feasible as locs. Changing the code to accomodate that
	loc cnt: word count `rsvars'
	forval v = 1/`cnt' {
		loc rsvar`v': word `v' of `rsvars'
		ren `rsvar`v'' `rsvar`v''_
		loc rsvar`v'_l: var label `rsvar`v''_
	}
	
	/*
	*rename and variable labels
	foreach var in `r(varlist)' {
		rename `var' `var'_
		local l`var'_ : variable label `var'_
	}
	*/
	
	*reshape the dataset into wide form
	ds key num, not 	
	reshape wide `r(varlist)', i(key) j(num)
	
	*assign variable labels back to the wide dataset
	forval v = 1/`cnt' {
		unab vl_name: `rsvar`v''*
		foreach var in `vl_name' {
			if !mi("`rsvar`v'_l'") {
				label var `var' "`rsvar`v'_l'"
			}
		}
	}
	
	/*
	*assign variable labels back to the wide dataset
	ds key, not 
	global lpvars `r(varlist)'
	foreach var in $lpvars {
		local newlabel : variable label `var'
		local newlabel2 = strpos("`newlabel'", " ")
		local newlabel3 = substr("`newlabel'",`newlabel2'+1, .)
		label var `var' "`l`newlabel3''" 
	}
	*/
	
	
	*save the wide form of the repeat group.
	save "`temp`i''", replace
	
	*If the repeat group is not nested, then we merge into the main dataset.
	if  "`lp`i'isin'"=="" {
		di "Loop `i' is not nested"
		use "$importdata`surveyname'_WIDE", clear
		merge 1:1 key using "`temp`i''"
		drop _merge
		* order $lpvars, a(setof`setof`i'')
		drop setof`setof`i''
		save "$importdata`surveyname'_WIDE", replace
	}
	
	*If the repeat group is nested, then we merge into the repeat group it sits in.
	else if  "`lp`i'isin'"!="" {
		di "Loop `i' is nested"
		use "`temp`lp`i'isin''", clear
		cap drop _merge
		merge m:1 key using "`temp`i''"
		drop _merge
		* order $lpvars, a(setof`setof`i'')
		drop setof`setof`i''
		*here we replace the temp file of the higher repeat group
		save "`temp`lp`i'isin''", replace
	}
	local i = `i'+1
}

save "$importdata`surveyname'_WIDE", replace
