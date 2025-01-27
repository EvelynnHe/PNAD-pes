clear all



program main
// 	get_state_abbreviation
	create_mean_std
	controlled_difference
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




program create_mean_std

	use "${raw}/pnad_pes_1981_2015_comp81.dta", clear
	
	rename ano year
	rename tinha_outro_trab more_than_one_job
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
	
//	wage = income/ hour
	gen wage = month_inc_def / workh
	gen lnwage = ln(wage)
	
	gen male = .
	replace male = 1 if sexo == 1
	replace male = 0 if sexo == 0
	
	gen female = .
	replace female = 1 if sexo == 0
	replace female = 0 if sexo == 1
	
	gen nonwhite = .
	replace nonwhite = 1 if inlist(cor, 4, 6, 8, 0)
	replace nonwhite = 0 if inlist(cor, 2)
	
	gen type = ""
	replace type = "cleaner" if occup == 5142  /* code 5143 is non-existent */
	replace type = "guard" if occup == 5173 | occup == 5174 
	
	gen informal = . 
	replace informal = 1 if legally_emp == 0
	replace informal = 0 if legally_emp == 1
	
	collapse (mean) mean_age=age (mean) mean_s=s (mean) mean_male=male (mean) mean_nonwhite=nonwhite ///
        (mean) mean_workh=workh (mean) mean_lnwage=lnwage ///
        (sd) sd_age=age (sd) sd_s=s (sd) sd_male=male (sd) sd_nonwhite=nonwhite ///
        (sd) sd_workh=workh (sd) sd_lnwage=lnwage ///
        [fw=peso] if inrange(year, 2003, 2010), by(informal type)
	
end
	



program controlled_difference
	/* make formal and informal comparison with controlled variables */
	
	use "${raw}/pnad_pes_1981_2015_comp81.dta", clear
	
	rename ano year
	rename tem_carteira_assinada legally_emp
	rename ocup_sem_nova occup 
	rename renda_mensal_todos_trab month_income   
	rename idade age
	rename educa s  
	rename horas_trab_todos_trab workh 
	
	replace deflator = 1 if year == 2015  

	gen month_inc_def = month_income / deflator / conversor 
	
	gen wage = month_inc_def / workh
	gen lnwage = ln(wage)
	
	gen male = .
	replace male = 1 if sexo == 1
	replace male = 0 if sexo == 0
	
	gen nonwhite = .
	replace nonwhite = 1 if inlist(cor, 4, 6, 8, 0)
	replace nonwhite = 0 if inlist(cor, 2)
	
	gen cleaner = 1 if occup == 5142  
	gen guard = 1 if occup == 5173 | occup == 5174
	
	gen informal = . 
	replace informal = 1 if legally_emp == 0
	replace informal = 0 if legally_emp == 1
	
	keep if year >= 2003 & (cleaner == 1 | guard == 1)
	keep year state cleaner guard informal age s male nonwhite workh lnwage peso
	
	gen age2 = age ^ 2
	
	encode state, gen(state_num)  /* convert state from string type to num */
	
	cap log close
	log using "${outdir}/reg_ctrldifference.log", replace 
	
	global convars age s male nonwhite workh 
	
	display "cleaner"
	foreach var in $convars {
		
		reg `var' informal i.year i.state_num if cleaner == 1 & inrange(year, 2003, 2010) [pw=peso], robust
	}
	
	display "guard"
	foreach var in $convars {
		
		reg `var' informal i.year i.state_num if guard == 1 & inrange(year, 2003, 2010) [pw=peso], robust
	}
	
	reg lnwage informal age age2 s male nonwhite i.year i.state_num if cleaner == 1 & inrange(year, 2003, 2010) [pw=peso], robust
	
	reg lnwage informal age age2 s male nonwhite i.year i.state_num if guard == 1 & inrange(year, 2003, 2010) [pw=peso], robust

	log close
	
		
end



main


