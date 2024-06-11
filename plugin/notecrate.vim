if !exists("g:notecrate_dirs")
    let g:notecrate_dirs = {
		\ "notes": { "prefix": "n", "dir": "~/notecrate"}
		\ }
endif

let g:todo_plugin_dir = expand("<sfile>:p:h:h")

for [key, value] in items(g:notecrate_dirs)
	silent execute "autocmd BufRead,BufNewFile " . value["dir"] . "/*.md set filetype=notecrate syntax=notecrate"
	silent execute "normal! :nnoremap <leader>w" . value["prefix"] . " :e " . value["dir"] . "/index.md<CR>:let b:notecrate_dir = \"" . value["dir"] . "\"<CR>:let b:notecrate_history = []<CR>\<CR>"
	let current_dir = expand('%:~:h')
	if current_dir == value["dir"]
		if !exists("b:notecrate_dir")
			let b:notecrate_dir = value["dir"]
		endif
		if !exists("b:notecrate_history")
			let b:notecrate_history = []
		endif
	endif
endfor
