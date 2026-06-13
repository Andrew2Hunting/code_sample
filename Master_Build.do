clear all

*Change to local directory for Main folder
local path "C:\Users\nimen\Desktop\Main"


*======================================
**# IRA
*======================================

{	
	*The USA grant data can be found at https://www.usaspending.gov/download_center/award_data_archive by downloading the FY####_All_Contracts_Full_########.zip file filtered by Agency - "All", Award Type - "Financial Assistance", for fiscal years 2018 to 2025. 
	*This .do can replicate the dataset as long as all of the .csv files are unzipped and placed in the same "Award_Spending_Download" folder (The organization of the subfolders does not matter) 


*prepare sub award data format to merge 
*this is necessary to connect each prime award with its corresponding sub award amount totals
import delimited using "`path'\Raw_Data\IRA\all_subawards_results_API.csv" , clear delimiter(comma) bindquote(strict) emptylines(include) encoding(UTF-8) maxquotedrows(unlimited)
collapse (sum) subawardamount, by(primeawardid)
rename primeawardid award_id
rename subawardamount lifetime_s
tempfile sub_lifetime
save "`sub_lifetime'"

*prepare sub award data to append
import delimited using "`path'\Raw_Data\IRA\all_subawards_results_API.csv" , clear delimiter(comma) bindquote(strict) emptylines(include) encoding(UTF-8) maxquotedrows(unlimited)
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


clear
cd "`path'\Raw_Data\IRA\Award_Spending_Download"
*cd "`path'/Raw_Data/IRA/Award_Spending_Download"

* Build a list of all CSV files in the directory
ssc install filelist
filelist, list directory()
tempfile ListCsv
save "`ListCsv'"
  
local obs = _N

forvalues i=1/`obs' {
	use "`ListCsv'" in `i', clear
	local f = dirname + "\" + filename
	*local f = dirname + "/" + filename
	import delimited using "`f'", clear delimiter(comma) bindquote(strict) emptylines(include) encoding(UTF-8) maxquotedrows(unlimited)
	keep assistance_award_unique_key award_id_fain award_id_uri modification_number federal_action_obligation total_obligated_amount total_outlayed_amount_for_overal action_date action_date_fiscal_year period_of_performance_start_date period_of_performance_current_en treasury_accounts_funding_this_a program_activities_funding_this_ prime_award_transaction_recipien prime_award_transaction_place_of cfda_number assistance_type_code prime_award_base_transaction_des business_types_code action_type_code record_type_code business_types_description recipient_name
	
	drop if federal_action_obligation <= 0
	
	gen award_id = award_id_fain
	replace award_id = award_id_uri if award_id == ""
	drop award_id_fain award_id_uri

	* Create IRA identifiers based on description and program activity strings
	gen IRA1 = strpos(prime_award_base_transaction_des, " IRA ") > 0
	gen IRA2 = strpos(prime_award_base_transaction_des, "INFLATION REDUCTION ACT") > 0
	gen IRA3 = strpos(program_activities_funding_this_, "INFLATION REDUCTION ACT") > 0
	gen IRA4 = strpos(program_activities_funding_this_, " IRA ") > 0


	* Create IRA5 identifier based on CFDA numbers with start year >= 2023
	gen IRA5 = 0
	gen startyear = substr(period_of_performance_start_date, 1, 4)
	destring startyear, replace

	replace IRA5 = 1 if cfda_number == float(10.708) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.724) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.727) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.728) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.729) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.731) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.734) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.754) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.757) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.758) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.868) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.912) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.924) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.932) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.968) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(10.984) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(11.017) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(11.417) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(11.44)  & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(11.473) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(14.021) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(14.239) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(15.165) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(15.514) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(15.567) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(15.575) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(15.577) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(15.654) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(20.115) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(20.205) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.034) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.039) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.04)  & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.046) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.047) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.049) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.203) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.306) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.312) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.6)   & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.614) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.615) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.616) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.721) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.957) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.959) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(66.96)  & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(81.041) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(81.087) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(81.089) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(81.117) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(81.253) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(81.254) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(81.256) & startyear >= 2023
	replace IRA5 = 1 if cfda_number == float(93.581) & startyear >= 2023

	* Create IRA_unique identifier for CFDA numbers exclusively tied to the IRA
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
collapse (first) total_obligated_amount total_outlayed_amount_for_overal period_of_performance_start_date period_of_performance_current_en recipient_name assistance_type_code business_types_code business_types_description action_type_code record_type_code startyear IRA IRAalt IRAunique, by(award_id)

merge 1:m award_id using "`subdata'"
keep if _merge == 3
gen action_date_fiscal_year = substr(action_date, 1, 4)
destring action_date_fiscal_year, replace
replace IRA = federal_action_obligation if IRA > 0 
replace IRAalt = federal_action_obligation if IRAalt > 0 
replace IRAunique = federal_action_obligation if IRAunique > 0 


append using "`prime_awards_only'"


* Navigate to Master Data folder
cd "`path'\Master_Data"
*cd "`path'/Master_Data"

* Save a copy of IRA-only awards before further processing
preserve
keep if IRA != 0 
save AllIraSpending, replace
restore

* Create quarter variable from action date
gen month = substr(action_date, 6, 2)
gen quarter = "."
replace quarter = "1" if month == "01" | month == "02" | month == "03"
replace quarter = "2" if month == "04" | month == "05" | month == "06"
replace quarter = "3" if month == "07" | month == "08" | month == "09"
replace quarter = "4" if month == "10" | month == "11" | month == "12"


*Collapse data based on the two possible ways of identifying the location of the spending: first the location of the place of performance, then the location based on where the recipient is located (Headquarters)

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

* Create FIPSQTRYR panel key
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
rename IRA_Promised_alt IRA_Promised_alt_p
rename IRA_Outlayed_unique IRA_Outlayed_unique_P
rename IRA_Promised_unique IRA_Promised_unique_P 
rename IRA_Outlayed IRA_Outlayed_P 
rename IRA_Promised IRA_Promised_p

cd "`path'\Raw_Data\IRA"
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

* Create FIPSQTRYR panel key
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

cd "`path'\Raw_Data\IRA"
save Collapsed_IRAspending_H, replace 

}

*======================================
**# BEA GDP
*======================================

{
* The BEA GDP data is categorized by county.
* Source file: CAGDP1__ALL_AREAS_2001_2022.csv
* NOTE: After reshape, year = j + 1992. This assumes the wide columns are v1–v30
* (years 1993–2022). Verify with: assert year >= 1993 & year <= 2022

*import delimited "`path'/Raw_Data/BEA_GDP/CAGDP1__ALL_AREAS_2001_2022.csv", ///
	clear varnames(1)
import delimited "`path'\Raw_Data\BEA_GDP\CAGDP1__ALL_AREAS_2001_2022.csv", ///
	clear varnames(1)

* Keep only relevant data
drop region tablename linecode industryclassification
keep if unit == "Thousands of dollars"


* Reshape from wide (one column per year) to long
* Verify column names before reshaping: ds v*
reshape long v, i(geofips) j(year)

* Rename and fix year offset
rename v       Current_GDP
rename geofips FIPS
replace year = year + 1992

*Remove state and US aggregate
replace FIPS = substr(FIPS,3,5)
drop if substr(FIPS,3,3) == "000"

replace Current_GDP = "0" if Current_GDP =="(NA)"

* Sanity check on year range
assert year >= 1993 & year <= 2022

* Create qtr and FIPSQTRYR
gen unq = _n
expand 4 
bysort unq: gen qtr = _n


tostring FIPS qtr year, replace
gen FIPSQTRYR = FIPS + qtr + year
sort FIPSQTRY
drop FIPS year geoname description unit qtr unq
destring Current_GDP, replace 

save "`path'\Raw_Data\BEA_GDP\BEA_GDP.dta", replace
} 

*======================================
**# CENSUS POPULATION
*======================================

{	
* The Census Population data is categorized by county.
* Merges two Excel files: 2010–2020 and 2020–2024.


* Load 2010–2020 population file
*import excel "`path'/Raw_Data/Census_Population/2010-2020 pop.xlsx", ///
	firstrow clear
import excel "`path'\Raw_Data\Census_Population\2010-2020 pop.xlsx", ///
	firstrow clear
drop if missing(FIPS)
tempfile temp1
save `temp1'

* Load 2020–2024 population file and merge with 2010–2020
*import excel "`path'/Raw_Data/Census_Population/2020-2024 pop.xlsx", ///
	firstrow clear
import excel "`path'\Raw_Data\Census_Population\2020-2024 pop.xlsx", ///
	firstrow clear
drop if missing(FIPS)
merge 1:1 FIPS using `temp1'

* Drop redundant Census benchmark columns
drop April12010EstimatesBase April12020EstimatesBase April12020census

* NOTE: Column letters D–M map to years from the merged Excel layout.
* From 2020–2024 file: D=2020, E=2021, F=2022, G=2023, H=2024
* From 2010–2020 file: I=2015, J=2016, K=2017, L=2018, M=2019
* Verify this mapping matches your actual Excel column headers before running.
rename D y2020
rename E y2021
rename F y2022
rename G y2023
rename H y2024
rename I y2015
rename J y2016
rename K y2017
rename L y2018
rename M y2019

* Reshape to long format
reshape long y, i(FIPS) j(year)
rename y population

*Drop US aggregate
replace FIPS = substr(FIPS,3,5)
drop if FIPS == "00000"

* Create FIPSQTRYR (population is annual; assign to Q4 as convention)
gen unq = _n
expand 4 
bysort unq: gen qtr = _n
tostring FIPS qtr year, replace
gen FIPSQTRYR = FIPS + qtr + year
sort FIPSQTRYR

drop FIPS year geoname _merge qtr unq 

*save "`path'/Raw_Data/Census_Population/Census_Population.dta", replace
save "`path'\Raw_Data\Census_Population\Census_Population.dta", replace
tempfile Census_Population	
save "`Census_Population'"	
****************************************************************************
} 

*======================================
**# ENERGY COMMUNITIES
*======================================

{
* ======================================
**# COAL ADJACENT
* ======================================
*This data can be retrieved from https://home.treasury.gov/policy-issues/tax-policy/data-transparency/all-treasury-generated-energy-communities-data-sets as of 3/5/2026
	
import excel "`path'\Raw_Data\Energy_Communities\EC_AllTracts_V4.xlsx", sheet("EC_AllTracts_V4") clear
*import excel "`path'/Raw_Data/Energy_Communities/EC_AllTracts_V4.xlsx", sheet("EC_AllTracts_V4") clear

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
import excel "`path'\Raw_Data\Energy_Communities\EC_MSA_FFE_U2022_AllCounties.xlsx", sheet("EC_MSA_FFE_U2022_AllCounties") clear
*import excel "`path'/Raw_Data/Energy_Communities/EC_MSA_FFE_U2022_AllCounties.xlsx", sheet("EC_MSA_FFE_U2022_AllCounties") clear

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


import excel "`path'\Raw_Data\Energy_Communities\EC_MSA_FFE_U2023_AllCounties.xlsx", sheet("EC_MSA_FFE_U2023_AllCounties_V1") clear
*import excel "`path'/Raw_Data/Energy_Communities/EC_MSA_FFE_U2023_AllCounties.xlsx", sheet("EC_MSA_FFE_U2023_AllCounties_V1") clear

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


import excel "`path'\Raw_Data\Energy_Communities\EC_MSA_FFE_U2024_AllCounties.xlsx", sheet("EC_MSA_FFE_U2024_AllCounties") clear
*import excel "`path'/Raw_Data/Energy_Communities/EC_MSA_FFE_U2024_AllCounties.xlsx", sheet("EC_MSA_FFE_U2024_AllCounties") clear

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

*save "`path'/Raw_Data/Energy_Communities/All_Energy_Comm.dta", replace
save "`path'\Raw_Data\Energy_Communities\All_Energy_Comm.dta", replace

}



*======================================
*======================================
**# MSA PRICE LEVEL
*======================================
*======================================

{
	
*prepare MSA to FIPS crosswalk
import delimited "`path'\Raw_Data\MSA\crosswalk.csv", clear varnames(1)
*import delimited "`path'/Raw_Data/MSA/crosswalk.csv", clear varnames(1)

tostring fipstate fipscty, replace 
replace fipscty = "0" + fipscty if strlen(fipscty) < 3
replace fipscty = "0" + fipscty if strlen(fipscty) < 3
gen FIPS = fipstate + fipscty
drop msa_name fipstate fipscty county_name
destring FIPS, replace 	
	
tempfile crosswalk
save "`crosswalk'"
	
* Convert .csv into .dta
import delimited "`path'\Raw_Data\MSA\Table.csv", clear varnames(1)
*import delimited "`path'/Raw_Data/MSA/Table.csv", clear varnames(1)
*save "MSA Price Level.dta", replace	

* Drop irrelevant data
keep if description == "RPPs: All items"
rename geofips msa
*add FIPS codes
merge 1:m msa using "`crosswalk'"
drop if _merge == 1
drop _merge

* Reshape data
reshape long v, i(FIPS) j(year)

* Rename data and fix year
rename v RPPs
label variable RPPs "Regional Price Parities"
destring msa, replace
replace year = year + 2013

* Create qtr and FIPSQTRYR
gen unq = _n
expand 4 
bysort unq: gen qtr = _n
tostring FIPS qtr year, replace
gen FIPSQTRYR = FIPS + qtr + year
sort FIPSQTRYR
drop FIPS year msa geoname linecode description qtr unq

cd "`path'\Raw_Data\MSA"
*cd "`path'/Raw_Data/MSA"
save "MSA_Price_Level.dta", replace	
tempfile MSA_Price_Level
save "`MSA_Price_Level'"
}


*======================================
**# MERGING EVERYTHING
*======================================

clear all 
local path "C:\Users\nimen\Desktop\Main"

{
use "`path'\Raw_Data\IRA\Collapsed_IRAspending_P.dta", clear	

merge 1:1 FIPSQTRYR using "`path'\Raw_Data\IRA\Collapsed_IRAspending_H.dta"
keep if _merge == 1 | _merge == 3
drop _merge

merge 1:1 FIPSQTRYR using "`path'\Raw_Data\BEA_GDP\BEA_GDP.dta"
keep if _merge == 1 | _merge == 3
drop _merge

merge 1:1 FIPSQTRYR using "`path'\Raw_Data\Census_Population\Census_Population.dta"
keep if _merge == 1 | _merge == 3
drop _merge	

gen FIPS = substr(FIPSQTRYR,1,5)

merge m:1 FIPS using "`path'\Raw_Data\Energy_Communities\All_Energy_Comm.dta"
keep if _merge == 1 | _merge == 3
drop _merge	

merge 1:1 FIPSQTRYR using "`path'\Raw_Data\MSA\MSA_Price_Level.dta"
keep if _merge == 1 | _merge == 3
drop _merge	

g lnGDP=ln(Current_GDP)
g lnpop=ln(population)


cd "`path'\Master_Data"
save All_Combined, replace 

}

