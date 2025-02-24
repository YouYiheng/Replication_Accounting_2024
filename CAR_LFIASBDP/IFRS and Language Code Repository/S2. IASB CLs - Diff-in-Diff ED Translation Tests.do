cd "DIRECTORY"

use ifrs_lang_dset_20240116, clear
keep if commented_ever==1
*** Now moving on to some DiD for individual languages
*** var_f --> french       var_j --> japanese       var_s --> spanish
* FRENCH - first ED with French translation was in September, 2007
g post_f = 0
replace post_f = 1 if year(ed_date)>2007 | year(ed_date)==2007 & month(ed_date)>=9
g treat_f = 0
replace treat_f = 1 if lang1=="french"
* controls defined as english
g treat_f2 = 0 if lang1=="english"
replace treat_f2 = 1 if lang1=="french"
* controls defined as all languages except English
g treat_f3 = 0 if lang1!="english"
replace treat_f3 = 1 if lang1=="french"

* JAPANESE - first ED with Japanese translation was in May of 2009
g post_j = 0
replace post_j = 1 if year(ed_date)>2009 | year(ed_date)==2009 & month(ed_date)>=5
g treat_j = 0
replace treat_j = 1 if lang1=="japanese"
* controls defined as english and french
g treat_j2 = 0 if lang1=="english" | lang1=="french"
replace treat_j2 = 1 if lang1=="japanese"
* controls defined as all languages except English and French
g treat_j3 = 0 if lang1!="english" & lang1!="french"
replace treat_j3 = 1 if lang1=="japanese"

* SPANISH - first ED with Spanish translation was in October 2013
g post_s = 0
replace post_s = 1 if year(ed_date)>2013 | year(ed_date)==2013 & month(ed_date)>=10
g treat_s = 0
replace treat_s = 1 if lang1=="spanish"
* controls defined as english and french and Japanese
g treat_s2 = 0 if lang1=="english" | lang1=="french" | lang1=="japanese"
replace treat_s2 = 1 if lang1=="spanish"
* controls defined as all languages except English, French, and Japanese
g treat_s3 = 0 if lang1!="english" & lang1!="french" & lang1!="japanese"
replace treat_s3 = 1 if lang1=="spanish"

save allvars_4_DiD, replace


local diffyears = 3

use allvars_4_DiD, clear
keep if !missing(treat_f2)
* Now I'll create a window to only include EDs issued in the two years pre- and post-French ED
keep if (year(ed_date)>(2007-`diffyears') | year(ed_date)==(2007-`diffyears') & month(ed_date)>=9) & (year(ed_date)<(2007+`diffyears'+1) | year(ed_date)==(2007+`diffyears'+1) & month(ed_date)<9)
g treat = treat_f2
g post = 0
replace post = 1 if post_f==1
g did_group = 1
save french, replace

use allvars_4_DiD, clear
keep if !missing(treat_j2)
* Now I'll create a window to only include EDs issued in the two years pre- and post-Japanese ED
keep if (year(ed_date)>(2009-`diffyears') | year(ed_date)==(2009-`diffyears') & month(ed_date)>=5) & (year(ed_date)<(2009+`diffyears'+1) | year(ed_date)==(2009+`diffyears'+1) & month(ed_date)<5)
g treat = treat_j2
g post = 0
replace post = 1 if post_j==1
g did_group = 2
save japanese, replace


use allvars_4_DiD, clear
keep if !missing(treat_s2)
* Now I'll create a window to only include EDs issued in the two years pre- and post-Spanish ED
keep if (year(ed_date)>(2013-`diffyears') | year(ed_date)==2009 & month(ed_date)>=10) & (year(ed_date)<(2013+`diffyears'+1) | year(ed_date)==(2013+`diffyears'+1) & month(ed_date)<10)
g treat = treat_s2
g post = 0
replace post = 1 if post_s==1
g did_group = 3
save spanish, replace


append using french
append using japanese

egen group_ed = group(ed_n did_group)
egen group_country = group(cl_country_n did_group)


**# Analyses for Table 4