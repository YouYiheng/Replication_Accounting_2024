cd "DIRECTORY"

**# Bookmark #1
use cl_dset_fortests_Apr22, clear

*merge in gdp
merge m:1 cl_country_code ed_year using gdp
drop if _m==2 
drop _m
replace ln_countcompfirms = 0 if missing(ln_countcompfirms)
g ln_pop = log(population) 

*merge in governance
merge m:1 cl_country_code ed_year using governance
drop if _m==2 
drop _m

*merge in donations
merge m:1 cl_country ed_year using donations_dset
drop if _m==2
drop _m
replace donation_dummy = 0 if missing(donation_dummy)
g ln_donations = ln(donations + 1)

*merge in ED variables
merge m:1 ed using projects_Oct2021
drop if _m==2
drop _m
* Create staff ally variable
g staff_ally = 0
replace staff_ally = 1 if cl_country==proj_mgr1_nat | cl_country==proj_mgr2_nat | cl_country==proj_mgr3_nat | cl_country==proj_mgr4_nat | cl_country==proj_mgr5_nat

*merge in board member data 
joinby ed using bms
sort ed cl_country member

g board_allies = 0
replace board_allies = 1 if cl_country==bm_country
* now collapse back to comment letter
collapse (first) clw_id ed cl_country cl_country_code lang1 lang2 lang3 lang4 language commenter type quoted_by_staff referenced_by_staff (mean) ed_year clwordcount ln_clwordcount grammarly_score lfi lfi_dec_full wgt_avg_lfi gdp lngdp ln_pop countcompfirms ln_countcompfirms govindex ln_donations donation_dummy ed_date cl_deadline nlanguages english french japanese spanish n_cls staff_ally (sum) board_allies, by(cl_newname)

*merge in IFRS adoption years
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
g ifrs_allowed_or_req_yearlevel = 0
replace ifrs_allowed_or_req_yearlevel = 1 if fulladoption_ifrs_yearlevel == 1 | voladoption_indicator == 1 | reqforsome_indicator == 1

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
drop if _m==2
drop _m
g goog_trans_avail = 0 if ed_year>=2008
replace goog_trans_avail = 1 if ed_year>= goog_translate_adopt_yr
g goog_trans_avail_b = 0
replace goog_trans_avail_b = 1 if ed_year>=goog_translate_adopt_yr_beta

*Merge in uniqueness
merge 1:1 cl_newname using cosine_sim_iasbcls
drop if _m==2
drop _m

* normalize cosine similarity measures
g clwordcount2 = clwordcount ^ 2
g clwordcount3 = clwordcount ^ 3
foreach var in unique_ed_med {
	g I`var' = 1 - `var'
	reg `var' clwordcount clwordcount2 clwordcount3
	predict `var'_resid, resid
	egen rankr_`var' = xtile(`var'_resid), nq(10) by(ed)
	replace rankr_`var' = rankr_`var'/10
}

drop if ed_year>2020
* drop effective date EDs
drop if ed=="ED_2015_2_Revenue_Effective_Date" | ed=="ED_2015_7_Eff_Date" | ed=="ED_2020_3_Classification_Liabilities_EffDate"

rename nlanguages nlanguages_ed

* variables for testing
g board_ally = 0
replace board_ally = 1 if board_allies>0

g translation_ed = 0
replace translation_ed = 1 if lang1=="english" | (french==1 & lang1=="french") | (japanese==1 & lang1=="japanese") | (spanish==1 & lang1=="spanish") 

*high linguistic distance indicator
g far_from_eng = 0
qui sum lfi, d
replace far_from_eng = 1 if lfi>`r(p50)'
g far_from_eng_full = 0
replace far_from_eng_full = 1 if lfi_dec_full >= 6
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
g culdist_uk_Z = 0
replace culdist_uk_Z = culdist_uk if !missing(culdist_uk)

* count languages by cl_country
g nlanguages_ctry = 4 if !missing(lang4)
replace nlanguages_ctry = 3 if !missing(lang3) & missing(nlanguages_ctry)
replace nlanguages_ctry = 2 if !missing(lang2) & missing(nlanguages_ctry)
replace nlanguages_ctry = 1 if missing(nlanguages_ctry)

foreach var in clwordcount ln_clwordcount grammarly_score {
	winsor `var', gen(w_`var') p(0.01)
}
replace type = "ind" if missing(type)
* Create dummies for each constituent type
foreach var in academ aud_bn aud_sm consult gov ind law nfp org prep regulator standardset user {
	g i_`var' = 0
	replace i_`var' = 1 if type=="`var'"
}

egen ncls_country = count(clw_id), by(cl_country)

g i_other = i_consult + i_gov + i_ind + i_law + i_nfp + i_regulator
egen type2 = group(type)
replace referenced_by_staff = 1 if referenced_by_staff==0 & quoted_by_staff==1

drop if missing(ln_donations)

* Ranked variables
egen rank_grammarly = rank(w_grammarly_score)
replace rank_grammarly = rank_grammarly/_N
egen rank_grammarly_type = rank(w_grammarly_score), by(type)
bysort type: replace rank_grammarly_type = rank_grammarly_type/_N

keep if !missing(quoted_by_staff*lfi*far_from_eng*rankr_unique_ed_med*w_grammarly_score*govindex)

*** Descriptives Table-Panel A is summary stats and B is Pearson correlations
local desc_vars quoted_by_staff w_grammarly_score rankr_unique_ed_med lfi far_from_eng w_ln_clwordcount board_ally staff_ally fulladoption_ifrs_yearlevel ln_donations lngdp ln_pop ln_countcompfirms govindex former_british_colony toefl_2016 culdist_uk translation_ed

**# Analyses for Tables 5 through 8