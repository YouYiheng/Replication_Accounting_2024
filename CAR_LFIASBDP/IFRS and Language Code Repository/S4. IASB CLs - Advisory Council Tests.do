cd "DIRECTORY"

** IFRS Advisory Council data, descriptives, and regression tests
** First I'm getting data on the countries' languages, lfi, and far_from_eng
use ifrs_lang_dset_20240116, clear

g countervar = ed_year * commented_country if commented_country==1
egen first_comment_country = min(countervar), by(cl_country)

keep cl_country cl_country_code lang1 lfi far_from_eng NCLs_country first_comment_country

collapse lfi far_from_eng NCLs_country first_comment_country (first) lang1 cl_country_code, by(cl_country)
save country_language, replace

** Now I want to identify, for each  constituent, the first time there was a comment letter
use ifrs_cls_dset_220240223, clear
egen first_comment_clw = min(ed_year), by(clw_id)
collapse first_comment_clw lfi, by(clw_id)
rename lfi lfi_clw
save clw_first, replace

* Import hand-collected data on IFRS advisory council members
import excel using "SUBDIRECTORY\AC_Members_10_03_24 _ CLW_ID.xlsx", clear sheet(All) firstrow
keep Date Member clw_id cl_country_clw_id cl_country_search type_coded sub_type_coded
rename Date ed_year
keep if ed_year>=2007 & !missing(ed_year)
destring clw_id, replace force
format clw_id %11.0g
rename cl_country_search cl_country

merge m:1 cl_country using country_language
drop if _m==2
drop _m

merge m:1 clw_id using clw_first
drop if _m==2
replace first_comment_clw = 2006 if _m==1 & !missing(clw_id) // there are some writers for which we have a CL that came in before our sample starts
drop _m

sort ed_year clw_id

* create an indicator variable for whether the council member ever wrote a comment letter prior to being on the council
g previously_commented = 0
replace previously_commented = 1 if first_comment_clw<=ed_year & !missing(first_comment_clw)
* Create an indicator variable for whether the council member subsequently wrote a comment letter after being named to the council
g later_commented = 0
replace later_commented = 1 if first_comment_clw>ed_year & !missing(first_comment_clw)
* create an indicator variable for whether the council member ever commented
g ever_commented = 0
replace ever_commented = 1 if !missing(first_comment_clw)

**** Now repeat the above but at the country level
g previously_commented_country = 0
replace previously_commented_country = 1 if first_comment_country<=ed_year & !missing(first_comment_country)
* Create an indicator variable for whether the council member subsequently wrote a comment letter after being named to the council
g later_commented_country = 0
replace later_commented_country = 1 if first_comment_country>ed_year & !missing(first_comment_country)
* create an indicator variable for whether the council member ever commented
g ever_commented_country = 0
replace ever_commented_country = 1 if !missing(first_comment_country)

g unique_countries_byyear = 0
g unique_languages_byyear = 0
forvalues i = 2007(1)2022 {
	egen tag`i' = tag(cl_country) if ed_year==`i'
	replace unique_countries_byyear = unique_countries_byyear + tag`i'
	drop tag`i'
	
	egen tag`i' = tag(lang1) if ed_year==`i'
	replace unique_languages_byyear = unique_languages_byyear + tag`i'
	drop tag`i'	
}

save ifrs_advisory_council, replace

** Determinants of being on the advisory council--at the country-ED level 
use ifrs_advisory_council, clear
keep ed_year clw_id cl_country lfi first_comment_country
rename ed_year council_year
keep if !missing(clw_id)
sort cl_country clw_id council_year
duplicates drop clw_id council_year, force
save ifrs_advisory_council2, replace

use ifrs_lang_dset_20240116, clear
collapse far_from_eng lfi board_ally staff_ally fulladoption_ifrs_yearlevel ln_donations lninterp_gdp lninterp_pop ln_countcompfirms former_british_colony govindex_Z missing_govindex toefl_2016_Z missing_toefl culdist_uk_Z missing_culdist commented_ever ifrs_partialorfull_yearlevel, by(cl_country ed_year)

sort cl_country ed_year
joinby cl_country using ifrs_advisory_council2, unmatched(master)
g future_council_member = 0
replace future_council_member = 1 if !missing(council_year) & _m==3 & ed_year <= council_year
g council_member_ever = 0
replace council_member_ever = 1 if !missing(council_year)
drop _m
duplicates drop cl_country ed_year, force

keep if ed_year>2008

**# Analyses for Table 9, Panels A and B


**# Determinants of being on the advisory council--at the CL level
use ifrs_advisory_council, clear
keep ed_year clw_id cl_country lfi first_comment_clw
rename ed_year council_year
keep if !missing(clw_id)
duplicates drop clw_id council_year, force
save ifrs_advisory_council3, replace

use ifrs_cls_dset_220240223, clear

joinby clw_id using ifrs_advisory_council3, unmatched(master)
g future_council_member = 0
replace future_council_member = 1 if !missing(council_year) & _m==3 & ed_year <= council_year
g council_member_ever = 0
replace council_member_ever = 1 if !missing(council_year)
drop _m
duplicates drop cl_newname, force


local dv future_council_member
local ind_var1 far_from_eng
local ind_var2 lfi
local controls w_ln_clwordcount w_grammarly_score rankr_unique_ed_med board_ally staff_ally fulladoption_ifrs_yearlevel ln_donations lngdp ln_pop ln_countcompfirms govindex former_british_colony toefl_2016_Z missing_toefl culdist_uk_Z missing_culdist translation_ed

keep if ed_year>2008

**# Analyses for Table 9C
