clear all

global raw "E:\files\HKU_files\IBGE"
global derived "E:\files\HKU_files\IBGE\derived"
global outdir "E:\files\HKU_files\IBGE\output"

set scheme uncluttered


program main
// 	get_state_abbreviation
	unemployment_calculation
	create_state_year_panel
// 	difference_calculation
end

program get_state_abbreviation

	u "${raw}/pnad_pes_1981_2015_comp81.dta", clear
	
	gen state = ""
	replace state = "AC" if uf == "12"
	replace state = "AL" if uf == "27"
	replace state = "AM" if uf == "13"
	replace state = "AP" if uf == "16"
	replace state = "BA" if uf == "29"
	replace state = "CE" if uf == "23"
	replace state = "DF" if uf == "53"
	replace state = "ES" if uf == "32"
	replace state = "GO" if uf == "52"
	replace state = "MA" if uf == "21"
	replace state = "MG" if uf == "31"
	replace state = "MS" if uf == "50"
	replace state = "MT" if uf == "51"
	replace state = "PA" if uf == "15"
	replace state = "PB" if uf == "25"
	replace state = "PE" if uf == "26"
	replace state = "PI" if uf == "22"
	replace state = "PR" if uf == "41"
	replace state = "RJ" if uf == "33"
	replace state = "RN" if uf == "24"
	replace state = "RO" if uf == "11"
	replace state = "RR" if uf == "14"
	replace state = "RS" if uf == "43"
	replace state = "SC" if uf == "42"
	replace state = "SE" if uf == "28"
	replace state = "SP" if uf == "35"
	replace state = "TO" if uf == "17"
	
	save "${raw}/pnad_pes_1981_2015_comp81.dta", replace

end




program unemployment_calculation

	use "${raw}/pnad_pes_1981_2015_comp81.dta", clear
	
	rename idade age
	rename ano year
	rename tinha_trab_sem had_a_job
	rename tem_carteira_assinada legally_emp
	rename horas_trab_todos_trab workhour_total
	rename tomou_prov_semana job_hunted_past_week
	rename tomou_prov_2meses job_hunted_past_month
	
	gen job_hunted = 1 if job_hunted_past_week == 1 | job_hunted_past_month == 1
	
	
	gen demp = 1 if (had_a_job == 1 | legally_emp == 1 | workhour_total > 0) & age >= 16
	gen dunemp = 1 if (job_hunted == 1 & had_a_job == 0) & age >= 16
	
	gen labor_force = 1 if demp == 1 | dunemp == 1
	
	collapse (sum) demp dunemp labor_force [pw=peso], by(year state)
	
	gen unemp_rate = dunemp / labor_force
	
	hist unemp_rate if year >= 1993

end


program create_state_year_panel

	use "${raw}/pnad_pes_1981_2015_comp81.dta", clear
	
	rename ano year
	rename tinha_outro_trab more_than_one_job
	
//	count if missing(more_than_one_job) 
// 	tab more_than_one_job if year >= 1993
//  4086632 missing value for "more than one job during the reference week"
// 	But only 149106 observations said they do have "more than one job". It's a small fraction. I think if one's occupation is cleaner, no matter what his second job is, he is a cleaner, so no need to drop them.
	
	rename tem_carteira_assinada legally_emp
	rename ocup_sem_nova occup /* ocup_sem_nova is applicable to 2000 year and after */ 
	rename renda_mensal_todos_trab month_income   /* month income in all occupations */
	rename idade age
	rename educa s  /* year of schooling */
	rename horas_trab_todos_trab workh /* working hours in all occupations */
	
	replace deflator = 1 if year == 2015  /* The deflator of obs in year 2015 is missing */
	
// 	deflated income = income / deflator / currency
// 	deflated all income to 2015 
	gen month_inc_def = month_income / deflator / conversor 
	
	gen lninc = ln(month_inc_def)
	
	gen cleaner = 1 if occup == 5142  /* code 5143 is non-existent */
	gen guard = 1 if occup == 5173 | occup == 5174
	
	local groups cleaner guard
	
	foreach group in `groups' {
		gen f`group' = legally_emp if `group' == 1
		gen if`group' = 1 - legally_emp if `group' == 1
	}
	
	
	local groups2 fcleaner ifcleaner fguard ifguard 
	foreach g2 in `groups2' {
		gen lninc_`g2' = lninc if `g2' == 1
		gen age_`g2' = age if `g2' == 1
		gen s_`g2' = s if `g2' == 1
		gen workh_`g2' = workh if `g2' == 1
	}
	
	collapse (mean) fcleaner ifcleaner fguard ifguard lninc_* age_* s_* workh_* [pw=peso] if inrange(year, 2003, 2015), by(year state) 
	
	
	save "${derived}/state_year_panel.dta", replace
	
end
	
	
	
program difference_calculation

	use "${derived}/state_year_panel.dta", clear
	
	local groups cleaner guard
	
	foreach group in `groups' {
		gen dlninc_`group' = lninc_f`group' - lninc_if`group'
		gen dage_`group' = age_f`group' - age_if`group'
		gen ds_`group' = s_f`group' - s_if`group'
		gen dworkh_`group' = workh_f`group' - workh_if`group'
	}
	

	local states AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP
	
	/* ln income difference: formal - informal */
	foreach abb in `states' {
		quietly {
			graph twoway ///
			(line dlninc_cleaner year if state == "`abb'", lcolor(blue) lwidth(medium) lpattern(solid)) ///
			(line dlninc_guard year if state == "`abb'", lcolor(red) lwidth(medium) lpattern(dash)), ///
			xlab(2003(1)2015) ///
            ytitle("ln monthly income Difference") ///
            xtitle("`abb'") ///
            legend(on order(1 2) ///
				label(1 "cleaner") ///
				label(2 "guard") ///
				size(small) ring(0) position(1) col(2) region(lwidth(none))) 
		graph export "${outdir}/income/lninc_`abb'.pdf", replace
		}
	}
	
	
	/* age difference: */
	foreach abb in `states' {
		quietly {
			graph twoway ///
			(line dage_cleaner year if state == "`abb'", lcolor(blue) lwidth(medium) lpattern(solid)) ///
			(line dage_guard year if state == "`abb'", lcolor(red) lwidth(medium) lpattern(dash)), ///
			xlab(2003(1)2015) ///
            ytitle("age Difference") ///
            xtitle("`abb'") ///
            legend(on order(1 2) ///
				label(1 "cleaner") ///
				label(2 "guard") ///
				size(small) ring(0) position(1) col(2) region(lwidth(none))) 
		graph export "${outdir}/age/age_`abb'.pdf", replace
		}
	}
	
	
	/* working hour difference */
	foreach abb in `states' {
		quietly {
			graph twoway ///
			(line dworkh_cleaner year if state == "`abb'", lcolor(blue) lwidth(medium) lpattern(solid)) ///
			(line dworkh_guard year if state == "`abb'", lcolor(red) lwidth(medium) lpattern(dash)), ///
			xlab(2003(1)2015) ///
            ytitle("Working hours Difference") ///
            xtitle("`abb'") ///
            legend(on order(1 2) ///
				label(1 "cleaner") ///
				label(2 "guard") ///
				size(small) ring(0) position(1) col(2) region(lwidth(none))) 
		graph export "${outdir}/working_hour/workh_`abb'.pdf", replace
		}
	}
	
	
	/* years of schooling difference */
	foreach abb in `states' {
		quietly {
			graph twoway ///
				(line ds_cleaner year if state == "`abb'", lcolor(blue) lwidth(medium) lpattern(solid)) ///
				(line ds_guard year if state == "`abb'", lcolor(red) lwidth(medium) lpattern(dash)), ///
				xlab(2003(1)2015) ///
				ytitle("Years of schooling Difference") ///
				xtitle("`abb'") ///
				legend(on order(1 2) ///
					label(1 "cleaner") ///
					label(2 "guard") ///
					size(small) ring(0) position(1) col(2) region(lwidth(none))) 
			graph export "${outdir}/year_of_schooling/s_`abb'.pdf", replace
		}
	}
	
end



main


