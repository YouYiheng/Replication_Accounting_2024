cd "DIRECTORY"

**# Start here and create country-code dataset
use cl_dset_fortests_Apr22, clear

*Merge in uniqueness
merge m:1 cl_newname using cosine_sim_iasbcls
drop if _m==2
drop _m

* Variables that I want at the country-constituent type level: N, avg length
* Variables I want at the country level: avg length and all the constituent level stuff
foreach var in academ aud_bn aud_sm consult gov ind law nfp org prep regulator standardset user {
	egen clwordcount_`var'_country = mean(clwordcount) if type=="`var'", by(ed cl_country)
}
egen NCLs_country = count(clw_id), by(ed cl_country)

** Counts of CLs from different constituencies
foreach var in academ aud_bn aud_sm consult gov ind law nfp org prep regulator standardset user {
	egen NCLs_country_`var' = count(clw_id) if type=="`var'", by(ed cl_country)
}
egen clwordcount_country = mean(clwordcount), by(ed cl_country)

* collapse, using averages, to the country-ED level
collapse (mean) ed_year clwordcount NCLs_country NCLs_country_academ NCLs_country_aud_bn NCLs_country_aud_sm NCLs_country_consult NCLs_country_gov NCLs_country_ind NCLs_country_law NCLs_country_nfp NCLs_country_org NCLs_country_prep NCLs_country_regulator NCLs_country_standardset NCLs_country_user clwordcount_country , by(ed cl_country)

foreach var in academ aud_bn aud_sm consult gov ind law nfp org prep regulator standardset user {
	replace NCLs_country_`var' = 0 if missing(NCLs_country_`var')
}

*merge in ifrs adoption status and country code
merge m:1 cl_country ed_year using ifrs_adoption_status
drop if _m==2
drop _m

*merge in linguistic distance
merge m:1 cl_country using ling_dist_2021_11
drop if _m==2
drop _m

* toefl and culture distance
merge m:1 cl_country using country_static_measures
drop if _m==2
drop _m

*merge in gdp
merge m:1 cl_country_code ed_year using gdp
drop if _m==2
drop _m

*create an interpolated / extrapolated gdp for missing years
sort cl_country ed_year
bysort cl_country: ipolate gdp ed_year, gen(interp_gdp) epolate
*create an interpolated / extrapolated population 
sort cl_country ed_year
bysort cl_country: ipolate population ed_year, gen(interp_pop) epolate

replace ln_countcompfirms = 0 if missing(ln_countcompfirms)
g ln_pop = log(population)
g lninterp_pop = ln(interp_pop)
g lninterp_gdp = ln(interp_gdp)

*merge in governance
merge m:1 cl_country_code ed_year using governance
drop if _m==2 
drop _m

* inter/extrapolate governance index
sort cl_country ed_year 
bysort cl_country: ipolate govindex ed_year, gen(interp_govindex) epolate

*merge in donations
merge m:1 cl_country ed_year using donations_dset
drop if _m==2
drop _m
replace donations = 0 if missing(donations) & ed_year>2006
replace donation_dummy = 0 if missing(donation_dummy)
g ln_donations = ln(donations + 1)

*merge in ED variables
merge m:1 ed using projects_Oct2021
drop if _m==2
drop _m
* Create staff ally variable
g staff_ally = 0
replace staff_ally = 1 if cl_country==proj_mgr1_nat | cl_country==proj_mgr2_nat | cl_country==proj_mgr3_nat | cl_country==proj_mgr4_nat | cl_country==proj_mgr5_nat
drop proj_mgr? proj_mgr?_nat

*merge in board member data 
joinby ed using bms
sort ed cl_country member

g board_allies = 0
replace board_allies = 1 if cl_country==bm_country
* now collapse back to ed-country
collapse (first) cl_country_code languages lang1 lang2 lang3 lang4 language associated_final_std (mean) ed_year clwordcount NCLs_country NCLs_country_academ NCLs_country_aud_bn NCLs_country_aud_sm NCLs_country_consult NCLs_country_gov NCLs_country_ind NCLs_country_law NCLs_country_nfp NCLs_country_org NCLs_country_prep NCLs_country_regulator NCLs_country_standardset NCLs_country_user clwordcount_country lfi lfi_dec_full wgt_avg_lfi gdp lngdp countcompfirms ln_countcompfirms govindex ed_date cl_deadline nlanguages english french japanese spanish failed n_cls staff_ally jointwithfasb aligntofasb ln_pop ln_donations donations donation_dummy culdist_uk_new toefl_2016_new interp_gdp interp_govindex lninterp_gdp lninterp_pop (sum) board_allies, by(ed cl_country)

*merge in IFRS fulladoption indicator
merge m:1 cl_country_code using ifrs_adopt
drop if _m==2
drop _m
* ifrs adoption variable
g adopted_ifrs_full = 0
replace adopted_ifrs_full = 1 if fulladoption<=ed_year
rename fulladoption fulladoptionyear

* merge in more IFRS dates
merge m:1 cl_country_code ed_year using ifrs_adoption_status
drop if _m==2
drop _m
rename prohibited ifrs_prohibited

* IFRS status variables for use in testing
rename fulladoption_indicator fulladoption_ifrs_yearlevel
g partial_ifrs_yearlevel = 0
replace partial_ifrs_yearlevel = 1 if voladoption_indicator == 1 | reqforsome_indicator == 1 | conv_proj_indicator == 1
g ifrs_partialorfull_yearlevel = 0
replace ifrs_partialorfull_yearlevel = 1 if fulladoption_ifrs_yearlevel == 1 | partial_ifrs_yearlevel == 1

* Merge in TOEFL Scores
merge m:1 cl_country using toefl_2016
drop if _m==2
drop _m
qui sum toefl_2016
replace toefl_2016 = `r(max)' if cl_country=="united states"

*Merge in culture scores
merge m:1 cl_country using culture
drop if _m==2
drop _m

*Merge in former UK colonies data
merge m:1 cl_country using uk_colonies
drop if _m==2
drop _m
replace former_british_colony = 0 if missing(former_british_colony)

*Merge in google translate dataset
merge m:1 lang1 using goog_translate
drop _m
g goog_trans_avail = 0 if ed_year>=2008
replace goog_trans_avail = 1 if ed_year>= goog_translate_adopt_yr
g goog_trans_avail_b = 0
replace goog_trans_avail_b = 1 if ed_year>=goog_translate_adopt_yr_beta

* variables for testing
g commented_country = 0
replace commented_country = 1 if NCLs_country>0 & !missing(NCLs_country)
* commented_country for each constituency
foreach var in academ aud_bn aud_sm consult gov ind law nfp org prep regulator standardset user {
	g commented_country_`var' = 0
	replace commented_country_`var' = 1 if NCLs_country_`var'>0 & !missing(NCLs_country_`var')
}
g board_ally = 0
replace board_ally = 1 if board_allies>0

g translation_ed = 0
replace translation_ed = 1 if lang1=="english" | (french==1 & lang1=="french") | (japanese==1 & lang1=="japanese") | (spanish==1 & lang1=="spanish") 

*high linguistic distance indicator
g far_from_eng = 0
qui sum lfi, d
replace far_from_eng = 1 if lfi>`r(p50)'
g far_from_eng_wal = 0 //barrier defined with the weighted average LFI value
qui sum wgt_avg_lfi, d
replace far_from_eng_wal = 1 if wgt_avg_lfi>`r(p50)'

* numerical variable for EDs to do FEs
egen ed_n = group(ed)
egen cl_country_n = group(cl_country)

* "Missing" indicator variables for fluency and culture
g missing_toefl = 0
replace missing_toefl = 1 if missing(toefl_2016)
g toefl_2016_Z = 0
replace toefl_2016_Z = toefl_2016 if !missing(toefl_2016)
g missing_culdist = 0
replace missing_culdist = 1 if missing(culdist_uk)
qui sum culdist_uk
g culdist_uk_Z = r(mean)
replace culdist_uk_Z = culdist_uk if !missing(culdist_uk)

*create variable for missing governance index
g missing_govindex = 0
replace missing_govindex = 1 if missing(govindex)
qui sum govindex
g govindex_Z = r(mean)
replace govindex_Z = govindex if !missing(govindex)

g lnNCLs_country = ln(NCLs_country)
replace lnNCLs_country = 0 if NCLs_country==0

rename nlanguages nlanguages_ed

*** Number of official languages
* count languages by cl_country
g nlanguages_ctry = 4 if !missing(lang4)
replace nlanguages_ctry = 3 if !missing(lang3) & missing(nlanguages_ctry)
replace nlanguages_ctry = 2 if !missing(lang2) & missing(nlanguages_ctry)
replace nlanguages_ctry = 1 if missing(nlanguages_ctry)

g lfi_s = lfi / nlanguages_ctry

g timetrend = ed_year-2004
drop if ed_year<2007

g ln_nlanguages_ctry = ln(nlanguages_ctry)
* drop effective date EDs
drop if ed=="ED_2015_2_Revenue_Effective_Date" | ed=="ED_2015_7_Eff_Date" | ed=="ED_2020_3_Classification_Liabilities_EffDate"

* merge in whether they commented at all
merge 1:1 cl_country ed_year ed using tar_r1_sample
drop if _m==2
drop _m
replace commented_ever = 0 if missing(commented_ever)
egen commented_ever2 = mean(commented_ever), by(cl_country)
replace commented_ever2 = 1 if commented_ever2>0

* drop countries missing full gdp data
drop if cl_country == "reunion" | cl_country == "gibraltar" | cl_country == "dutch antilles" | cl_country == "taiwan" | cl_country == "british virgin islands" | cl_country == "montserrat" | cl_country =="anguilla"

**# Analyses for Tables 1 through 3

save ifrs_lang_dset_20240116, replace

