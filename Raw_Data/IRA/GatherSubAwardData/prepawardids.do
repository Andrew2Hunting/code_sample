clear all
		
local path "C:\Users\nimen\Documents\USU\My Research\Kat's Inflation Reduction Labor\Master_Folder"
	
cd "`path'\Raw_Data\IRA\Award_Spending_Download"

filelist, list directory()
tempfile ListCsv
save "`ListCsv'"
  
local obs = _N

clear
tempfile master_ids
save `master_ids', emptyok replace

forvalues i=1/`obs' {
	use  "`ListCsv'" in `i', clear
    local f = dirname + "\" + filename	
	import delimited using "`f'" , clear delimiter(comma) bindquote(strict) emptylines(include) encoding(UTF-8) maxquotedrows(unlimited)
	keep award_id_fain award_id_uri federal_action_obligation prime_award_base_transaction_des program_activities_funding_this_ period_of_performance_start_date cfda_number 
	
	
*removing loan-only line items
drop if federal_action_obligation <= 0	

*make unique id
gen award_id = award_id_fain
replace award_id = award_id_uri if award_id == ""
drop award_id_fain award_id_uri
	
*make ira identifier
gen IRA1 = strpos( prime_award_base_transaction_des , " IRA ") > 0
gen IRA2 = strpos( prime_award_base_transaction_des , "INFLATION REDUCTION ACT") > 0
gen IRA3 = strpos( program_activities_funding_this_ , "INFLATION REDUCTION ACT") > 0
gen IRA4 = strpos( program_activities_funding_this_ , " IRA ") > 0

gen IRA5 = 0
gen startyear = substr(period_of_performance_start_date,1,4 )
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
replace IRA5 = 1 if cfda_number == float(11.44) & startyear >= 2023
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
replace IRA5 = 1 if cfda_number == float(66.04) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.046) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.047) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.049) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.203) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.306) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.312) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.6) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.614) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.615) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.616) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.721) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.957) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.959) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(66.96) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(81.041) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(81.087) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(81.089) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(81.117) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(81.253) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(81.254) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(81.256) & startyear >= 2023
replace IRA5 = 1 if cfda_number == float(93.581) & startyear >= 2023


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

gen IRA = 0
replace IRA = 1 if IRA1 == 1 | IRA2 == 1 | IRA3 == 1 | IRA4 == 1 | IRA5 == 1 | IRA_unique == 1


keep award_id IRA

duplicates drop award_id, force

compress

append using `master_ids'

duplicates drop award_id, force
save `master_ids', replace

  
		}
 

 keep if IRA == 1


export delimited using `"C:\Users\nimen\Documents\USU\My Research\Kat's Inflation Reduction Labor\Master_Folder\Raw_Data\IRA\GatherSubAwardData\awardids.csv"', replace

