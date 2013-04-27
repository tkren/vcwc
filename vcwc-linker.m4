define(`input_files', `ifelse($#, 0, , $#, 1, `include($1)', `include(`$1')input_files(shift($@))')')dnl
