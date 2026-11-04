* Replace this directory with local directory to the "Master Folder"
*For windows usesrs, make sure to replace "\" with "/"
local path "C:/Users/..."
local path "C:/Users/nimen/Documents/USU/My Research/My Code Sample"
pause off

*--------------------------------------------------
* DATA QUALITY AUDIT: INITIALIZATION
*--------------------------------------------------

clear all
*set more off

local date_now = subinstr("`c(current_date)'", " ", "_", .)
local time_now = subinstr("`c(current_time)'", ":", ".", .)

capture log close _all
log using "`path'/Logs/log_`date_now'_`time_now'.log", ///
    text replace

display "Stata version: `c(stata_version)'"


*======================================
*======================================
**# BLS 
*======================================
*======================================
{	
	
*======================================
**# MERGING EACH YEAR
*======================================

*initializing variables
local tot_obs_cnt = 0
local iter = 0

{
foreach foldername in 2018 2019 2020 2021 2022 2023 2024 2025 2026{
cd "`path'/Raw_Data/BLS/4_Digit_NAICS_Codes/`foldername'"

local files : dir "." files "*.csv"

* Create an empty dataset to start
clear
tempfile master`foldername'
save "`master`foldername''", emptyok


foreach file of local files {
    di "Processing `file'..."
    import delimited "`file'", clear varnames(1) stringcols(_all)
    cap drop lq* oty*
		
	*Keep only values aggrergated to county level agregations with a spesified county
	keep if substr(agglvl_code,1,1) == "7"
	drop if substr(area_fips,3,3)=="999"
	*There are two counties with the word "City" in the county name
	drop if strpos(area_title, "City") > 0 & area_fips !="51036" & area_fips != "51095"
	
	*Limit sample to continental United States, and drop connecticut
	drop if substr(area_fips,1,2)=="02"
	drop if substr(area_fips,1,2)=="09"
	drop if substr(area_fips,1,2)=="15"
	drop if substr(area_fips,1,2)=="72"
	drop if substr(area_fips,1,2)=="78"
	
	drop own_code agglvl_code size_code disclosure_code size_title agglvl_title
	
	drop if industry_code == ""
		
	*quality check measures
	isid area_fips qtr own_title
	local tot_obs_cnt = `tot_obs_cnt' + _N
	assert c(k) == 15
	assert !missing(area_fips)
	
    append using "`master`foldername''"
    save "`master`foldername''", replace
	
	
	
	
	*Record for which data is missing by county
	import delimited "`file'", clear varnames(1) stringcols(_all)
    cap drop lq* oty*
		
	*Keep only values aggrergated to county, as "County, by Supersector -- by ownership sector"
	keep if substr(agglvl_code,1,1) == "7"
	drop if substr(area_fips,3,3)=="999"
	drop if strpos(area_title, "City") > 0 & area_fips !="51036" & area_fips != "51095"
	
	*Limit sample to continental United States, and drop connecticut
	drop if substr(area_fips,1,2)=="02"
	drop if substr(area_fips,1,2)=="09"
	drop if substr(area_fips,1,2)=="15"
	drop if substr(area_fips,1,2)=="72"
	drop if substr(area_fips,1,2)=="78"
	
	drop if industry_code == ""
	keep area_fips industry_code 
		
	if `iter' == 0 {
		merge m:1 area_fips using "`path'/Raw_Data/BLS/fipslist.dta"
		gen missing_count = 0
		replace missing_count = 1 if _merge == 2
		keep area_fips name missing_count
		collapse (sum) missing_count (first) name, by(area_fips)
		local iter = `iter' + 1
		save "`path'/Raw_Data/BLS/missing_bls.dta", replace 
	}
	else {
		merge m:1 area_fips using "`path'/Raw_Data/BLS/fipslist.dta"
		rename _merge  current_missing
		keep area_fips current_missing
		replace current_missing = 0 if current_missing == 3 | current_missing == 1
		replace current_missing = 1 if current_missing == 2
		collapse (sum) current_missing, by(area_fips) 
		merge 1:1 area_fips using "`path'/Raw_Data/BLS/missing_bls.dta"
		replace missing_count = missing_count + current_missing
		keep area_fips name missing_count
		save "`path'/Raw_Data/BLS/missing_bls.dta", replace 
	}
	
use "`master`foldername''", clear	
}

* Cleans all the data with various renaming
rename area_fips FIPS
label variable FIPS "unique identifier specifying state and county"
rename industry_code NAICS
label variable NAICS "unique identifier specifying inustry sector"
label variable NAICS "unique identifier specifying industry sector" 
label variable year "year"
label variable qtr "quarter"
rename industry_title industry
label variable industry "industry code and title"
rename area_title county
label variable county "county or region name"
rename own_title own
label variable own "private or government ownership"

rename qtrly_estabs_count firm_count
rename firm_count firms
label variable firms "number of firms"
rename total_qtrly_wages total_wages
label variable total_wages "total quarterly wages"

save "`master`foldername''", replace

*save "`path'/`foldername'/`foldername'_merged.dta", replace
*save "`path'\`foldername'\`foldername'_merged.dta", replace
* Repeat these steps for every year of data (2018 - 2025)
}


use "`master2018'", clear
foreach i in 2019 2020 2021 2022 2023 2024 2025 2026 {
	append using "`master`i''"
}


* Destring numeric variables using post-rename names (FIPS stays string to preserve leading zeros)
destring NAICS year qtr firms total_wages ///
    month1_emplvl month2_emplvl month3_emplvl ///
    taxable_qtrly_wages qtrly_contributions avg_wkly_wage, ///
    replace force

*CHECK - Observation count matched	
	
* Save as permanent Stata file
save "`path'/Raw_Data/BLS/merged_data_4digit.dta", replace
}


*======================================
**# GENERATE OVERALL BLS EMPLOYMENT DATASET
*======================================

u "`path'/Raw_Data/BLS/merged_data_4digit.dta", clear

{

* this dataset contains different levels of employment, private, public etc
* before creating variables, we need to collapse the dataset to be at the FIPS, NAICs, year quarter level
* we're going to look at total employment now 


g empl_quarterly=month3_emplvl
collapse (sum) empl_quarterly firms total_wages taxable_qtrly_wages qtrly_contributions (mean) avg_wkly_wage , by(FIPS NAICS year qtr)

* drop all counties/industries that report zero employment in all years, they won't be used for identificaiton anyway 
bysort FIPS NAICS: egen maxempl_quarterly=max(empl_quarterly)
drop if maxempl_quarterly==0
drop maxempl_quarterly

* labeling

label variable taxable_qtrly_wages "taxable quarterly wages"
label variable qtrly_contributions "quarterly tax contributions"
label variable avg_wkly_wage "average individual weekly wage"
label variable firms "number of firms"
label variable total_wages "total wages"


* Create a new treated variable that shows if the NAICS code is a treated industry

gen treat = 0

replace treat = 1 if ///
NAICS==2111 | NAICS==2122 | NAICS==2123 | NAICS==2131 | ///
NAICS==2211 | NAICS==2213 | NAICS==2361 | NAICS==2362 | NAICS==2371 | NAICS==2382 | ///
NAICS==3112 | NAICS==3241 | NAICS==3251 | NAICS==3272 | NAICS==3273 | ///
NAICS==3311 | NAICS==3313 | NAICS==3314 | NAICS==3334 | NAICS==3336 | ///
NAICS==3344 | NAICS==3353 | NAICS==3359 | NAICS==3361 | NAICS==3363 | ///
NAICS==4861 | NAICS==4862 | NAICS==4869 | ///
NAICS==5413 | NAICS==5416 | NAICS==5417 | NAICS==5622

label variable treat "Dummy = 1 if NAICS industry affected by IRA 2022"

order treat, after(NAICS)


* this code generates exposure variables in 2022 (we do not use 2018) 
* there are two options here; calculate hsare in 2022 and then take that share to all other counties as an average 
* option 2 is calculate sum in 2022 for all and treated and then max of those for each county and then share (thsi would create weights depending on the size of the county...)

foreach var of varlist firms empl_quarterly total_wages {
bysort FIPS  : egen `var'sumtemp=sum(`var') if year==2022
bysort FIPS  : egen `var'trtemp=sum(`var') if treat==1 & year==2022
bysort FIPS  : egen `var'tr=max(`var'trtemp) if year==2022

g share`var'temp=`var'tr/`var'sumtemp	
bysort FIPS  : egen share`var'=mean(share`var'temp)

}



foreach var of varlist sharefirms shareempl_quarterly sharetotal_wages {
	su `var', d
g high`var'=`var'>`r(p50)'
g tq`var'=`var'>`r(p75)'
g bq`var'=`var'<`r(p25)'
}

drop *temp

sort FIPS year qtr
order FIPS  year qtr

gen quarterly = yq(year, qtr)
format quarterly %tq

cap drop post
g post=(quarterly>yq(2022, 4))


 * growth rates 
 
 egen fipsc=group(FIPS)
 egen fipscind=group(FIPS NAICS)

 xtset fipscind quarterly
 
 * quarterly growth rates
 rename avg_wkly_wage weekly_wage
 foreach var of varlist firms total_wages empl_quarterly weekly_wage {
g	gr`var'=(`var'-l.`var')/l.`var'
}

* growth rates relative to 2022 relevant quarter benchmark
foreach var of varlist firms total_wages empl_quarterly weekly_wage {
g `var'2022q1=`var' if year==2022	& qtr==1
g `var'2022q2=`var' if year==2022	& qtr==2
g `var'2022q3=`var' if year==2022	& qtr==3
g `var'2022q4=`var' if year==2022	& qtr==4

bysort FIPS NAICS: egen mean`var'2022q1=mean(`var'2022q1)
bysort FIPS NAICS: egen mean`var'2022q2=mean(`var'2022q2)
bysort FIPS NAICS: egen mean`var'2022q3=mean(`var'2022q3)
bysort FIPS NAICS: egen mean`var'2022q4=mean(`var'2022q4)

g	gr`var'2022=(`var'-mean`var'2022q1)/mean`var'2022q1 if qtr==1
replace gr`var'2022=(`var'-mean`var'2022q2)/mean`var'2022q2 if qtr==2
replace gr`var'2022=(`var'-mean`var'2022q3)/mean`var'2022q3 if qtr==3
replace gr`var'2022=(`var'-mean`var'2022q4)/mean`var'2022q4 if qtr==4
drop mean`var'2022* `var'2022*
}
 
* growth rates relative to 2018 relevant quarter benchmark
 foreach var of varlist firms total_wages empl_quarterly weekly_wage {
g `var'2018q1=`var' if year==2018	& qtr==1
g `var'2018q2=`var' if year==2018	& qtr==2
g `var'2018q3=`var' if year==2018	& qtr==3
g `var'2018q4=`var' if year==2018	& qtr==4

bysort FIPS NAICS: egen mean`var'2018q1=mean(`var'2018q1)
bysort FIPS NAICS: egen mean`var'2018q2=mean(`var'2018q2)
bysort FIPS NAICS: egen mean`var'2018q3=mean(`var'2018q3)
bysort FIPS NAICS: egen mean`var'2018q4=mean(`var'2018q4)

g	gr`var'2018=(`var'-mean`var'2018q1)/mean`var'2018q1 if qtr==1
replace gr`var'2018=(`var'-mean`var'2018q2)/mean`var'2018q2 if qtr==2
replace gr`var'2018=(`var'-mean`var'2018q3)/mean`var'2018q3 if qtr==3
replace gr`var'2018=(`var'-mean`var'2018q4)/mean`var'2018q4 if qtr==4
drop mean`var'2018* `var'2018*
}
 
 rename grempl_quarterly2022 grempl2022

* the main variable is winsorized at 1% but then we also winsorzie at 5%
* when we winsorize matters relative to dropping observations (dropping the county naics cells with zero employment in at least 1 of the years is restrictive)

 winsor2  grfirms grtotal_wages grempl_quarterly grweekly_wage grfirms2022 grtotal_wages2022 grempl2022 grweekly_wage2022 grfirms2018 grtotal_wages2018 grempl_quarterly2018 grweekly_wage2018, cut(5, 95)

 
 winsor2  grfirms grtotal_wages grempl_quarterly grweekly_wage grfirms2022 grtotal_wages2022 grempl2022 grweekly_wage2022 grfirms2018 grtotal_wages2018 grempl_quarterly2018 grweekly_wage2018, cut(1, 99) replace

g state=substr(FIPS,1,2)
destring state, replace


* Converts values into strings and concatenates them.

gen FIPSQTRYR = FIPS + string(qtr) + string(year)

sort FIPSQTRYR

}


save "`path'/Raw_Data/BLS/countyindustrylevel.dta", replace

*======================================
**# GENERATE PRIVATE BLS EMPLOYMENT DATASET
*======================================


u "`path'/Raw_Data/BLS/merged_data_4digit.dta", clear

{

* this dataset contains different levels of employment, private, public etc
* before creating variables, we need to collapse the dataset to be at the FIPS, NAICs, year quarter level
* this code keeps just the private data 

g empl_quarterly=month3_emplvl
keep if own=="Private"
collapse (sum) empl_quarterly firms total_wages taxable_qtrly_wages qtrly_contributions (mean) avg_wkly_wage , by(FIPS NAICS year qtr)

* the dataset has a lot of zeros (when do we eliminate them?)
* drop all counties/industries that report zero employment in all years, they won't be used for identificaiton anyway 
bysort FIPS NAICS: egen maxempl_quarterly=max(empl_quarterly)
drop if maxempl_quarterly==0
drop maxempl_quarterly

* labeling

label variable taxable_qtrly_wages "taxable quarterly wages"
label variable qtrly_contributions "quarterly tax contributions"
label variable avg_wkly_wage "average individual weekly wage"
label variable firms "number of firms"
label variable total_wages "total wages"


* Create a new treated variable that shows if the NAICS code is a treated industry

gen treat = 0

replace treat = 1 if ///
NAICS==2111 | NAICS==2122 | NAICS==2123 | NAICS==2131 | ///
NAICS==2211 | NAICS==2213 | NAICS==2361 | NAICS==2362 | NAICS==2371 | NAICS==2382 | ///
NAICS==3112 | NAICS==3241 | NAICS==3251 | NAICS==3272 | NAICS==3273 | ///
NAICS==3311 | NAICS==3313 | NAICS==3314 | NAICS==3334 | NAICS==3336 | ///
NAICS==3344 | NAICS==3353 | NAICS==3359 | NAICS==3361 | NAICS==3363 | ///
NAICS==4861 | NAICS==4862 | NAICS==4869 | ///
NAICS==5413 | NAICS==5416 | NAICS==5417 | NAICS==5622

label variable treat "Dummy = 1 if NAICS industry affected by IRA 2022"

order treat, after(NAICS)


* this code generates exposure variables in 2022 (we do not use 2018) 


foreach var of varlist firms empl_quarterly total_wages {
bysort FIPS  : egen `var'sumtemp=sum(`var') if year==2022
bysort FIPS  : egen `var'trtemp=sum(`var') if treat==1 & year==2022
bysort FIPS  : egen `var'tr=max(`var'trtemp) if year==2022

g share`var'temp=`var'tr/`var'sumtemp	
bysort FIPS  : egen share`var'=mean(share`var'temp)

}


foreach var of varlist sharefirms shareempl_quarterly sharetotal_wages {
	su `var', d
g high`var'=`var'>`r(p50)'
g tq`var'=`var'>`r(p75)'
g bq`var'=`var'<`r(p25)'
}

drop *temp

sort FIPS year qtr
order FIPS  year qtr

gen quarterly = yq(year, qtr)
format quarterly %tq

cap drop post
g post=(quarterly>yq(2022, 4))


 * growth rates 
 
 egen fipsc=group(FIPS)
 egen fipscind=group(FIPS NAICS)

 xtset fipscind quarterly
 
 * quarterly growth rates
 rename avg_wkly_wage weekly_wage
 foreach var of varlist firms total_wages empl_quarterly weekly_wage {
g	gr`var'=(`var'-l.`var')/l.`var'
}

* growth rates relative to 2022 relevant quarter benchmark
foreach var of varlist firms total_wages empl_quarterly weekly_wage {
g `var'2022q1=`var' if year==2022	& qtr==1
g `var'2022q2=`var' if year==2022	& qtr==2
g `var'2022q3=`var' if year==2022	& qtr==3
g `var'2022q4=`var' if year==2022	& qtr==4

bysort FIPS NAICS: egen mean`var'2022q1=mean(`var'2022q1)
bysort FIPS NAICS: egen mean`var'2022q2=mean(`var'2022q2)
bysort FIPS NAICS: egen mean`var'2022q3=mean(`var'2022q3)
bysort FIPS NAICS: egen mean`var'2022q4=mean(`var'2022q4)

g	gr`var'2022=(`var'-mean`var'2022q1)/mean`var'2022q1 if qtr==1
replace gr`var'2022=(`var'-mean`var'2022q2)/mean`var'2022q2 if qtr==2
replace gr`var'2022=(`var'-mean`var'2022q3)/mean`var'2022q3 if qtr==3
replace gr`var'2022=(`var'-mean`var'2022q4)/mean`var'2022q4 if qtr==4
drop mean`var'2022* `var'2022*
}
 

 rename grempl_quarterly2022 grempl2022

* the main variable is winsorized at 1% but then we also winsorzie at 5%
* when we winsorize matters relative to dropping observations (dropping teh countyx naics cells with zero employment in at least 1 of the years is restricve)

 winsor2  grfirms grtotal_wages grempl_quarterly grweekly_wage grfirms2022 grtotal_wages2022 grempl2022 grweekly_wage2022 , cut(5, 95)

 
 winsor2  grfirms grtotal_wages grempl_quarterly grweekly_wage grfirms2022 grtotal_wages2022 grempl2022 grweekly_wage2022 , cut(1, 99) replace

g state=substr(FIPS,1,2)
destring state, replace


* rename variables with subscript _private

foreach var of varlist treat grfirms2022 grtotal_wages2022 grempl2022 grweekly_wage2022 shareempl_quarterly sharetotal_wages sharefirms {
	rename `var' `var'_private
} 

keep treat FIPS year qtr NAICS *_private


* Converts values into strings and concatenates them.

gen FIPSQTRYR = FIPS + string(qtr) + string(year)

sort FIPSQTRYR

}

save "`path'/Raw_Data/BLS/countyindustrylevel_private.dta", replace


*======================================
**# GENERATE PUBLIC BLS EMPLOYMENT DATASET (at the country-level)
*======================================

u "`path'/Raw_Data/BLS/merged_data_4digit.dta", clear

{

* this dataset contains different levels of employment, private, public etc
* before creating variables, we need to collapse the dataset to be at the FIPS, NAICs, year quarter level
* this code keeps just the private data 

g empl_quarterly=month3_emplvl
ta own
drop if own=="Private"
collapse (sum) empl_quarterly firms total_wages taxable_qtrly_wages qtrly_contributions (mean) avg_wkly_wage , by(FIPS year qtr)

* labeling

label variable taxable_qtrly_wages "taxable quarterly wages"
label variable qtrly_contributions "quarterly tax contributions"
label variable avg_wkly_wage "average individual weekly wage"
label variable firms "number of firms"
label variable total_wages "total wages"


 * growth rates 
 
 gen quarterly = yq(year, qtr)
format quarterly %tq

 egen fipsc=group(FIPS)
 xtset fipsc quarterly
 
 * quarterly growth rates
 rename avg_wkly_wage weekly_wage
 foreach var of varlist firms total_wages empl_quarterly weekly_wage {
g	gr`var'=(`var'-l.`var')/l.`var'
}

* growth rates relative to 2022 relevant quarter benchmark
foreach var of varlist firms total_wages empl_quarterly weekly_wage {
g `var'2022q1=`var' if year==2022	& qtr==1
g `var'2022q2=`var' if year==2022	& qtr==2
g `var'2022q3=`var' if year==2022	& qtr==3
g `var'2022q4=`var' if year==2022	& qtr==4

bysort FIPS : egen mean`var'2022q1=mean(`var'2022q1)
bysort FIPS : egen mean`var'2022q2=mean(`var'2022q2)
bysort FIPS : egen mean`var'2022q3=mean(`var'2022q3)
bysort FIPS : egen mean`var'2022q4=mean(`var'2022q4)

g	gr`var'2022=(`var'-mean`var'2022q1)/mean`var'2022q1 if qtr==1
replace gr`var'2022=(`var'-mean`var'2022q2)/mean`var'2022q2 if qtr==2
replace gr`var'2022=(`var'-mean`var'2022q3)/mean`var'2022q3 if qtr==3
replace gr`var'2022=(`var'-mean`var'2022q4)/mean`var'2022q4 if qtr==4
drop mean`var'2022* `var'2022*
}
 

 rename grempl_quarterly2022 grempl2022

* the main variable is winsorized at 1% but then we also winsorzie at 5%
* when we winsorize matters relative to dropping observations (dropping teh countyx naics cells with zero employment in at least 1 of the years is restricve)

 winsor2   grfirms2022 grtotal_wages2022 grempl2022 grweekly_wage2022 , cut(5, 95)
 winsor2  grfirms2022 grtotal_wages2022 grempl2022 grweekly_wage2022 , cut(1, 99) replace


* rename variables with subscript _private

foreach var of varlist  grfirms2022 grtotal_wages2022 grempl2022 grweekly_wage2022 {
	rename `var' `var'_public
} 

keep  FIPS year qtr  *_public


g state=substr(FIPS,1,2)
destring state, replace

* drop states 2, 15 (Alska, Hawaii)
* drop state 72 and 78

drop if state==2
drop if state==15
drop if state==72
drop if state==78


* Converts values into strings and concatenates them.

gen FIPSQTRYR = FIPS + string(qtr) + string(year)

sort FIPSQTRYR

}

save "`path'/Raw_Data/BLS/countyindustrylevel_public.dta", replace

}



*======================================
**# IRA
*======================================

{
	
	
	*The USA grant data can be found at https://www.usaspending.gov/download_center/award_data_archive by downloading the FY####_All_Contracts_Full_########.zip file filtered by Agency - "All", Award Type - "Financial Assistance", for fiscal years 2018 to 2025. 
	*This .do can replicate the dataset as long as all of the .csv files are unzipped and placed in the same "Award_Spending_Download" folder (The organization of the subfolders does not matter) 


*prepare sub award data format to merge 
*this is necessary to connect each prime award with its corresponding sub award amount totals
import delimited using "`path'/Raw_Data/IRA/all_subawards_results_API.csv" , clear delimiter(comma) bindquote(strict) emptylines(include) encoding(UTF-8) maxquotedrows(unlimited)
collapse (sum) subawardamount, by(primeawardid)
rename primeawardid award_id
rename subawardamount lifetime_s
tempfile sub_lifetime
save "`sub_lifetime'"

*prepare sub award data to append
import delimited using "`path'/Raw_Data/IRA/all_subawards_results_API.csv" , clear delimiter(comma) bindquote(strict) emptylines(include) encoding(UTF-8) maxquotedrows(unlimited)
rename subawardamount federal_action_obligation
rename primeawardid award_id
rename subawarddate action_date
rename subawarddescription prime_award_base_transaction_des
rename subrecipientlocation prime_award_transaction_recipien
rename subawardprimaryplaceofperformanc prime_award_transaction_place_of
gen awardtype = "sub"
*remove if there is a "None" for location data 
drop if prime_award_transaction_recipien == . & prime_award_transaction_place_of == .
destring prime_award_transaction_recipien prime_award_transaction_place_of, replace 

tempfile subdata
save "`subdata'"

*In order to identify spending amounts relating to the Inflation Reduction Act (IRA) we use CFDA codes. A Catalog of Federal Domestic Assistance (CFDA) number is a five digit code that uniquely identifies the grant proram for which the funding was awarded in the usaspending.gov dataset. The government grants website sam.gov stores major information for all government grants including a general description and the laws which authorize them. We use both the description and the associated legislation to determine which grant programs were affected by the IRA. Some grants were created and authorized by the IRA. Others already existed, but recieved additional funding from the IRA. Certain grants do not list the Inflation Recuction Act (Public Law No: 117-169) as the authorizing piece of legislation, yet they are still related. For those, the IRA changed portions of other existing public law to allow or create new grants under the umbrella of pre-existing law. Thus, such laws do not list the IRA as the authorizing legislation, but they do mention the IRA in their grant description. 

import delimited "`path'/Raw_Data/IRA/SAM_CFDA_codes/AssistanceListings_DataGov_PUBLIC_CURRENT.csv", clear maxquotedrows(unlimited) varnames(1) stringcols(_all) bindquote(strict)

keep programnumber authorization040 objectives050 typesofassistance060 publisheddate

*Data Cleaning
{
replace authorization040 = subinstr(authorization040, "P.L.", "Public Law", .)
replace authorization040 = subinstr(authorization040, "PL", "Public Law", .)
replace authorization040 = subinstr(authorization040, "P. L.", "Public Law", .)
replace authorization040 = subinstr(authorization040, "P.L", "Public Law", .)
replace authorization040 = subinstr(authorization040, "P.L. No:", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Pub. L.", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Pub. L. No.", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Pub.L.", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Pub L.", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Pub L", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Pub. L", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Pub. Law", "Public Law", .)
replace authorization040 = subinstr(authorization040, "pub. L.", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Pub L No.", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Public law", "Public Law", .)
replace authorization040 = subinstr(authorization040, "PUBLIC LAW", "Public Law", .)
replace authorization040 = subinstr(authorization040, "public Law", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Public Law Public Law", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Public Law P.L.", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Public Law PL", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Public Law Public law", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Public Law No.", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Public Law No:", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Public Law Number", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Public\rlaw", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Publice Law", "Public Law", .)
replace authorization040 = subinstr(authorization040, "Public, Law", "Public Law", .)

replace authorization040 = subinstr(authorization040, "U.S.C.", "US Code", .)
replace authorization040 = subinstr(authorization040, "USC", "US Code", .)
replace authorization040 = subinstr(authorization040, "U.S.C", "US Code", .)
replace authorization040 = subinstr(authorization040, "U.S. Code", "US Code", .)
replace authorization040 = subinstr(authorization040, "United States Code", "US Code", .)
replace authorization040 = subinstr(authorization040, "U.S. C.", "US Code", .)
replace authorization040 = subinstr(authorization040, "U.S. C", "US Code", .)
replace authorization040 = subinstr(authorization040, "U.SC.", "US Code", .)
replace authorization040 = subinstr(authorization040, "(", "", .)
replace authorization040 = subinstr(authorization040, ")", "", .)
replace authorization040 = subinstr(authorization040, "§", "", .)
*for text parsing purposes, I add a trailing space to allow a later function to work properly
replace authorization040 = authorization040 + " "


replace objectives050 = subinstr(objectives050, "P.L.", "Public Law", .)
replace objectives050 = subinstr(objectives050, "PL", "Public Law", .)
replace objectives050 = subinstr(objectives050, "P. L.", "Public Law", .)
replace objectives050 = subinstr(objectives050, "P.L", "Public Law", .)
replace objectives050 = subinstr(objectives050, "P.L. No:", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Pub. L.", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Pub. L. No.", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Pub.L.", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Pub L.", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Pub L", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Pub. L", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Pub. Law", "Public Law", .)
replace objectives050 = subinstr(objectives050, "pub. L.", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Pub L No.", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Public law", "Public Law", .)
replace objectives050 = subinstr(objectives050, "PUBLIC LAW", "Public Law", .)
replace objectives050 = subinstr(objectives050, "public Law", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Public Law Public Law", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Public Law P.L.", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Public Law PL", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Public Law Public law", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Public Law No.", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Public Law No:", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Public Law Number", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Public\rlaw", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Publice Law", "Public Law", .)
replace objectives050 = subinstr(objectives050, "Public, Law", "Public Law", .)
}

*Dummy For Being Authorized by IRA directly or indirectly
gen IRA_author = strpos(authorization040, "Inflation Reduction Act") > 0 
replace IRA_author = 1 if strpos(authorization040, "Public Law 117-169") > 0 
replace IRA_author = 1 if strpos(authorization040, "117-169") > 0 & strpos(authorization040, "Public Laws") > 0
replace IRA_author = 1 if strpos(objectives050, "Inflation Reduction Act") > 0 
replace IRA_author = 1 if strpos(objectives050, "Public Law 117-169") > 0 

*test if New US code sections (or subsections of those) from IRA authorize the grant
*This text parsing identifies a section or subsection of the IRA US Code portions if the authorization description contains the exact text for the IRA section (ex. "26 US Code 4001") and if the charecter immediately after the search text is a non-nunmber (ie a space when the section is an exact match, or a letter when the authorization text is a subsection)
 *this keeps the text parsing from getting a false positive, as if I searched for "26 US Code 21" and accepted "26 US Code 2101" as the same.

*The following list of US Code sections consists of every (1) new section or (2) preceeding or (3) new preceeding section created by the Inflation Reduction Act (Public Law 117-169)
*https://uscode.house.gov/classification/tbl117pl_2nd.htm 
 
foreach section in "26 US Code 56A" "26 US Code 55" "26 US Code 4501" "26 US Code 4501" "26 US Code 4001" "42 US Code 1320f" "42 US Code 1320f-1" "42 US Code 1320f-2" "42 US Code 1320f-3" "42 US Code 1320f-4" "42 US Code 1320f-5" "42 US Code 1320f-6" "42 US Code 1320f-7" "26 US Code 5000D" "26 US Code 5000D" "26 US Code 4001" "42 US Code 1395w-114b" "42 US Code 1395w-114c" "42 US Code 1395w-114d" "26 US Code 45U" "26 US Code 38" "26 US Code 40B" "26 US Code 38" "26 US Code 45V" "26 US Code 38" "26 US Code 21" "26 US Code 21" "26 US Code 27" "26 US Code 25E" "26 US Code 21" "26 US Code 45W" "26 US Code 38" "26 US Code 45X" "26 US Code 38" "26 US Code 45Y" "26 US Code 38" "26 US Code 48E" "26 US Code 46" "26 US Code 45Z" "26 US Code 38" "26 US Code 6417" "26 US Code 6418" "26 US Code 6411" "42 US Code 18795" "42 US Code 18795a" "42 US Code 18795b" "42 US Code 16517" "42 US Code 18715" "42 US Code 18715a" "42 US Code 18715b" "42 US Code 17113b" "43 US Code 1356c" "30 US Code 1727" "43 US Code 3006" "42 US Code 7432" "42 US Code 7433" "42 US Code 7434" "42 US Code 7435" "42 US Code 7436" "42 US Code 7437" "42 US Code 7438" "23 US Code 177" "23 US Code 101" "23 US Code 178" "23 US Code 101" "23 US Code 179" "23 US Code 101" {
	replace IRA_author = 1 if strpos(authorization040, "`section'") > 0 & 1 == regexm( substr( authorization 040, ( strpos(authorization040, "`section'") + strlen("`section'") ), 1 ) ,"[^0-9]")
}

keep if IRA_author == 1
keep programnumber
destring programnumber, replace
rename programnumber cfda_number
gen IRA_new = 1
recast double cfda_number, force
replace cfda_number = round(cfda_number, 0.001) 

save "`path'/Raw_Data/IRA/SAM_CFDA_codes/IRA_identifier.dta", replace

local obsIRAlist = _N


clear
cd "`path'/Raw_Data/IRA/Award_Spending_Download"

* Build a list of all CSV files in the directory
*ssc install filelist
filelist, list directory()
tempfile ListCsv
save "`ListCsv'"
  
local obs = _N

* Loop through each file, import, clean, and tag IRA awards
forvalues i=1/`obs' {
	use "`ListCsv'" in `i', clear
	local f = dirname + "/" + filename
	import delimited using "`f'", clear delimiter(comma) bindquote(strict) emptylines(include) encoding(UTF-8) maxquotedrows(unlimited)
	keep assistance_award_unique_key award_id_fain award_id_uri modification_number federal_action_obligation total_obligated_amount total_outlayed_amount_for_overal action_date action_date_fiscal_year period_of_performance_start_date period_of_performance_current_en treasury_accounts_funding_this_a program_activities_funding_this_ prime_award_transaction_recipien prime_award_transaction_place_of cfda_number assistance_type_code prime_award_base_transaction_des business_types_code action_type_code record_type_code business_types_description recipient_name
	
	drop if federal_action_obligation <= 0
	drop if federal_action_obligation == .
	
	gen award_id = award_id_fain
	replace award_id = award_id_uri if award_id == ""
	drop award_id_fain award_id_uri

	* Create IRA identifiers based on description and program activity strings
	gen IRA1 = strpos(prime_award_base_transaction_des, " IRA ") > 0
	gen IRA2 = strpos(prime_award_base_transaction_des, "INFLATION REDUCTION ACT") > 0
	gen IRA3 = strpos(program_activities_funding_this_, "INFLATION REDUCTION ACT") > 0
	gen IRA4 = strpos(program_activities_funding_this_, " IRA ") > 0

	* Each of these programs mentioned the Inflation Reduction Act as a source of their funding at some point in time. Many of these programs pre date the IRA. This is the CFDA codes generated from the SAM data above
capture {
    recast double cfda_number, force
    replace cfda_number = round(cfda_number, 0.001)
}

if _rc {
    replace cfda_number = substr(cfda_number, 1, 2) if ustrregexm(cfda_number, "[A-Za-z]") > 0 
    destring cfda_number, replace 
	recast double cfda_number, force
    replace cfda_number = round(cfda_number, 0.001)
}
	
	merge m:1 cfda_number using "`path'/Raw_Data/IRA/SAM_CFDA_codes/IRA_identifier.dta"
	drop if _merge == 2
	drop _merge
	replace IRA_new =0 if IRA_new == .
	
	rename IRA_new IRA5
	
	* Create IRA_unique identifier for CFDA numbers exclusively tied to the IRA, meaning only programas that came into being because of the IRA
	gen IRA_unique = 0
	replace IRA_unique = 1 if cfda_number == float(10.758)
	replace IRA_unique = 1 if cfda_number == float(10.968)
	replace IRA_unique = 1 if cfda_number == float(10.984)
	replace IRA_unique = 1 if cfda_number == float(14.021)
	replace IRA_unique = 1 if cfda_number == float(15.165)
	replace IRA_unique = 1 if cfda_number == float(15.577)
	replace IRA_unique = 1 if cfda_number == float(20.115)
	replace IRA_unique = 1 if cfda_number == float(66.046)
	replace IRA_unique = 1 if cfda_number == float(66.049)
	replace IRA_unique = 1 if cfda_number == float(66.614)
	replace IRA_unique = 1 if cfda_number == float(66.615)
	replace IRA_unique = 1 if cfda_number == float(66.616)
	replace IRA_unique = 1 if cfda_number == float(66.721)
	replace IRA_unique = 1 if cfda_number == float(66.957)
	replace IRA_unique = 1 if cfda_number == float(66.959)
	replace IRA_unique = 1 if cfda_number == float(66.96)
	replace IRA_unique = 1 if cfda_number == float(81.253)
	replace IRA_unique = 1 if cfda_number == float(81.256)

	* Combine all IRA flags into a single indicator

	gen IRA = 0
	replace IRA = federal_action_obligation if IRA1 == 1 | IRA2 == 1 | IRA3 == 1 | IRA4 == 1 | IRA5 == 1 
	
	gen IRAalt=0
replace IRAalt=federal_action_obligation if IRA1 == 1 | IRA2 == 1 | IRA3 == 1 | IRA4 == 1

	gen IRAunique = 0
	replace IRAunique = federal_action_obligation if IRA1 == 1 | IRA2 == 1 | IRA3 == 1 | IRA4 == 1 | IRA_unique == 1 	
	
	drop IRA1 IRA2 IRA3 IRA4 IRA5 IRA_unique
	
	destring assistance_type_code, force replace
	
	tempfile save`i'
	save "`save`i''"

}

* Combine all per-file tempfiles into one master dataset
use "`save1'", clear
forvalues i=2/`obs' {
	append using "`save`i''"
}


*add the sub award data
gen awardtype = "prime"
merge m:1 award_id using "`sub_lifetime'"
drop if _merge ==2

bysort award_id: egen total_change_A = total(federal_action_obligation) if _merge == 3 
bysort award_id: egen n_transactions_A = count(award_id) if _merge == 3 
replace federal_action_obligation = (total_change_A-lifetime_s) / n_transactions_A if _merge == 3

drop n_transactions_A total_change_A _merge lifetime_s  

tempfile prime_awards_only
save "`prime_awards_only'"


*fill all the missing fields in the subdata
keep if IRA > 0 
collapse (first) total_obligated_amount total_outlayed_amount_for_overal period_of_performance_start_date period_of_performance_current_en recipient_name assistance_type_code business_types_code business_types_description action_type_code record_type_code IRA IRAalt IRAunique, by(award_id)

merge 1:m award_id using "`subdata'"
keep if _merge == 3
gen action_date_fiscal_year = substr(action_date, 1, 4)
destring action_date_fiscal_year, replace
replace IRA = federal_action_obligation if IRA > 0 
replace IRAalt = federal_action_obligation if IRAalt > 0 
replace IRAunique = federal_action_obligation if IRAunique > 0 


append using "`prime_awards_only'"


* Navigate to Master Data folder
cd "`path'/Master_Data"

* Save a copy of IRA-only awards before further processing
preserve
keep if IRA != 0 
save 11.02.26_AllIraSpending.dta, replace
restore

* Create quarter variable from action date
gen month = substr(action_date, 6, 2)
gen quarter = "."
replace quarter = "1" if month == "01" | month == "02" | month == "03"
replace quarter = "2" if month == "04" | month == "05" | month == "06"
replace quarter = "3" if month == "07" | month == "08" | month == "09"
replace quarter = "4" if month == "10" | month == "11" | month == "12"


preserve
** PLACE BASED ON LOCATION OF PLACE OF PERFORMANCE (as in P)**

drop if prime_award_transaction_place_of > 56045
drop if mod(prime_award_transaction_place_of, 1000)  == 999
tostring prime_award_transaction_place_of, replace
gen state = substr(prime_award_transaction_place_of,1,2)
drop if state=="02"
drop if state=="15"
drop if state=="72"
drop if state=="78"
replace prime_award_transaction_place_of = "0" + prime_award_transaction_place_of if strlen(prime_award_transaction_place_of) == 4


tostring prime_award_transaction_recipien prime_award_transaction_place_of, replace


* Create FIPSQTRYR panel key

replace prime_award_transaction_place_of = prime_award_transaction_recipien if prime_award_transaction_place_of == ""
drop if prime_award_transaction_place_of == ""
gen FIPSQTRYR = prime_award_transaction_place_of + quarter + string(action_date_fiscal_year)


*Record Total lifetime outlay of cash and lifetime awardance of cash, for each grant award, which is to be saved only to the first observation of the award 
gen new_date = daily(action_date, "YMD")
format new_date %td
sort award_id new_date

by award_id: gen first_obs = _n == 1
replace total_obligated_amount = 0 if first_obs == 0
replace total_outlayed_amount_for_overal = 0 if first_obs == 0

rename federal_action_obligation AllGovAward


gen AllGovOutlayed = total_outlayed_amount_for_overal
gen AllGovPromised = total_obligated_amount

gen IRA_Outlayed_alt = total_outlayed_amount_for_overal if IRAalt == 1 
gen IRA_Promised_alt  = total_obligated_amount if IRAalt == 1 

gen IRA_Outlayed_unique = total_outlayed_amount_for_overal if IRAunique == 1 
gen IRA_Promised_unique = total_obligated_amount if IRAunique == 1 

gen IRA_Outlayed = total_outlayed_amount_for_overal if IRA == 1 
gen IRA_Promised = total_obligated_amount if IRA == 1 

* Collapse to FIPSQTRYR level
collapse (sum) AllGovAward AllGovOutlayed AllGovPromised IRA*, by(FIPSQTRYR)

rename AllGovAward AllGovAward_P 
rename AllGovOutlayed AllGovOutlayed_P 
rename AllGovPromised AllGovPromised_P
rename IRA IRA_P 
rename IRAalt IRAalt_P 
rename IRAunique IRAunique_P 
rename IRA_Outlayed_alt IRA_Outlayed_alt_P
rename IRA_Promised_alt IRA_Promised_alt_P
rename IRA_Outlayed_unique IRA_Outlayed_unique_P
rename IRA_Promised_unique IRA_Promised_unique_P 
rename IRA_Outlayed IRA_Outlayed_P 
rename IRA_Promised IRA_Promised_P

label variable AllGovAward_P "total additional fed $ committed/retracted to county this qtr for all awards"
label variable AllGovPromised_P "tot fed $ committed to cnty, for all time, for awards issued this qtr, all award"
label variable AllGovOutlayed_P "tot fed $ sent to cnty, for all time, for awards issued this qtr, all award type"


label variable IRA_P "total additional fed $ committed/retraced to this county for IRA1-5 awards"
label variable IRA_Promised_P "tot fed $ committed to cnty, for all time, for awards issued this qtr, IRA1-5"
label variable IRA_Outlayed_P "tot fed $ sent to cnty, for all time, for awards issued this qtr, IRA1-5 awards"


label variable IRAalt_P "total additional fed $ committed/retraced to this county for IRA1-4 awards"
label variable IRA_Promised_alt_P "tot fed $ committed to cnty, for all time, for awards issued this qtr, IRA1-4"
label variable IRA_Outlayed_alt_P "tot fed $ sent to cnty, for all time, for awards issued this qtr, IRA1-4 awards"


label variable IRAunique_P "total add fed $ comm/ret to county for awards created by the IRA"
label variable IRA_Promised_unique_P "tot fed $ committed to cnty, for all time, for awards issued this qtr, IRA_uniq"
label variable IRA_Outlayed_unique_P "tot fed $ sent to cnty, for all time, for awards issued this qtr, IRA_unq awards"




tempfile Collapsed_IRAspending_BLS_P
save "`Collapsed_IRAspending_BLS_P'"

****************************************************************************
cd "`path'/Raw_Data/IRA"
save Collapsed_IRAspending_P, replace 



** PLACE BASED ON LOCATION OF BUSINESS HQ (as in H)**
restore

drop if prime_award_transaction_recipien > 56045
drop if mod(prime_award_transaction_recipien, 1000)  == 999
tostring prime_award_transaction_recipien, replace
gen state = substr(prime_award_transaction_recipien,1,2)
drop if state=="02"
drop if state=="15"
drop if state=="72"
drop if state=="78"
replace prime_award_transaction_recipien = "0" + prime_award_transaction_recipien if strlen(prime_award_transaction_recipien) == 4

tostring prime_award_transaction_recipien prime_award_transaction_place_of, replace

* Create FIPSQTRYR panel key
replace prime_award_transaction_recipien = prime_award_transaction_place_of if prime_award_transaction_recipien == ""
drop if prime_award_transaction_recipien == ""
gen FIPSQTRYR = prime_award_transaction_recipien + quarter + string(action_date_fiscal_year)


*Record Total lifetime outlay of cash and lifetime awardance of cash, for each grant award, which is to be saved only to the first observation of the award 
gen new_date = daily(action_date, "YMD")
format new_date %td
sort award_id new_date

by award_id: gen first_obs = _n == 1
replace total_obligated_amount = 0 if first_obs == 0
replace total_outlayed_amount_for_overal = 0 if first_obs == 0

rename federal_action_obligation AllGovAward


gen AllGovOutlayed = total_outlayed_amount_for_overal
gen AllGovPromised = total_obligated_amount

gen IRA_Outlayed_alt = total_outlayed_amount_for_overal if IRAalt == 1 
gen IRA_Promised_alt  = total_obligated_amount if IRAalt == 1 

gen IRA_Outlayed_unique = total_outlayed_amount_for_overal if IRAunique == 1 
gen IRA_Promised_unique = total_obligated_amount if IRAunique == 1 

gen IRA_Outlayed = total_outlayed_amount_for_overal if IRA == 1 
gen IRA_Promised = total_obligated_amount if IRA == 1 

* Collapse to FIPSQTRYR level
collapse (sum) AllGovAward AllGovOutlayed AllGovPromised IRA*, by(FIPSQTRYR)

rename AllGovAward AllGovAward_H 
rename AllGovOutlayed AllGovOutlayed_H 
rename AllGovPromised AllGovPromised_H
rename IRA IRA_H 
rename IRAalt IRAalt_H 
rename IRAunique IRAunique_H 
rename IRA_Outlayed_alt IRA_Outlayed_alt_H
rename IRA_Promised_alt IRA_Promised_alt_H
rename IRA_Outlayed_unique IRA_Outlayed_unique_H
rename IRA_Promised_unique IRA_Promised_unique_H
rename IRA_Outlayed IRA_Outlayed_H
rename IRA_Promised IRA_Promised_H

label variable AllGovAward_H "total additional fed $ committed/retracted to county this qtr for all awards"
label variable AllGovPromised_H "tot fed $ committed to cnty, for all time, for awards issued this qtr, all award"
label variable AllGovOutlayed_H "tot fed $ sent to cnty, for all time, for awards issued this qtr, all award type"


label variable IRA_H "total additional fed $ committed/retraced to this county for IRA1-5 awards"
label variable IRA_Promised_H "tot fed $ committed to cnty, for all time, for awards issued this qtr, IRA1-5"
label variable IRA_Outlayed_H "tot fed $ sent to cnty, for all time, for awards issued this qtr, IRA1-5 awards"


label variable IRAalt_H "total additional fed $ committed/retraced to this county for IRA1-4 awards"
label variable IRA_Promised_alt_H "tot fed $ committed to cnty, for all time, for awards issued this qtr, IRA1-4"
label variable IRA_Outlayed_alt_H "tot fed $ sent to cnty, for all time, for awards issued this qtr, IRA1-4 awards"


label variable IRAunique_H "total add fed $ comm/ret to county for awards created by the IRA"
label variable IRA_Promised_unique_H "tot fed $ committed to cnty, for all time, for awards issued this qtr, IRA_uniq"
label variable IRA_Outlayed_unique_H "tot fed $ sent to cnty, for all time, for awards issued this qtr, IRA_unq awards"

tempfile Collapsed_IRAspending_BLS_H
save "`Collapsed_IRAspending_BLS_H'"

****************************************************************************
cd "`path'/Raw_Data/IRA"
save Collapsed_IRAspending_H, replace 

}

*======================================
**# BEA GDP
*======================================

{
* The BEA GDP data is retrieved from the interactive data tool at https://apps.bea.gov/itable/?ReqID=70&step=1#eyJhcHBpZCI6NzAsInN0ZXBzIjpbMSwyOSwyNSwzMSwyNiwyNywzMF0sImRhdGEiOltbIlRhYmxlSWQiLCI1MzMiXSxbIk1ham9yX0FyZWEiLCI0Il0sWyJTdGF0ZSIsWyJYWCJdXSxbIkFyZWEiLFsiWFgiXV0sWyJTdGF0aXN0aWMiLFsiMSJdXSxbIlVuaXRfb2ZfbWVhc3VyZSIsIkxldmVscyJdLFsiWWVhciIsWyIyMDI0IiwiMjAyMyIsIjIwMjIiLCIyMDIxIiwiMjAyMCIsIjIwMTkiLCIyMDE4Il1dLFsiWWVhckJlZ2luIiwiLTEiXSxbIlllYXJfRW5kIiwiLTEiXV19

*RETRIEVED ON 8/31/26, Using CAGDP1 County gross domestic product (GDP) summary

import delimited "`path'/Raw_Data/BEA_GDP/CountyGdpData_2018_2024.csv", varname(1) clear

* Reshape from wide (one column per year) to long
* Verify column names before reshaping: ds v*
reshape long v, i(geofips) j(year)

* Rename and fix year offset
rename v county_GDP_yr
destring county_GDP_yr, replace

rename geofips FIPS

drop if geoname ==""
replace year = 2018 if year == 3
replace year = 2019 if year == 4
replace year = 2020 if year == 5
replace year = 2021 if year == 6
replace year = 2022 if year == 7
replace year = 2023 if year == 8
replace year = 2024 if year == 9
tostring year, replace

gen unq = _n
expand 4 
bysort unq: gen qtr = _n
tostring qtr, replace

gen FIPSQTRYR = FIPS + qtr + year

keep FIPSQTRYR county_GDP_yr
replace county_GDP_yr = "" if county_GDP_yr == "(NA)"
destring county_GDP_yr, replace

rename county_GDP_yr Current_GDP

label variable Current_GDP "Yearly GDP aggregate by county"



save "`path'/Raw_Data/BEA_GDP/BEA_GDP.dta", replace
****************************************************************************
} 

*======================================
**# CENSUS POPULATION
*======================================

{	
* The Census Population data is categorized by county.
* Merges two Excel files: 2010–2020 and 2020–2025.

tempfile temp_pop_2010_2020

* Load 2015–2020 population data from 2010–2020 file
import excel "`path'/Raw_Data/Census_Population/2010-2020 pop.xlsx", ///
	firstrow clear
drop geoname April12010EstimatesBase D E F G H 
replace FIPS = strtrim(FIPS)
replace FIPS = substr(FIPS,2,5)
rename I population2015
rename J population2016
rename K population2017
rename L population2018
rename M population2019
rename April12020census population2020

save `temp_pop_2010_2020'

*2021-2025 population data
*this comes from the excel file: Annual Resident Population Estimates... found on https://www.census.gov/data/tables/time-series/demo/popest/2020s-counties-total.html#v2024
import delimited "`path'/Raw_Data/Census_Population/co-est2025-alldata.csv", clear

keep state county popestimate2021 popestimate2022 popestimate2023 popestimate2024 popestimate2025
tostring(state), replace
replace state = "0" + state if strlen(state) == 1
tostring(county), replace
replace county = "0" + county if strlen(county) != 3
replace county = "0" + county if strlen(county) != 3
drop if county == "000"
gen FIPS = state + county
drop state county

rename popestimate2021 population2021
rename popestimate2022 population2022
rename popestimate2023 population2023
rename popestimate2024 population2024
rename popestimate2025 population2025

merge 1:1 FIPS using `temp_pop_2010_2020'
keep if _merge == 3
drop _merge

*We drop the following states
*15 Hawaii    02 Alaska     09 connecticut
gen dropstate = substr(FIPS,1,2)
drop if dropstate == "15" | dropstate == "02" | dropstate == "09"
drop dropstate

* Reshape to long format
reshape long population, i(FIPS) j(year)

* Create FIPSQTRYR 
*since the population is annually estimated for July 1st of the year (representing the population at the end of the 2nd quarter), we assume for simplicity a steady average growth and estimate the missing data for the other 3 quarters

gen qdate = yq(year, 2)
format qdate %tq
egen fips_id = group(FIPS)
xtset fips_id qdate
tsfill
by fips_id: ipolate population qdate, gen(pop_q)
replace year = yofd(dofq( qdate ))
gen qtr = quarter(dofq( qdate ))
tostring qtr year, replace
sort fips_id qdate
by fips_id: replace FIPS = FIPS[_n-1] if missing(FIPS)
gen FIPSQTRYR = FIPS + qtr + year
replace population = pop_q
keep FIPSQTRYR population

save "`path'/Raw_Data/Census_Population/Census_Population.dta", replace
} 

*======================================
**# ENERGY COMMUNITIES
*======================================

{
* ======================================
**# COAL ADJACENT
* ======================================
*This data can be retrieved from https://home.treasury.gov/policy-issues/tax-policy/data-transparency/all-treasury-generated-energy-communities-data-sets as of 3/5/2026
	
import excel "`path'/Raw_Data/Energy_Communities/EC_AllTracts_V4.xlsx", sheet("EC_AllTracts_V4") clear

drop in 1/2

rename C fipsplus
rename D coalclose

* Recode coal-closure flag from string to numeric
replace coalclose = "1" if coalclose == "Yes"
replace coalclose = "0" if coalclose == "No"
destring coalclose, replace

* Extract 4- or 5-digit FIPS code from the longer tract identifier
gen fips = substr(fipsplus, 1, 4) if strlen(fipsplus) == 10
replace fips = substr(fipsplus, 1, 5) if strlen(fipsplus) == 11

keep fips coalclose

* Collapse to county level (mean of tract-level flags)
collapse (mean) coalclose, by(fips)

tempfile coal
save "`coal'", replace

* ======================================
**# UNEMPLOYMENT MEASURE
* ======================================

* Load annual county-level unemployment-based Energy Community files
* for 2022, 2023, and 2024, then merge them together.
import excel "`path'/Raw_Data/Energy_Communities/EC_MSA_FFE_U2022_AllCounties.xlsx", sheet("EC_MSA_FFE_U2022_AllCounties") clear

drop in 1/2
rename A statefips
rename B countyfips
rename G energycom22
replace statefips  = "0" + statefips  if strlen(statefips)  == 1
replace countyfips = "0" + countyfips if strlen(countyfips) == 1
replace countyfips = "0" + countyfips if strlen(countyfips) == 2
gen fips = statefips + countyfips
keep fips energycom22

tempfile s1
save "`s1'"


import excel "`path'/Raw_Data/Energy_Communities/EC_MSA_FFE_U2023_AllCounties.xlsx", sheet("EC_MSA_FFE_U2023_AllCounties_V1") clear

drop in 1/2
rename A statefips
rename B countyfips
rename G energycom23
replace statefips  = "0" + statefips  if strlen(statefips)  == 1
replace countyfips = "0" + countyfips if strlen(countyfips) == 1
replace countyfips = "0" + countyfips if strlen(countyfips) == 2
gen fips = statefips + countyfips
keep fips energycom23

tempfile s2
save "`s2'"


import excel "`path'/Raw_Data/Energy_Communities/EC_MSA_FFE_U2024_AllCounties.xlsx", sheet("EC_MSA_FFE_U2024_AllCounties") clear

drop in 1/2
rename A statefips
rename B countyfips
rename R energycom24
replace statefips  = "0" + statefips  if strlen(statefips)  == 1
replace countyfips = "0" + countyfips if strlen(countyfips) == 1
replace countyfips = "0" + countyfips if strlen(countyfips) == 2
gen fips = statefips + countyfips
keep fips energycom24

tempfile s3
save "`s3'"

* Merge all three unemployment-based files together
use "`s1'", clear
forvalues i=2/3 {
	merge 1:1 fips using "`s`i''"
	rename _merge _merge`i'
}

* Trim leading zero from single-digit state FIPS codes
replace fips = substr(fips, 2, 4) if substr(fips, 1, 1) == "0"

drop _merge2 _merge3

* Merge in coal-closure adjacency data
merge 1:1 fips using "`coal'"

* Keep only matched counties (present in both sources)
keep if _merge == 3
drop _merge

destring energycom*, replace

rename fips FIPS
replace FIPS = "0"+ FIPS if strlen(FIPS) == 4  

gen unq1 = _n
expand 4 
bysort unq1: gen qtr = _n
gen unq2 = _n
expand 8 
bysort unq2: gen year = _n

replace year = 2018 if year == 1
replace year = 2019 if year == 2
replace year = 2020 if year == 3
replace year = 2021 if year == 4
replace year = 2022 if year == 5
replace year = 2023 if year == 6
replace year = 2024 if year == 7
replace year = 2025 if year == 8

tostring qtr year, replace

gen FIPSQTRYR = FIPS + qtr + year

drop FIPS qtr year unq* 

tempfile All_Energy_Comm
save "`All_Energy_Comm'"


save "`path'/Raw_Data/Energy_Communities/All_Energy_Comm.dta", replace

}



*======================================
*======================================
**# MSA PRICE LEVEL
*======================================
*======================================

{
*Regional price parity data from the BEA retrieved at the following webpage on 9/9/26
*https://apps.bea.gov/itable/?ReqID=70&step=1#eyJhcHBpZCI6NzAsInN0ZXBzIjpbMSwyOV0sImRhdGEiOltbIlRhYmxlSWQiLCIxMDEiXV19


import delimited "`path'/Raw_Data/MSA/FIPS_list.csv", clear varnames(1) stringcols(_all)

rename fips FIPS

tempfile price_parity
save "`price_parity'"


import delimited "`path'/Raw_Data/MSA/crosswalk.csv", clear varnames(1) stringcols(_all)

rename fips FIPS
drop if area_type == "Micro"
keep msa FIPS msa_name 


merge 1:1 FIPS using "`price_parity'"
drop if _merge == 1
drop _merge

gen unq = _n
expand 8 
bysort unq: gen year = _n
drop unq

replace year = 2018 if year == 1
replace year = 2019 if year == 2
replace year = 2020 if year == 3
replace year = 2021 if year == 4
replace year = 2022 if year == 5
replace year = 2023 if year == 6
replace year = 2024 if year == 7
replace year = 2025 if year == 8

*REMOVE when we get the new data
*drop if year == 2025

preserve
drop if msa == ""
save "`price_parity'", replace 
restore

keep if msa == ""
tempfile portionarea
gen state = substr(FIPS,1,2)
save "`portionarea'"


*Data for metropolitan counties
import delimited "`path'/Raw_Data/MSA/MARPP_All_Items_2018_2024.csv", clear varnames(4) stringcols(_all)

reshape long v, i(geofips) j(year)
rename v RPPs
destring RPPs, replace
label variable RPPs "Regional Price Parities"
drop if RPPs == .

rename geofips msa
drop if msa == "00000" | msa == "00999"
compress msa
drop geoname
replace year = year + 2015


merge 1:m msa year using "`price_parity'"
*We only drop msa areas relating to Alaska, Connecticut and Hawaii with the following drop. The _merge==2 observations are all non metropolitan areas

keep if _merge == 3
drop _merge msa_name

save "`price_parity'", replace 

*data for non-metropolitan counties
import delimited "`path'/Raw_Data/MSA/PARPP_All_Items_2018_2024.csv", clear varnames(4) stringcols(_all)

drop if geofips == "00000"
drop if substr(geofips,4,2) == "98"
reshape long v, i(geofips) j(year)
rename v RPPs
destring RPPs, replace
label variable RPPs "Regional Price Parities"
gen state = substr(geofips,1,2)
drop geoname geofips
drop if RPPs == .
replace year = year + 2015

merge 1:m year state using "`portionarea'"
keep if _merge == 3
drop state _merge msa msa_name
append using "`price_parity'"
tostring year, replace 



* Create qtr and FIPSQTRYR
gen unq = _n
expand 4 
bysort unq: gen qtr = _n
tostring FIPS qtr year, replace
gen FIPSQTRYR = FIPS + qtr + year
sort FIPSQTRYR
drop unq qtr year FIPS msa

cd "`path'/Raw_Data/MSA"
save "MSA_Price_Level.dta", replace	
tempfile MSA_Price_Level
save "`MSA_Price_Level'"
}


*======================================
*======================================
**# Blue vs White Collar
*======================================
*======================================

{

cd "`path'/Raw_Data/Blue_White_Collar/2025_Natnl_Empl_Mat_Pred_By_Indus"

local matfiles: dir "." files "*.csv"

* Define destrings and tostrings
local vars_to_destring "employment percentofindustry percentofoccupation"
local vars_to_string "occupationtitle occupationcode occupationtype"
local first = 1

foreach file of local matfiles {
	import delimited "`file'", clear

	cap drop projected2034employment projected2034percentofindustry projected2034percentofoccupation employmentchange20242034 employmentpercentchange20242034 occupationsort displaylevel

 *Destring
	if `: list sizeof local(vars_to_destring)' > 0 {
		capture destring `vars_to_destring', replace force
		if _rc!= 0 {
			display as error "Warning: Some `vars_to_destring' could not be destringed in `file'"
		}
	}

*Tostring 
	foreach var of local vars_to_string {
		capture tostring `var', replace force
		if _rc!= 0 {
			capture recast str250 `var'
		}
	 }

	replace occupationcode = subinstr(occupationcode, `"""', "", .) 
	gen filename = "`file'" 
	gen NAICS_match = regexs(1) if regexm(filename, "_([^.]*)\.")
	replace NAICS_match = subinstr(NAICS_match, "ind_", "", .) 
	replace NAICS_match = subinstr(NAICS_match, "p", "P", .) 

	drop filename
	
	*Assign capial O for other 
	gen labor_type = "O"

	* Assign W for white collar
	replace labor_type = "W" if strpos(occupationcode, "11-") > 0
	replace labor_type = "W" if strpos(occupationcode, "13-") > 0
	replace labor_type = "W" if strpos(occupationcode, "15-") > 0
	replace labor_type = "W" if strpos(occupationcode, "17-") > 0
	replace labor_type = "W" if strpos(occupationcode, "19-") > 0
	replace labor_type = "W" if strpos(occupationcode, "21-") > 0
	replace labor_type = "W" if strpos(occupationcode, "23-") > 0
	replace labor_type = "W" if strpos(occupationcode, "25-") > 0
	replace labor_type = "W" if strpos(occupationcode, "27-") > 0
	replace labor_type = "W" if strpos(occupationcode, "29-") > 0
	replace labor_type = "W" if strpos(occupationcode, "41-") > 0
	replace labor_type = "W" if strpos(occupationcode, "42-") > 0

	* Assign 1 for blue collar
	replace labor_type = "B" if strpos(occupationcode, "45-") > 1
	replace labor_type = "B" if strpos(occupationcode, "47-") > 1
	replace labor_type = "B" if strpos(occupationcode, "49-") > 1
	replace labor_type = "B" if strpos(occupationcode, "51-") > 1
	replace labor_type = "B" if strpos(occupationcode, "53-") > 1
	
	
	drop if occupationtype == "Summary"
	
	collapse (sum) percentofindustry (first) NAICS_match , by(labor_type)
	
	
	gen blue_col_prop = percentofindustry if labor_type == "B"
	gen white_col_prop = percentofindustry if labor_type == "W"
	gen other_col_prop = percentofindustry if labor_type == "O"
	
	collapse (sum) blue_col_prop white_col_prop other_col_prop, by(NAICS_match)
	
	
	 
	if `first' == 1 {
		save temp_combined.dta, replace
		local first = 0
	 }
	else {
		append using temp_combined.dta, force
		save temp_combined.dta, replace
	}
}	 

tempfile jobtypes
save "`jobtypes'"

*This matches any BLS 4-digit NAICS code wiht the closest 2025 National Employment Matrix code (named NAICS_match). Prioirity is given first to the most granular matches, (ex. the first 4 of the matrix code matches the complete NAICS). Then, if there is no granular match, we look for the next most granular supergroup to which the NAICS belongs (like how NAICS 4523 falls under matrix code 44-450). Our least granular matches in this file are the government jobs at the NAICS 9000 umbrella.

import delimited "`path'/Raw_Data/Blue_White_Collar/NAICS_CODES.csv", clear

rename naics NAICS
destring NAICS, replace 

gen NAICS_match = ""

replace NAICS_match ="111000" if NAICS == 1111
replace NAICS_match ="111000" if NAICS == 1112
replace NAICS_match ="111000" if NAICS == 1113
replace NAICS_match ="111000" if NAICS == 1114
replace NAICS_match ="111000" if NAICS == 1119
replace NAICS_match ="112000" if NAICS == 1121
replace NAICS_match ="112000" if NAICS == 1122
replace NAICS_match ="112000" if NAICS == 1123
replace NAICS_match ="112000" if NAICS == 1124
replace NAICS_match ="112000" if NAICS == 1125
replace NAICS_match ="112000" if NAICS == 1129
replace NAICS_match ="1131-2" if NAICS == 1131
replace NAICS_match ="1131-2" if NAICS == 1132
replace NAICS_match ="113300" if NAICS == 1133
replace NAICS_match ="114000" if NAICS == 1141
replace NAICS_match ="114000" if NAICS == 1142
replace NAICS_match ="115000" if NAICS == 1151
replace NAICS_match ="115000" if NAICS == 1152
replace NAICS_match ="115000" if NAICS == 1153
replace NAICS_match ="211000" if NAICS == 2111
replace NAICS_match ="212100" if NAICS == 2121
replace NAICS_match ="212200" if NAICS == 2122
replace NAICS_match ="212300" if NAICS == 2123
replace NAICS_match ="213000" if NAICS == 2131
replace NAICS_match ="221100" if NAICS == 2211
replace NAICS_match ="221200" if NAICS == 2212
replace NAICS_match ="221300" if NAICS == 2213
replace NAICS_match ="236100" if NAICS == 2361
replace NAICS_match ="236200" if NAICS == 2362
replace NAICS_match ="237100" if NAICS == 2371
replace NAICS_match ="237200" if NAICS == 2372
replace NAICS_match ="237300" if NAICS == 2373
replace NAICS_match ="237900" if NAICS == 2379
replace NAICS_match ="238100" if NAICS == 2381
replace NAICS_match ="238200" if NAICS == 2382
replace NAICS_match ="238300" if NAICS == 2383
replace NAICS_match ="238900" if NAICS == 2389
replace NAICS_match ="311100" if NAICS == 3111
replace NAICS_match ="311200" if NAICS == 3112
replace NAICS_match ="311300" if NAICS == 3113
replace NAICS_match ="311400" if NAICS == 3114
replace NAICS_match ="311500" if NAICS == 3115
replace NAICS_match ="311600" if NAICS == 3116
replace NAICS_match ="311700" if NAICS == 3117
replace NAICS_match ="311800" if NAICS == 3118
replace NAICS_match ="311900" if NAICS == 3119
replace NAICS_match ="312100" if NAICS == 3121
replace NAICS_match ="312200" if NAICS == 3122
replace NAICS_match ="313000" if NAICS == 3131
replace NAICS_match ="313000" if NAICS == 3132
replace NAICS_match ="313000" if NAICS == 3133
replace NAICS_match ="314000" if NAICS == 3141
replace NAICS_match ="314000" if NAICS == 3149
replace NAICS_match ="315000" if NAICS == 3151
replace NAICS_match ="315000" if NAICS == 3152
replace NAICS_match ="315000" if NAICS == 3159
replace NAICS_match ="316000" if NAICS == 3161
replace NAICS_match ="316000" if NAICS == 3162
replace NAICS_match ="316000" if NAICS == 3169
replace NAICS_match ="321100" if NAICS == 3211
replace NAICS_match ="321200" if NAICS == 3212
replace NAICS_match ="321900" if NAICS == 3219
replace NAICS_match ="322100" if NAICS == 3221
replace NAICS_match ="322200" if NAICS == 3222
replace NAICS_match ="323000" if NAICS == 3231
replace NAICS_match ="324000" if NAICS == 3241
replace NAICS_match ="325000" if NAICS == 3251
replace NAICS_match ="325000" if NAICS == 3252
replace NAICS_match ="325000" if NAICS == 3253
replace NAICS_match ="325400" if NAICS == 3254
replace NAICS_match ="325000" if NAICS == 3255
replace NAICS_match ="325000" if NAICS == 3256
replace NAICS_match ="325000" if NAICS == 3259
replace NAICS_match ="326100" if NAICS == 3261
replace NAICS_match ="326200" if NAICS == 3262
replace NAICS_match ="327000" if NAICS == 3271
replace NAICS_match ="327000" if NAICS == 3272
replace NAICS_match ="327000" if NAICS == 3273
replace NAICS_match ="327000" if NAICS == 3274
replace NAICS_match ="327000" if NAICS == 3279
replace NAICS_match ="331100" if NAICS == 3311
replace NAICS_match ="331200" if NAICS == 3312
replace NAICS_match ="331300" if NAICS == 3313
replace NAICS_match ="331400" if NAICS == 3314
replace NAICS_match ="331500" if NAICS == 3315
replace NAICS_match ="332000" if NAICS == 3321
replace NAICS_match ="332000" if NAICS == 3322
replace NAICS_match ="332000" if NAICS == 3323
replace NAICS_match ="332000" if NAICS == 3324
replace NAICS_match ="332000" if NAICS == 3325
replace NAICS_match ="332000" if NAICS == 3326
replace NAICS_match ="332700" if NAICS == 3327
replace NAICS_match ="332800" if NAICS == 3328
replace NAICS_match ="332000" if NAICS == 3329
replace NAICS_match ="333000" if NAICS == 3331
replace NAICS_match ="333000" if NAICS == 3332
replace NAICS_match ="333300" if NAICS == 3333
replace NAICS_match ="333000" if NAICS == 3334
replace NAICS_match ="333500" if NAICS == 3335
replace NAICS_match ="333600" if NAICS == 3336
replace NAICS_match ="333000" if NAICS == 3339
replace NAICS_match ="334100" if NAICS == 3341
replace NAICS_match ="334200" if NAICS == 3342
replace NAICS_match ="334300" if NAICS == 3343
replace NAICS_match ="334400" if NAICS == 3344
replace NAICS_match ="334500" if NAICS == 3345
replace NAICS_match ="334600" if NAICS == 3346
replace NAICS_match ="335100" if NAICS == 3351
replace NAICS_match ="335200" if NAICS == 3352
replace NAICS_match ="335300" if NAICS == 3353
replace NAICS_match ="335900" if NAICS == 3359
replace NAICS_match ="336100" if NAICS == 3361
replace NAICS_match ="336200" if NAICS == 3362
replace NAICS_match ="336300" if NAICS == 3363
replace NAICS_match ="336400" if NAICS == 3364
replace NAICS_match ="336500" if NAICS == 3365
replace NAICS_match ="336600" if NAICS == 3366
replace NAICS_match ="336900" if NAICS == 3369
replace NAICS_match ="337000" if NAICS == 3371
replace NAICS_match ="337000" if NAICS == 3372
replace NAICS_match ="337900" if NAICS == 3379
replace NAICS_match ="339100" if NAICS == 3391
replace NAICS_match ="339900" if NAICS == 3399
replace NAICS_match ="423100" if NAICS == 4231
replace NAICS_match ="423000" if NAICS == 4232
replace NAICS_match ="423000" if NAICS == 4233
replace NAICS_match ="423400" if NAICS == 4234
replace NAICS_match ="423000" if NAICS == 4235
replace NAICS_match ="423000" if NAICS == 4236
replace NAICS_match ="423000" if NAICS == 4237
replace NAICS_match ="423800" if NAICS == 4238
replace NAICS_match ="423000" if NAICS == 4239
replace NAICS_match ="424000" if NAICS == 4241
replace NAICS_match ="424000" if NAICS == 4242
replace NAICS_match ="424300" if NAICS == 4243
replace NAICS_match ="424000" if NAICS == 4244
replace NAICS_match ="424500" if NAICS == 4245
replace NAICS_match ="424000" if NAICS == 4246
replace NAICS_match ="424000" if NAICS == 4247
replace NAICS_match ="424000" if NAICS == 4248
replace NAICS_match ="424000" if NAICS == 4249
replace NAICS_match ="425000" if NAICS == 4251
replace NAICS_match ="441100" if NAICS == 4411
replace NAICS_match ="441200" if NAICS == 4412
replace NAICS_match ="441300" if NAICS == 4413
replace NAICS_match ="44-450" if NAICS == 4421
replace NAICS_match ="44-450" if NAICS == 4422
replace NAICS_match ="44-450" if NAICS == 4431
replace NAICS_match ="444100" if NAICS == 4441
replace NAICS_match ="444200" if NAICS == 4442
replace NAICS_match ="445000" if NAICS == 4451
replace NAICS_match ="445000" if NAICS == 4452
replace NAICS_match ="445300" if NAICS == 4453
replace NAICS_match ="44-450" if NAICS == 4461
replace NAICS_match ="44-450" if NAICS == 4471
replace NAICS_match ="44-450" if NAICS == 4481
replace NAICS_match ="44-450" if NAICS == 4482
replace NAICS_match ="44-450" if NAICS == 4483
replace NAICS_match ="44-450" if NAICS == 4511
replace NAICS_match ="44-450" if NAICS == 4512
replace NAICS_match ="44-450" if NAICS == 4522
replace NAICS_match ="44-450" if NAICS == 4523
replace NAICS_match ="44-450" if NAICS == 4531
replace NAICS_match ="44-450" if NAICS == 4532
replace NAICS_match ="44-450" if NAICS == 4533
replace NAICS_match ="44-450" if NAICS == 4539
replace NAICS_match ="44-450" if NAICS == 4541
replace NAICS_match ="44-450" if NAICS == 4542
replace NAICS_match ="44-450" if NAICS == 4543
replace NAICS_match ="481100" if NAICS == 4811
replace NAICS_match ="481200" if NAICS == 4812
replace NAICS_match ="482000" if NAICS == 4821
replace NAICS_match ="483100" if NAICS == 4831
replace NAICS_match ="483200" if NAICS == 4832
replace NAICS_match ="484000" if NAICS == 4841
replace NAICS_match ="484000" if NAICS == 4842
replace NAICS_match ="485100" if NAICS == 4851
replace NAICS_match ="485200" if NAICS == 4852
replace NAICS_match ="485300" if NAICS == 4853
replace NAICS_match ="485400" if NAICS == 4854
replace NAICS_match ="485500" if NAICS == 4855
replace NAICS_match ="485900" if NAICS == 4859
replace NAICS_match ="486100" if NAICS == 4861
replace NAICS_match ="486200" if NAICS == 4862
replace NAICS_match ="486900" if NAICS == 4869
replace NAICS_match ="487100" if NAICS == 4871
replace NAICS_match ="487200" if NAICS == 4872
replace NAICS_match ="487900" if NAICS == 4879
replace NAICS_match ="488100" if NAICS == 4881
replace NAICS_match ="488200" if NAICS == 4882
replace NAICS_match ="488300" if NAICS == 4883
replace NAICS_match ="488400" if NAICS == 4884
replace NAICS_match ="488500" if NAICS == 4885
replace NAICS_match ="488900" if NAICS == 4889
replace NAICS_match ="491000" if NAICS == 4911
replace NAICS_match ="492100" if NAICS == 4921
replace NAICS_match ="492200" if NAICS == 4922
replace NAICS_match ="493000" if NAICS == 4931
replace NAICS_match ="510000" if NAICS == 5111
replace NAICS_match ="510000" if NAICS == 5112
replace NAICS_match ="512100" if NAICS == 5121
replace NAICS_match ="512200" if NAICS == 5122
replace NAICS_match ="510000" if NAICS == 5151
replace NAICS_match ="510000" if NAICS == 5152
replace NAICS_match ="517000" if NAICS == 5173
replace NAICS_match ="517000" if NAICS == 5174
replace NAICS_match ="517000" if NAICS == 5179
replace NAICS_match ="518000" if NAICS == 5182
replace NAICS_match ="519000" if NAICS == 5191
replace NAICS_match ="519000" if NAICS == 5192
replace NAICS_match ="521000" if NAICS == 5211
replace NAICS_match ="522000" if NAICS == 5221
replace NAICS_match ="522200" if NAICS == 5222
replace NAICS_match ="522000" if NAICS == 5223
replace NAICS_match ="523000" if NAICS == 5231
replace NAICS_match ="523000" if NAICS == 5232
replace NAICS_match ="523000" if NAICS == 5239
replace NAICS_match ="524100" if NAICS == 5241
replace NAICS_match ="524200" if NAICS == 5242
replace NAICS_match ="525100" if NAICS == 5251
replace NAICS_match ="525900" if NAICS == 5259
replace NAICS_match ="531000" if NAICS == 5311
replace NAICS_match ="531000" if NAICS == 5312
replace NAICS_match ="531000" if NAICS == 5313
replace NAICS_match ="532100" if NAICS == 5321
replace NAICS_match ="532000" if NAICS == 5322
replace NAICS_match ="532000" if NAICS == 5323
replace NAICS_match ="532000" if NAICS == 5324
replace NAICS_match ="533000" if NAICS == 5331
replace NAICS_match ="541100" if NAICS == 5411
replace NAICS_match ="541200" if NAICS == 5412
replace NAICS_match ="541300" if NAICS == 5413
replace NAICS_match ="541400" if NAICS == 5414
replace NAICS_match ="541500" if NAICS == 5415
replace NAICS_match ="541600" if NAICS == 5416
replace NAICS_match ="541700" if NAICS == 5417
replace NAICS_match ="541800" if NAICS == 5418
replace NAICS_match ="541900" if NAICS == 5419
replace NAICS_match ="551000" if NAICS == 5511
replace NAICS_match ="561100" if NAICS == 5611
replace NAICS_match ="561200" if NAICS == 5612
replace NAICS_match ="561300" if NAICS == 5613
replace NAICS_match ="561400" if NAICS == 5614
replace NAICS_match ="561500" if NAICS == 5615
replace NAICS_match ="561600" if NAICS == 5616
replace NAICS_match ="561700" if NAICS == 5617
replace NAICS_match ="561900" if NAICS == 5619
replace NAICS_match ="562100" if NAICS == 5621
replace NAICS_match ="562200" if NAICS == 5622
replace NAICS_match ="562900" if NAICS == 5629
replace NAICS_match ="61110P" if NAICS == 6111
replace NAICS_match ="61120P" if NAICS == 6112
replace NAICS_match ="61130P" if NAICS == 6113
replace NAICS_match ="61140P" if NAICS == 6114
replace NAICS_match ="61150P" if NAICS == 6115
replace NAICS_match ="61160P" if NAICS == 6116
replace NAICS_match ="61170P" if NAICS == 6117
replace NAICS_match ="621100" if NAICS == 6211
replace NAICS_match ="621200" if NAICS == 6212
replace NAICS_match ="621300" if NAICS == 6213
replace NAICS_match ="621400" if NAICS == 6214
replace NAICS_match ="621500" if NAICS == 6215
replace NAICS_match ="621600" if NAICS == 6216
replace NAICS_match ="621900" if NAICS == 6219
replace NAICS_match ="62210P" if NAICS == 6221
replace NAICS_match ="62220P" if NAICS == 6222
replace NAICS_match ="62230P" if NAICS == 6223
replace NAICS_match ="623100" if NAICS == 6231
replace NAICS_match ="623200" if NAICS == 6232
replace NAICS_match ="623300" if NAICS == 6233
replace NAICS_match ="623900" if NAICS == 6239
replace NAICS_match ="624100" if NAICS == 6241
replace NAICS_match ="6242-3" if NAICS == 6242
replace NAICS_match ="624300" if NAICS == 6243
replace NAICS_match ="624400" if NAICS == 6244
replace NAICS_match ="711100" if NAICS == 7111
replace NAICS_match ="711200" if NAICS == 7112
replace NAICS_match ="7113-4" if NAICS == 7113
replace NAICS_match ="711400" if NAICS == 7114
replace NAICS_match ="711500" if NAICS == 7115
replace NAICS_match ="712000" if NAICS == 7121
replace NAICS_match ="713100" if NAICS == 7131
replace NAICS_match ="713200" if NAICS == 7132
replace NAICS_match ="713900" if NAICS == 7139
replace NAICS_match ="721100" if NAICS == 7211
replace NAICS_match ="721200" if NAICS == 7212
replace NAICS_match ="721300" if NAICS == 7213
replace NAICS_match ="722300" if NAICS == 7223
replace NAICS_match ="722400" if NAICS == 7224
replace NAICS_match ="722511" if NAICS == 7225
replace NAICS_match ="811100" if NAICS == 8111
replace NAICS_match ="811200" if NAICS == 8112
replace NAICS_match ="811300" if NAICS == 8113
replace NAICS_match ="811400" if NAICS == 8114
replace NAICS_match ="812100" if NAICS == 8121
replace NAICS_match ="812200" if NAICS == 8122
replace NAICS_match ="812300" if NAICS == 8123
replace NAICS_match ="812900" if NAICS == 8129
replace NAICS_match ="813000" if NAICS == 8131
replace NAICS_match ="8132-3" if NAICS == 8132
replace NAICS_match ="813300" if NAICS == 8133
replace NAICS_match ="8134-9" if NAICS == 8134
replace NAICS_match ="813900" if NAICS == 8139
replace NAICS_match ="814000" if NAICS == 8141
replace NAICS_match ="900000" if NAICS == 9211
replace NAICS_match ="900000" if NAICS == 9221
replace NAICS_match ="900000" if NAICS == 9231
replace NAICS_match ="900000" if NAICS == 9241
replace NAICS_match ="900000" if NAICS == 9251
replace NAICS_match ="900000" if NAICS == 9261
replace NAICS_match ="900000" if NAICS == 9271
replace NAICS_match ="900000" if NAICS == 9281
replace NAICS_match ="900000" if NAICS == 9999

replace NAICS_match ="449100" if NAICS == 4491
replace NAICS_match ="449200" if NAICS == 4492
replace NAICS_match ="455000" if NAICS == 4551
replace NAICS_match ="455000" if NAICS == 4552
replace NAICS_match ="456100" if NAICS == 4561
replace NAICS_match ="457100" if NAICS == 4571
replace NAICS_match ="457200" if NAICS == 4572
replace NAICS_match ="458100" if NAICS == 4581
replace NAICS_match ="458200" if NAICS == 4582
replace NAICS_match ="458300" if NAICS == 4583
replace NAICS_match ="459110" if NAICS == 4591
replace NAICS_match ="459200" if NAICS == 4592
replace NAICS_match ="459300" if NAICS == 4593
replace NAICS_match ="4590a1" if NAICS == 4594
replace NAICS_match ="4590a1" if NAICS == 4595
replace NAICS_match ="459900" if NAICS == 4599
replace NAICS_match ="513100" if NAICS == 5131
replace NAICS_match ="513200" if NAICS == 5132
replace NAICS_match ="516100" if NAICS == 5161
replace NAICS_match ="517000" if NAICS == 5171
replace NAICS_match ="517000" if NAICS == 5178


merge m:1 NAICS_match using "`jobtypes'"

drop _merge NAICS_match

save "`path'/Raw_Data/Blue_White_Collar/blue_white_collar.dta", replace 

}



*======================================
**# MERGING EVERYTHING
*======================================
local path "C:/Users/nimen/Documents/USU/My Research/Kat's Inflation Reduction Labor/Master_Folder"

{

* Start from the main (all-ownership) BLS employment dataset
use "`path'/Raw_Data/BLS/countyindustrylevel.dta", clear	

drop if state == 9 
*we drop connecticut from the analysis because the boundaries of their FIPS codes changed in 2024 for the BLS data
*the treatment levels in CT are not statistically different from those of the rest of the sample

* Merge private employment variables (same FIPS×NAICS×qtr×year)
merge 1:1 FIPSQTRYR NAICS using "`path'/Raw_Data/BLS/countyindustrylevel_Private.dta"
drop _merge

* Merge public employment variables (county×qtr×year, no NAICS)
merge m:1 FIPSQTRYR using "`path'/Raw_Data/BLS/countyindustrylevel_Public.dta"
drop _merge

merge m:1 FIPSQTRYR using "`path'/Raw_Data/IRA/Collapsed_IRAspending_P.dta"
drop if _merge == 2
drop _merge

merge m:1 FIPSQTRYR using "`path'/Raw_Data/IRA/Collapsed_IRAspending_H.dta"
drop if _merge == 2
drop _merge

merge m:1 FIPSQTRYR using "`path'/Raw_Data/BEA_GDP/BEA_GDP.dta"
drop if _merge == 2
drop _merge

merge m:1 FIPSQTRYR using "`path'/Raw_Data/Census_Population/Census_Population.dta"
drop if _merge == 2
drop _merge	

merge m:1 FIPSQTRYR using "`path'/Raw_Data/Energy_Communities/All_Energy_Comm.dta"
drop if _merge == 2
drop _merge	

merge m:1 FIPSQTRYR using "`path'/Raw_Data/MSA/MSA_Price_Level.dta"
drop if _merge == 2
drop _merge	

merge m:1 NAICS using "`path'/Raw_Data/Blue_White_Collar/blue_white_collar.dta"
drop if _merge == 2
drop _merge	

}


*======================================
*======================================
**# GENERATING ADDITIONAL VARIABLES FOR ANALYSIS
*======================================
*======================================

{
* drop states 2, 15 (Alska, Hawaii)
* drop state 72 and 78

drop if state==2
drop if state==15
drop if state==72
drop if state==78

drop if substr(FIPS,3,3) == "999"

g lnGDP=ln(Current_GDP)
g lnpop=ln(population)

* generate energy community dummy 
g energycomtemp=1 if coalclose>0 | energycom22==1 | energycom23==1 | energycom24==1
bysort FIPS: egen energycomm=max(energycomtemp)
replace energycomm=0 if energycomm==.
drop energycomtemp
ta energycomm

g coalclosed=(coalclose>0)
ta coalclosed

* variable generation for grants analysis
{

/*
replace AllGovPromised_P=0 if AllGovPromised_P==.
gen govtgrants_nonIRA = AllGovPromised_P - IRA_Promised_P
g lngovtgrants_nonIRA=ln(govtgrants_nonIRA)
g lAllGovPromised=ln(AllGovPromised_P)
g lgovtgrants_IRA=ln(IRA_Promised_P)
*/

replace AllGovAward_P=0 if AllGovAward_P==.
gen govtgrants_nonIRA = AllGovAward_P - IRA_P
g lngovtgrants_nonIRA=ln(govtgrants_nonIRA)
g lAllGovPromised=ln(AllGovAward_P)
g lgovtgrants_IRA=ln(IRA_P)

/*
replace IRA_Promised_P=0 if IRA_Promised_P==.
replace IRA_Promised_alt_P= 0 if IRA_Promised_alt_P==.
replace IRA_Promised_unique_P=0 if IRA_Promised_unique_P==.
*/

replace IRA_P=0 if IRA_P==.
replace IRAalt_P= 0 if IRAalt_P==.
replace IRAunique_P=0 if IRAunique_P==.

/*
bysort NAICS FIPS: egen grantssumalttemp=sum(IRA_Promised_alt_P) if year>2022
bysort NAICS FIPS: egen grantssumtemp=sum(IRA_Promised_P) if year>2022
bysort NAICS FIPS: egen grantssumuniquetemp=sum(IRA_Promised_unique_P) if year>2022
bysort NAICS FIPS: egen grantsalltemp=sum(AllGovPromised_P) if year>2022
*/

bysort NAICS FIPS: egen grantssumalttemp=sum(IRAalt_P) if year>2022
bysort NAICS FIPS: egen grantssumtemp=sum(IRA_P) if year>2022
bysort NAICS FIPS: egen grantssumuniquetemp=sum(IRAunique_P) if year>2022
bysort NAICS FIPS: egen grantsalltemp=sum(AllGovAward_P) if year>2022

/*
bysort  FIPS: egen grantssumalt=max(grantssumalttemp)
bysort  FIPS: egen grantssum=max(grantssumtemp)
bysort  FIPS: egen grantssumunique=max(grantssumuniquetemp)
bysort  FIPS: egen grantsall=max(grantsalltemp)
*/

bysort  FIPS: egen grantssumalt=max(grantssumalttemp)
bysort  FIPS: egen grantssum=max(grantssumtemp)
bysort  FIPS: egen grantssumunique=max(grantssumuniquetemp)
bysort  FIPS: egen grantsall=max(grantsalltemp)

sort FIPS year qtr NAICS
browse FIPS year qtr NAICS IRA_Promised* grants*
drop *temp

g iragrantsshare=grantssumalt/grantsall
*winsor2 iragrantsshare, cut(1, 99) replace
replace iragrantsshar=0 if iragrantsshare==.
su iragrantsshare,d


foreach var of varlist grantssum grantssumalt grantssumunique iragrantsshare {
su `var' if `var'>0, d
g med`var'=`var'>`r(p50)'
g p90`var'=`var'>`r(p90)'
g p75`var'=`var'>`r(p75)'
g p25`var'=`var'<`r(p25)'
g p10`var'=`var'<`r(p10)'
}

g anygovtgrant=(grantssum>0)
ta anygovtgrant

g anygovtgrantalt=(grantssumalt>0)
ta anygovtgrantalt	
	
xtile qgrants = grantssumalt, nq(4)

}

 rename grfirms2022_private  grfirms2022_p
 rename  grempl2022_private grempl2022_p
 rename grtotal_wages2022_private   grtotal_wages2022_p
 rename grweekly_wage2022_private grweekly_wage2022_p

 
}


save "`path'/Master_Data/11.02.26_All_Combined", replace 