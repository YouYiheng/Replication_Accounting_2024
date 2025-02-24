* IFRS and Language Project Dataset Formation Code
* This code is used to compile the data used in the project. 

cd "DIRECTORY"

* linguistic distance
*bring in linguistic distance (LFI) data from Joshi and Lahiri
import excel using "SUBDIRECTORY\LANGUAGE INDEX 1213.xlsx", sheet(One score per language) clear firstrow case(lower)
drop language_d
replace language = "guarani" if language=="Guaran??"
g lang1 = lower(language)
destring lfi, replace force
sum lfi if features>5, d // only use languages with greater than five features for decile measure
egen lfi_dec_full = xtile(lfi) if features>5, nq(10)
save lfi, replace

* format language data for merging LFI 
import excel "SUBDIRECTORY\IFRS Country Master.xlsx", firstrow case(lower) clear
keep cl_country language lfi
sort cl_country
replace language = lower(language)
split language, parse(", ") gen(v)
rename v1 lang1
rename v2 lang2
rename v3 lang3
rename v4 lang4
rename language languages
rename lfi lfi_new

* conform languages 
replace lang1 = "belorussian" if lang1=="belarusian"
replace lang1 = "mandarin" if lang1=="chinese"
replace lang1 = "mandarin" if lang1=="mandarin chinese"
replace lang1 = "luxemburgeois" if lang1=="luxembourgish"
replace lang1 = "serbian-croatian" if lang1=="croatian"
replace lang1 = "guarani" if lang1=="paraguayan guaraní"
replace lang1 = "persian" if lang1=="farsi"
replace lang1 = "kirghiz" if lang1=="kyrgyz"
replace lang1 = "tetun" if lang1=="tetun prasa"
replace lang1 = "greenlandic" if lang1=="kalaallisut"
replace lang1 = "guarani" if cl_country=="paraguay"

*merge in lfi
merge m:1 lang1 using lfi
drop if _m==2
drop _m
sort lang2
replace lang2 = "tagalog" if lang2=="filipino"
replace lang2 = "tok pisin" if lang2=="tok-pisin"
replace lang2 = "berber" if lang2=="tamazight"
replace lang2 = "serbian-croatian" if lang2=="croatian"
replace lang3 = "serbian-croatian" if lang3=="serbian"
save lingdist_temp, replace // save temporarily

*add in LFI for other languages to get a weighted average LDistance
		use lfi, clear
		drop language
		rename features features2
		rename lfi_dec_full lfi_dec_full2
		rename lfi lfi2
		rename lang1 lang2
		sort lang2
		save lfi, replace

		use lingdist_temp, clear
		merge m:1 lang2 using lfi
		drop if _m==2
		drop _m
		save lingdist_temp, replace

		use lfi, clear
		rename features2 features3
		rename lfi_dec_full2 lfi_dec_full3
		rename lfi2 lfi3
		rename lang2 lang3
		sort lang3
		save lfi, replace

		use lingdist_temp, clear
		merge m:1 lang3 using lfi
		drop if _m==2
		drop _m
		save lingdist_temp, replace

		use lfi, clear
		rename features3 features4
		rename lfi_dec_full3 lfi_dec_full4
		rename lfi3 lfi4
		rename lang3 lang4
		sort lang4
		save lfi, replace

		use lingdist_temp, clear
		merge m:1 lang4 using lfi
		drop if _m==2
		drop _m features2 features3 features4 lfi_dec_full2 lfi_dec_full3 lfi_dec_full4

* Form weighted average LFI
g wgt_avg_lfi = lfi if missing(lfi2*lfi3*lfi4)
replace wgt_avg_lfi = ((lfi+lfi2)/2) if missing(lfi3*lfi4) & !missing(lfi*lfi2)
replace wgt_avg_lfi = ((lfi+lfi2+lfi3)/3) if missing(lfi4) & !missing(lfi*lfi2*lfi3)
replace wgt_avg_lfi = ((lfi+lfi2+lfi3+lfi4)/4) if !missing(lfi*lfi2*lfi3*lfi4)

drop lfi2 lfi3 lfi4
		
sort cl_country
duplicates drop cl_country, force
save ling_dist_2021_11, replace


* gdp and population
* Bring in GDP data downloaded from the IMF
import excel "SUBDIRECTORY\GDPFull.xls", firstrow case(lower) clear
drop countryname indicatorname
rename countrycode cl_country_code
reshape long gdp, i(cl_country_code) j(ed_year)
g lngdp = ln(gdp)
sort cl_country_code ed_year
save gdp, replace

		
		**** count of public firms per year per country downloaded from compustat global
		use compu_glbl_allfirms, clear // compu_glbl_allfirms is a downloaded dataset from Compustat Global of all gvkey-fyear combinations with a conm and iso country code (loc)
		drop datadate conm fic
		destring gvkey, replace
		sort loc fyear
		collapse (count) countcompfirms=gvkey, by(loc fyear)
		g ln_countcompfirms = log(countcompfirms)
		rename loc cl_country_code
		rename fyear ed_year
		save compu_glbl_count, replace

		***Bring in population data downloaded from world bank
		import delimited using "SUBDIRECTORY\Population_WorldBank.csv", varnames(1) clear
		* rename each year variable
		foreach v of varlist v5-v66 {
		   local x : variable label `v'
		   rename `v' yr`x'
		}
		drop countryname indicatorname indicatorcode yr1960-yr2003
		reshape long yr, i(countrycode) j(year)
		rename (yr countrycode year) (population cl_country_code ed_year)
		format population %12.0g
		save population_worldbank, replace

use gdp, clear

merge m:m cl_country_code ed_year using compu_glbl_count
drop if _m==2
drop _m
replace countcompfirms = 0 if missing(countcompfirms)
replace ln_countcompfirms = 0 if missing(ln_countcompfirms)

merge 1:1 cl_country_code ed_year using population_worldbank
drop if _m==2
drop _m
save gdp, replace

* TOEFL
*Bring in TOEFL 2016 scores, downloaded from Educational Testing Service website
import delimited "SUBDIRECTORY\TOEFL_2016.csv", clear varnames(1)
drop v*
destring s*, replace force
destring toefl_total, replace force
rename toefl_total toefl_2016
drop country
bysort cl_country: drop if _N!=1
save toefl_2016, replace

* Culture
* Bring in culture scores downloaded from Geert Hofstede's website
import delimited "SUBDIRECTORY\Culture_Hofstede.csv", clear varnames(1)
keep cl_country n_dimensions culdist_uk
destring culdist_uk, replace force
replace culdist_uk = 0 if cl_country=="united kingdom"
replace culdist_uk = . if n_dimensions < 4
sort cl_country
save culture, replace

* British colonies
*bring in former British colonies dataset, collected from CIA's World Factbook: https://www.cia.gov/the-world-factbook/field/independence/
import excel "SUBDIRECTORY\UK Colonies.xlsx", firstrow case(lower) clear
keep cl_country
g former_british_colony = 1
sort cl_country
save uk_colonies, replace

* IFRS adoption
*bring in IFRS adoption dataset that originated on Deloitte's IASPlus.net
import excel "SUBDIRECTORY\Copy of Adoption year Revised 6.7.2021.xlsx", sheet(Sheet1 (2)) firstrow case(lower) clear
drop if country=="Country"
replace country = lower(country)
drop if missing(country)
drop if missing(a3un)
rename a3un cl_country_code
rename country cl_country
keep cl_country cl_country_code fulladoption

* normalize text import issues
replace fulladoption = "2007" if fulladoption=="2007?"
replace fulladoption = "2008" if fulladoption=="2008?"
replace fulladoption = "2007" if fulladoption=="2005/2007"
replace fulladoption = "." if fulladoption=="1998/2010"
replace fulladoption = "1993" if fulladoption=="1993/2000"
replace fulladoption = "2022" if fulladoption=="2022/2023"
replace fulladoption = "2003" if fulladoption=="2015/2003"

destring fulladoption, replace force

sort cl_country
save ifrs_adopt, replace

* governance
*Bring in governance data from the World Bank's Worldwide Governance Indicators project
use "SUBDIRECTORY\Governance.dta", clear
rename year ed_year
rename ctry_code cl_country_code
drop country
* standardize country codes prior to upcoming merge
replace cl_country_code = "COD" if cl_country_code ==  "COG"
replace cl_country_code = "PSE" if cl_country_code ==  "WGB"
replace cl_country_code = "ROU" if cl_country_code ==  "ROM"
replace cl_country_code = "TLS" if cl_country_code ==  "TMP"
*form governance index from pca
pca vae pve gee rqe rle cce
predict govindex
save governance, replace

* ED variables
*Bring in ED variables, hand collected from the IASB website
import excel "SUBDIRECTORY\IASB Project Master", sheet(Sheet1) firstrow case(lower) clear
drop folder_ref cl_url
foreach var in ed_date cl_deadline {
	format `var' %td
}
g ed_year = year(ed_date)
destring jointwithfasb, replace force
destring aligntofasb, replace force
sort ed ed_year
save projects_Oct2021, replace

* Board members
*Board member nationality variables, collected from IASB member biographies on the IASB website, LinkedIn, and other publicly available sources
import excel "SUBDIRECTORY\IASB Project Master Board Members", sheet(Board Member Countries) firstrow case(lower) clear
replace country = lower(country)
save bm_countries, replace
import excel "SUBDIRECTORY\IASB Project Master Board Members", sheet(Standards) firstrow case(lower) clear
drop folder_ref cl_url
format ed_date %td
g ed_year = year(ed_date)
merge m:1 member using bm_countries
drop if _m==2 
drop _m
sort ed ed_year
rename country bm_country
save bms, replace

* Google translate
* Google translate data, based on language-level adoptions of Google Translate Beta; collected using the Internet Archive Wayback Machine
import delimited "SUBDIRECTORY\Google Translate Adoption Year by Language.csv", clear varnames(1)
sort lang1
save goog_translate, replace

* Donations
* Bring in "All_Countries" donations data collected from the IASB annual reports and based on additional data collected through conversations with IASB staff
import excel using "SUBDIRECTORY\Funding_Providers_IFRS_Foundation_28_08_22_bm-updatednames.xlsx", sheet(All_Countries2) clear firstrow case(lower)
g donation_dummy = 0
replace donation_dummy = 1 if donations>0
rename year ed_year
save donations_dset, replace

* Grammarly performance scores, hand collected by running each comment letter through Grammarly's scoring system
import excel using "SUBDIRECTORY\Grammarly Scores 2022-10-7.xlsx", sheet(Grammarly Scores 2022-10-7) clear firstrow case(lower)
keep filename finalscore correctness clarity
	foreach var in finalscore correctness clarity {
		destring `var', replace force
	}
sort filename
g raw_filename = substr(filename,1,20)
collapse (mean) finalscore (sum) correctness clarity, by(raw_filename)
	foreach var in correctness clarity {
		replace `var' = . if `var'==0
	}
g cl_newname = (raw_filename + ".txt")
drop raw_filename 
sort cl_newname
rename finalscore grammarly_score
rename correctness gramm_correctness
rename clarity gramm_clarity
save grammarly, replace

*** Uniqueness via cosine similarity, measured in R
import delimited using "SUBDIRECTORY\IASB CL Cosine_Sim BY ED 2023-02-08.csv", clear varnames(1)
destring med_cosine_sim, replace force
replace med_cosine_sim = (1-med_cosine_sim)
rename med_cosine_sim unique_ed_med
keep cl_newname unique_ed_med
save cosine_sim_ed, replace

* Now cosine similarity by ED-Constituent Type
import delimited using "SUBDIRECTORY\IASB CL Cosine_Sim BY ED-Type 2023-02-09.csv", clear varnames(1)
destring med_cosine_sim, replace force
replace med_cosine_sim = (1-med_cosine_sim)
rename med_cosine_sim unique_ed_t_med
keep cl_newname unique_ed_t_med
save cosine_sim_ed_t, replace

* Now cosine similarity by comment letter writer
import delimited using "SUBDIRECTORY\IASB CL Cosine_Sim BY CLW_ID 2023-02-08.csv", clear varnames(1)
destring med_cosine_sim, replace force
replace med_cosine_sim = (1-med_cosine_sim)
rename med_cosine_sim unique_clw_med
keep cl_newname unique_clw_med
save cosine_sim_clw, replace

use cosine_sim_ed, clear
merge 1:1 cl_newname using cosine_sim_ed_t
drop _m

merge 1:1 cl_newname using cosine_sim_clw
drop _m

save cosine_sim_iasbcls, replace
erase cosine_sim_clw.dta 
erase cosine_sim_ed.dta 
erase cosine_sim_ed_t.dta 

* CL dataset formation
*bring in hand-collected CL data
import delimited using "SUBDIRECTORY\IASB CLs with LM Characteristics - FULL.csv", clear
destring clw_id, replace force
format clw_id %11.0g
destring clwordcount, replace force
drop if clwordcount <50 | missing(clwordcount)
 *Format dates
foreach var in ed_date cl_deadline {
	split `var', g(part) p("/")
	drop `var'
	destring part1, replace force
	destring part2, replace force
	destring part3, replace force
	g `var' = mdy(part1, part2, part3)
	format `var' %td
	drop part1 part2 part3
}

** Merge languages in
merge m:1 cl_country using ling_dist_2021_10
drop if _m==2
drop _m

* define some variables
g ln_clwordcount = ln(clwordcount)
g ed_year = year(ed_date)

* Merge grammarly scores in 
merge m:1 cl_newname using grammarly
drop if _m==2
drop _m

save cl_dset_fortests_Apr22, replace

* IFRS adoption details
* Create blank dataset of years from 1994 through 2023
clear
set obs 29
g year = 1994 + _n - 1
save year_dataset2, replace
*Bring in country master data
import excel "SUBDIRECTORY\IFRS Country Master.xlsx", firstrow case(lower) clear
keep cl_country a3un fulladoption aconvergenceproject bvoluntaryadoption crequiredforsome prohibited
rename a3un cl_country_code
replace prohibited = "0" if missing(prohibited)
replace prohibited = "1" if prohibited=="x"
foreach var in fulladoption aconvergenceproject bvoluntaryadoption crequiredforsome prohibited {
	destring `var', replace
}
cross using year_dataset2

* Indicator for full adoption
gen fulladoption_indicator = (year >= fulladoption) if fulladoption != .
* Indicator for voluntary adoption 
gen voladoption_indicator = (year >= bvoluntaryadoption) if bvoluntaryadoption != .
* Indicator for convergence project underway
gen conv_proj_indicator = (year >= aconvergenceproject) if aconvergenceproject != .
* Indicator for required for some
gen reqforsome_indicator = (year >= crequiredforsome) if crequiredforsome != .

* replace with some zeroes
foreach var in fulladoption_indicator voladoption_indicator conv_proj_indicator reqforsome_indicator {
	replace `var' = 0 if missing(`var')
}
rename year ed_year
drop fulladoption aconvergenceproject bvoluntaryadoption crequiredforsome

* Indicator for whether the country ever adopted IFRS
egen everfulladoption = mean(fulladoption_indicator), by(cl_country_code)
egen evervoladoption = mean(voladoption_indicator), by(cl_country_code)
replace everfulladoption = 1 if everfulladoption > 0
replace evervoladoption  = 1 if evervoladoption  > 0

duplicates drop cl_country ed_year, force
sort cl_country ed_year

save ifrs_adoption_status, replace

* Cultural distance, and toefl scores
*Bring in country master data
import excel "SUBDIRECTORY\IFRS Country Master.xlsx", firstrow case(lower) clear
keep cl_country culdist_uk toefl 
rename (culdist_uk toefl) (culdist_uk_new toefl_2016_new)
duplicates drop cl_country, force

save country_static_measures, replace

* All countries all years
*Bring in country master data
import excel "SUBDIRECTORY\IFRS Country Master.xlsx", firstrow case(lower) clear
keep cl_country a3un
rename a3un cl_country_code
save all_countries, replace

clear
set obs 20
gen year = 2002
replace year = year + _n
save year_dataset, replace

use all_countries, clear
cross using year_dataset
rename year ed_year
save all_countries, replace