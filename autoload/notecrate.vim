" helper {{{
function! notecrate#get_visual_selection() " {{{
  let [line_start, column_start] = getpos("'<")[1:2]
  let [line_end, column_end] = getpos("'>")[1:2]
  let lines = getline(line_start, line_end)
  if len(lines) == 0
    return ''
  endif
  let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][column_start - 1:]
  return join(lines, "\n")
endfunction

" }}}
function! notecrate#get_word_at_cursor() " {{{
	let l:word = expand('<cWORD>')
	return l:word
endfunction
" }}}
function! notecrate#get_link_at_cursor() " {{{
	let l:regex = '\[\([^\]]*\)\](\([^)]*\))'
	let l:line = getline('.')
	let l:cursor = col('.') - 1
	let l:match = matchstrpos(l:line, l:regex, 0)
	while 1
		if (l:match[1] == -1)
			return ''
		elseif l:match[1] <= l:cursor && l:cursor < l:match[2]
			break
		endif
		let l:match = matchstrpos(l:line, l:regex, l:match[2] + 1)
	endwhile
	let l:matches = matchlist(l:match[0], l:regex)
	return {'text': l:matches[1], 'dest': l:matches[2]}
endfunction

" }}}
function! notecrate#generate_filename() " {{{
	return strftime("%Y%m%d%H%M%S") . ".md"
endfunction

" }}}
function! notecrate#get_title(filename) " {{{
	let l:regex = '^# \(\S.*\)$'
	let l:path = b:notecrate_dir . "/" . a:filename
	let l:lines = readfile(expand(l:path))
	let l:line = matchstr(l:lines, l:regex)
	if l:line != ""
		return matchlist(l:line, l:regex)[1]
	endif
	return ''
endfunction

" }}}
function! notecrate#get_id(filename) " {{{
	return = matchstr(a:filename, '^.*\(\.md$\)\@=')
endfunction

" }}}
function! notecrate#grep(pattern) " {{{
	echom b:notecrate_dir
	let l:files = []
	try
		silent execute  'vimgrep /' . a:pattern . '/j ' . b:notecrate_dir . '/*.md'
	catch /^Vim\%((\a\+)\)\=:E480/   " No Match
	endtry
	for d in getqflist()
		let l:filename = fnamemodify(bufname(d.bufnr), ":t")
		call add(l:files, l:filename)
	endfor
	call uniq(l:files)
	return l:files
endfunction

" }}}
function! notecrate#grep_links(pattern) " {{{
	let l:files = notecrate#grep(a:pattern)
	let l:links = []
	for filename in l:files
		if filename != "index.md"
			let l:title = notecrate#get_title(filename)
			call add(l:links, "* [" . l:title . "](" . filename . ")")
		endif
	endfor
	return sort(l:links)
endfunction

" }}}
function! notecrate#fzf_sink(sink_function) " {{{
	" let l:additional_options = get(a:, 1, {})
	let l:preview_options = {
		\ 'sink'    : function(a:sink_function),
		\ 'down'    : '~40%',
		\ 'dir'     : b:notecrate_dir,
		\ 'options' : ['--exact', '--tiebreak=end']
		\ }
	" call fzf#vim#ag("^(?=.)", fzf#vim#with_preview(l:preview_options))
	call fzf#vim#ag("^# ", fzf#vim#with_preview(l:preview_options))
endfunction

" }}}

" }}}
" folding {{{
function! notecrate#indent_level(lnum) " {{{
    return indent(a:lnum) / &shiftwidth
endfunction

" }}}
function! notecrate#heading_depth(lnum) " {{{
	let l:depth=0
	let l:thisLine = getline(a:lnum)
	if l:thisLine =~ '^#\+\s\+'
		let l:hashCount = len(matchstr(thisLine, '^#\{1,6}'))
		if l:hashCount > 0
			let l:depth = hashCount - 1
		endif
	elseif l:thisLine != ''
		let l:nextLine = getline(a:lnum + 1)
		if l:nextLine =~ '^=\+\s*$'
			let l:depth = 1
		elseif l:nextLine =~ '^-\+\s*$'
			let l:depth = 2
		endif
	endif
	return l:depth
endfunction

" }}}
function! notecrate#nested_markdown_folds(lnum) " {{{
	let l:thisLine = getline(a:lnum)
	let l:thisDepth = notecrate#heading_depth(a:lnum)
	let l:thisIndent = notecrate#indent_level(a:lnum)
	let l:prevLine = getline(a:lnum - 1)
	let l:prevIndent = notecrate#indent_level(a:lnum - 1)
	let l:nextLine = getline(a:lnum + 1)
	let l:nextIndent = notecrate#indent_level(a:lnum + 1)
	let l:nextDepth = notecrate#heading_depth(a:lnum + 1)

	if l:thisLine =~ '^\s*<' && l:prevLine =~ '^\s*$'
		return 1
	endif

	if l:thisLine =~ '^\s*$' && l:prevLine =~ '^\s*<'
		return 0
	endif

	if l:nextLine =~ '^---$' || l:thisLine =~ '^---$'
		return 0
	endif

	if l:thisLine =~ '^\s*$' && l:nextDepth > 0
		return -1
	endif

	if l:thisDepth > 0
		return ">".l:thisDepth
	endif

	if l:nextIndent == l:thisIndent
		return "="
	endif

	if l:nextIndent > l:thisIndent
		let l:dif = l:nextIndent - l:thisIndent
		return "a".l:dif
	endif

	if l:nextIndent < l:thisIndent
		let l:dif = l:thisIndent - l:nextIndent
		return "s".l:dif
	endif

endfunction

" }}}
function! notecrate#fold_text() " {{{
	if getline(v:foldstart) =~ "^\s*<"
		return "<>" . repeat(" ", winwidth(0))
	endif
	let l:ret = repeat(" ", indent(v:foldstart)) . trim(getline(v:foldstart))[0:-1] . " +" . repeat(" ", winwidth(0))
	let l:ret = substitute(l:ret, ' \S\+:\S\+', '', 'g')
	let l:ret = substitute(l:ret, '\*\*', '', 'g')
	return l:ret
endfunction

" }}}

" }}}

" notes {{{
function! notecrate#update_backlinks() " {{{
	let l:filename = expand('%:t')
	if l:filename == "index.md"
		return
	endif
	let l:pattern = '\[[^\]]*\](' . l:filename . ')\(\(.*\n\)*---\)\@='
	let l:links = notecrate#grep_links(l:pattern)
	let l:backlinks = "---\n\n"
	if len(l:links) == 0
		let l:backlinks = l:backlinks . "* [Index](index.md)"
	else
		let l:backlinks = l:backlinks . join(uniq(l:links), "\n") . "\n* [Index](index.md)"
	endif
	call setreg("l", l:backlinks)
	silent execute "normal! /^---\<CR>vG$\"lp"
	silent execute "normal! gg/^# \<CR>jj"
endfunction

" }}}
function! notecrate#apply_template(title) " {{{
	let l:template = "\n# " . a:title . "\n\n\n\n\n---\n\n"
	call setreg("l", l:template)
	silent execute 'normal "lP4j'
	call notecrate#update_backlinks()
endfunction

" }}}
function! notecrate#new_note(title, filename) " {{{
	let l:filename = expand('%:t')
	let l:notecrate_dir = b:notecrate_dir
	let l:notecrate_history = b:notecrate_history
	while !isdirectory(expand(b:notecrate_dir))
		let choice = confirm('', b:notecrate_dir . " does not exist. Create? &Yes\n&No\n")
		if choice == 1
			silent execute "!mkdir " . b:notecrate_dir
		else
			return 0
		endif
	endwhile
	let l:path = b:notecrate_dir . "/" . a:filename
	call add(b:notecrate_history, l:filename)
	silent execute "normal! :w\<CR>:e " . l:path . "\<CR>"
	let b:notecrate_dir = l:notecrate_dir
	let b:notecrate_history = l:notecrate_history
	call notecrate#apply_template(a:title)
	call notecrate#update_backlinks()
	write
endfunction

" }}}
function! notecrate#new_note_from_prompt() " {{{
	let l:title = input("Name of new note? ")
	let l:filename = notecrate#generate_filename()
	call notecrate#new_note(l:title, l:filename)
endfunction

" }}}
function! notecrate#new_note_from_selection() " {{{
	let l:title = notecrate#get_visual_selection()
	let l:filename = notecrate#generate_filename()
	silent execute "normal! :'<,'>s/\\%V.*\\%V/[" . l:title . "](" . l:filename . ")/e\<CR>"
	call notecrate#new_note(l:title, l:filename)
endfunction

" }}}
function! notecrate#delete_note() " {{{
	let l:filename = expand('%:t')
	let l:path = b:notecrate_dir . "/" . l:filename
	let choice = confirm('', "Delete " . l:filename . "? &Yes\n&No\n")
	if choice == 1
		call delete(l:path)
		call notecrate#delete_links(l:filename)
		silent execute "!rm " l:path
		silent execute "normal :bp!\<CR>"
	endif
endfunction

" }}}
function! notecrate#rename_note(new) " {{{
	let l:old = substitute(expand('%:t'), ".md", "", "g")
	let l:new = a:new
	let l:oldpath = b:notecrate_dir."/".l:old.".md"
	let l:newpath = b:notecrate_dir."/".l:new.".md"
	let choice = confirm('', "Rename " . l:old . ".md " . l:new . ".md? &Yes\n&No\n")
	if choice == 1
		silent execute "normal! :!mv " . l:oldpath . " " . l:newpath . "\<CR>"
		call notecrate#open_note(a:new . ".md")
		call notecrate#update_links(l:old, l:new)
		call notecrate#update_backlinks()
	endif
endfunction

" }}}

" }}}
" links {{{
function! notecrate#search_insert_link() " {{{
  call notecrate#fzf_sink('notecrate#insert_link_from_fzf')
endfunction
function! notecrate#insert_link_from_fzf(line)
  let l:filename = substitute(a:line, ":[0-9]\*:[0-9]\*:.\*$", "", "")
  let l:title = notecrate#get_title(filename)
  execute "normal! a[" . l:title . "](" . l:filename . ")\<Esc>"
endfunction

" }}}
function! notecrate#search_insert_link_selection() " {{{
  call notecrate#fzf_sink('notecrate#insert_link_from_fzf_selection')
endfunction
function! notecrate#insert_link_from_fzf_selection(line)
	let l:filename = substitute(a:line, ":[0-9]\*:[0-9]\*:.\*$", "", "")
	let l:title = notecrate#get_visual_selection()
	silent execute "normal! :'<,'>s/\\%V.*\\%V/[" . l:title . "](" . l:filename . ")/e\<CR>"
endfunction

" }}}
function! notecrate#delete_links(filename) " {{{
	execute "!" . g:gsed_command . " -i 's/\\[\\([^]]*\\)\\](" . a:filename . ")/\\1/g' " . b:notecrate_dir . "/*md"
endfunction

" }}}
function! notecrate#update_links(old, new) " {{{
	execute "!" . g:gsed_command . " -i 's/" . a:old . ".md/" . a:new . ".md/g' " . b:notecrate_dir . "/*md"
endfunction

" }}}

" }}}
" navigation {{{
function! notecrate#follow_link() " {{{
	let l:link = notecrate#get_link_at_cursor()"
	if type(l:link) == 4
		if l:link['dest'] =~ '^.*\.md$'
			call notecrate#open_note(l:link['dest'])
		else
			silent execute "!open " . l:link['dest']
		endif
	endif
endfunction

" }}}
function! notecrate#open_note(filename) " {{{
	let l:filename = expand('%:t')
	let l:notecrate_dir = b:notecrate_dir
	let l:notecrate_history = b:notecrate_history
	let l:path = b:notecrate_dir . "/" . a:filename
	let l:reg = getreg('')
	if !filereadable(expand(l:path))
		echo "Note does't exist!"
		return
	endif
	call add(b:notecrate_history, l:filename)
	silent execute "e " . l:path
	let b:notecrate_dir = l:notecrate_dir
	let b:notecrate_history = l:notecrate_history
	" call notecrate#update_backlinks()
	silent execute "normal! /^#\<CR>"
	call setreg('', l:reg)
endfunction

" }}}
function! notecrate#open_index() " {{{
	while !isdirectory(expand(b:notecrate_dir))
		let choice = confirm('', b:notecrate_dir . " does not exist. Create? &Yes\n&No\n")
		if choice == 1
			silent execute "!mkdir " . b:notecrate_dir
		else
			return 0
		endif
	endwhile
	let l:filename = "index.md"
	let l:path = b:notecrate_dir . "/" . l:filename
	if !filereadable(expand(l:path))
		echo "Note does't exist!"
		return
	endif
	silent execute "e " . l:path
	call notecrate#update_backlinks()
	silent execute "normal! /^#\<CR>"
endfunction

" }}}
function! notecrate#open_previous() " {{{
	if len(b:notecrate_history) == 0
		return
	endif
	let l:filename = remove(b:notecrate_history, -1)
	call notecrate#open_note(l:filename)
	call remove(b:notecrate_history, -1)
endfunction

" }}}
function! notecrate#search_open() " {{{
  call notecrate#fzf_sink('notecrate#open_from_fzf')
endfunction
function! notecrate#open_from_fzf(line)
  let filename = substitute(a:line, ":[0-9]\*:[0-9]\*:.\*$", "", "")
  call notecrate#open_note(filename)
endfunction

" }}}

" }}}

" git {{{
function! notecrate#push() " {{{
	execute "normal! :!cd " . b:notecrate_dir . "; git add -A; git commit -m \"autocommit\"; git push;\<CR>"
endfunction

" }}}
function! notecrate#pull() " {{{
	execute "normal! :!cd " . b:notecrate_dir . "; git pull;\<CR>"
endfunction

" }}}

" }}}

function! notecrate#update_mappings() " {{{
	execute 'command! -nargs=1 Rename call notecrate#rename_note(<f-args>)'
	execute 'nnoremap <buffer> <leader>r :Rename<CR>'

	execute 'command! -buffer -nargs=0 Delete call notecrate#delete_note()'
	execute 'nnoremap <buffer> <leader>d :Delete<CR>'

	execute 'command! -buffer -nargs=0 Convert :call notecrate#script("convert")'
	execute 'nnoremap <buffer> <leader>c :Convert<CR>'

	execute 'command! -buffer -nargs=0 Presentation :call notecrate#script("marp")'
	execute 'nnoremap <buffer> <leader>p :Presentation<CR>'

	execute 'command! -buffer -nargs=0 SearchOpen :call notecrate#search_open()'
	execute 'nnoremap <buffer> <leader>o :SearchOpen<CR>'

	execute 'command! -buffer -nargs=0 InsertLink :call notecrate#search_insert_link()'
	execute 'nnoremap <buffer> <leader>i :InsertLink<CR>'

	execute 'command! -buffer -nargs=0 Backlinks :call notecrate#update_backlinks()'
	execute 'nnoremap <buffer> <leader>b :Backlinks<CR>'

	execute 'command! -buffer -nargs=0 New :call notecrate#new_note_from_prompt()'
	execute 'nnoremap <buffer> <leader>n :New<CR>'

	execute 'command! -buffer -nargs=0 Push :call notecrate#push()'
	execute 'nnoremap <buffer> <leader>s :Push<CR>'

	execute 'command! -buffer -nargs=0 Pull :call notecrate#pull()'
	execute 'nnoremap <buffer> <leader>u :Pull<CR>'

	execute 'command! -buffer -nargs=0 Follow :call notecrate#follow_link()'
	execute 'nnoremap <buffer> <CR> :Follow<CR>'

	execute 'nnoremap <buffer> <backspace> :call notecrate#open_previous()<CR>'

	execute 'nnoremap <buffer> <S-j> /\[[^\]]*\]([^)]*)<CR>:noh<CR>'
	execute 'nnoremap <buffer> <S-l> /\[[^\]]*\]([^)]*)<CR>:noh<CR>'
	execute 'nnoremap <buffer> <Tab> /\[[^\]]*\]([^)]*)<CR>:noh<CR>'
	execute 'nnoremap <buffer> <S-Tab> /\[[^\]]*\]([^)]*)<CR>NN:noh<CR>'
	execute 'nnoremap <buffer> <S-h> /\[[^\]]*\]([^)]*)<CR>NN:noh<CR>'
	execute 'nnoremap <buffer> <S-k> /\[[^\]]*\]([^)]*)<CR>NN:noh<CR>'

	execute 'command! -buffer -nargs=0 Insert :call notecrate#search_insert_link_selection()'
	execute 'vnoremap <buffer> <leader>i :Insert<CR>'

	execute 'vnoremap <buffer> <CR> :call notecrate#new_note_from_selection()<CR>'

	execute 'inoremap <buffer> <Tab> <C-t>'
	execute 'inoremap <buffer> <S-Tab> <C-d>'

endfunction

" }}}
function! notecrate#update_syntax() " {{{
	execute 'setlocal textwidth=79'
	execute 'setlocal autowriteall'
	execute 'setlocal comments+=b:*'
	execute 'setlocal foldlevel=3'
	execute 'setlocal foldmethod=expr'
	execute 'setlocal foldexpr=notecrate#nested_markdown_folds(v:lnum)'
	execute 'setlocal foldtext=notecrate#fold_text()'
	execute 'setlocal conceallevel=2'
	execute 'setlocal concealcursor='
	execute 'setlocal wrap'

	execute 'syn match NotecrateLinkInternal /\(\](\)\@<=[^()]*\()\)\@=/'
	execute 'hi def link NotecrateLinkInternal Identifier'

	execute 'syn match NotecrateBoldConceal /\*\*/ conceal containedin=ALL'

	execute 'syn match NotecrateLinkConceal /!*\[\+\([^\]]*](\)\@=/ conceal'
	execute 'syn match NotecrateLinkConceal /\]\+\((\)\@=/ conceal'
	execute 'syn match NotecrateLinkConceal /\(\[[^\]]*\]\)\@<=([^)]*)/ conceal contains=NotecrateLinkInternal'
	execute 'hi def link NotecrateLinkConceal Comment'

	execute 'syn match NotecrateLink /\(\[\)\@<=[^\[\]]*\(\](\)\@=/'
	execute 'hi def link NotecrateLink Identifier'

	execute 'syn match NotecrateLinkImage /!\[\]/ containedin=ALL'
	execute 'hi def link NotecrateLinkImage Constant'

	execute 'syn match NotecrateHeader1 /\(^# \)\@<=.*/'
	execute 'hi def link NotecrateHeader1 Title'

	execute 'syn match NotecrateHeader2 /\(^##\+ \)\@<=.*/'
	execute 'hi def link NotecrateHeader2 Title'

	execute 'syn match NotecrateRule /^---\+/'
	execute 'hi def link NotecrateRule Comment'

	execute 'syn region NotecrateFrontCustomMatter start=/\%^---/ end=/^---/'
	execute 'hi def link NotecrateFrontCustomMatter Comment'

	execute 'syn region NotecrateCode start=/^```/ end=/^```/'
	execute 'hi def link NotecrateCode String'

	execute 'syn region NotecrateBold start=/\*\*/ end=/\*\*/ contains=NotecrateBoldConceal keepend'
	execute 'hi def link NotecrateBold Bold'

	execute 'syn match NotecrateQuote /^>.*$/'
	execute 'hi def link NotecrateQuote PreProc'

	execute 'syn match NotecrateTag /#[^# ]\S*/'
	execute 'hi def link NotecrateTag Identifier'

	execute 'syn match NotecrateDone /#DONE/ containedin=NotecrateTag'
	execute 'hi def link NotecrateDone Statement'

	execute 'syn match NotecrateTodo /#TODO/ containedin=NotecrateTag'
	execute 'hi def link NotecrateTodo Error'

endfunction

" }}}

function! notecrate#script(name) " {{{
	let l:script = g:todo_plugin_dir . "/scripts/" . a:name . ".sh"
	let l:dir = getcwd()
	let l:file = expand('%:t')
	execute "cd " . b:notecrate_dir
	execute "!bash " . l:script . " " . l:file
	execute "cd " . l:dir
endfunction

" }}}
