" Changed
"
" Description:
"   Displays signs on changed lines.
" Last Change: 2018-8-15
" Maintainer: Shuhei Kubota <kubota.shuhei+vim@gmail.com>
" Requirements:
"   * +signs (appears in :version)
"   * diff command
"   * setting &termencoding
" Installation:
"   Just source this file. (Put this file into the plugin directory.)
" Usage:
"   [Settings]
"
"   1. Setting &termencoding
"       Set &termencoding option according to your terminal encoding. 
"       Its default value is same as &encoding.
"       example:
"           set termencoding=cp932
"
"   2. Changing signs
"       To change signs, re-define signs after sourcing this script.
"       example (changing text):
"           sign define SIGN_CHANGED_DELETED_VIM text=D texthl=ChangedDefaultHl
"           sign define SIGN_CHANGED_ADDED_VIM   text=A texthl=ChangedDefaultHl
"           sign define SIGN_CHANGED_VIM         text=M texthl=ChangedDefaultHl
"       example (changin highlight @gvimrc):
"           highlight ChangedDefaultHl cterm=bold ctermbg=red ctermfg=white gui=bold guibg=red guifg=white
"
"   [Usual]
"
"   Edit a buffer and wait seconds or execute :Changed.
"   Then signs appear on changed lines.
"

command!  Changed       :call <SID>Changed_execute()
command!  ChangedClear  :call <SID>Changed_clear()

au! BufReadPost * Changed
au! BufWritePost * Changed
" au! CursorHold   * Changed
" au! CursorHoldI  * Changed
" heavy
" au! Inserteave * Changed
" too heavy
"au! CursorMoved * Changed
au! TextChanged * Changed
au! TextChangedI * Changed

let s:STARTID=30999

if !exists('g:Changed_definedSigns')
    let g:Changed_definedSigns = 1
"    highlight ChangedDefaultHl cterm=bold ctermbg=yellow ctermfg=black gui=bold guibg=yellow guifg=black
"    highlight ChangedDefaultHl cterm=bold ctermbg=green ctermfg=black gui=bold guibg=green guifg=black
"    highlight ChangedDefaultHl cterm=bold ctermbg=red ctermfg=white gui=bold guibg=red guifg=white
    highlight ChangedDefaultHl cterm=bold ctermbg=blue ctermfg=white gui=bold guibg=blue guifg=white
    sign define SIGN_CHANGED_DELETED_VIM text=- texthl=ChangedDefaultHl
    sign define SIGN_CHANGED_ADDED_VIM 	 text=+ texthl=ChangedDefaultHl
    sign define SIGN_CHANGED_VIM 		 text=* texthl=ChangedDefaultHl
    sign define SIGN_CHANGED_NONE
endif

function! s:Changed_clear()
    if exists('b:signId')
	let i = s:STARTID
        while b:signId >= i
            execute 'sign unplace ' . i . ' buffer=' . bufnr('%')
	    let i = i + 1
        endwhile
    endif
    if exists('b:signId') | unlet b:signId | endif

    " かえって重くなった
    " let bufinfo = getbufinfo(bufnr('%'))
    " if len(bufinfo) == 1 && has_key(bufinfo[0], "signs")
	"     for sign in bufinfo[0].signs
	" 	    if len(sign.name) >= 12 && sign.name[0:11] == 'SIGN_CHANGED'
	" 		    execute 'sign unplace ' . sign.id . ' buffer=' . bufnr('%')
	" 	    endif
	"     endfor
    " endif
endfunction

function! s:GetPlacedSignsDic(buffer)
    let placedstr = ''
    redir => placedstr
        silent execute "sign place buffer=".a:buffer
    redir END
    let dic ={}
    let signPlaceLines = split(placedstr, '\n')
    for line in signPlaceLines
        if match(line, "SIGN_CHANGED_") > 0
            let lineNum = matchstr(line, '\v^ {1,}\D{1,}\zs\d{1,}\ze\D.*')
            if ! empty(lineNum)
                let id = matchstr(line, '\v\D{1,}\d{1,}\D{1,}\zs\d{1,}\ze\D.*')
                let name = matchstr(line, '\v\D{1,}\d{1,}\D{1,}\d{1,} [^\=]{1,}\=\zs.{1,}\ze')
                if ! has_key(dic, lineNum)
                    let dic[lineNum] = {}
                endif
                let dic[lineNum][id] = name
           endif
        endif
    endfor
    return dic
endfunction

function! s:Changed_execute()

    if !&modified
        call s:Changed_clear()
        return
    endif

    " get paths
    let originalPath = substitute(expand('%:p'), '\', '/', 'g')
    let b:changedPath = substitute(tempname(), '\', '/', 'g')

    " both files are not saved -> don't diff
    if ! filereadable(originalPath) | return | endif

    " change encodings of paths (enc -> tenc)
    if exists('&tenc')
        let tenc = &tenc
    else
        let tenc = ''
    endif
    if strlen(tenc) == 0 | let tenc = &enc | endif

    " get diff text (0.01ms)
    silent execute 'write! ' . escape(b:changedPath, ' ')
    if exists('b:job') && job_status(b:job) == 'run'
	    call job_stop(b:job)
    endif
    let b:job = job_start(
        \['diff', '-u', iconv(originalPath, &enc, tenc), iconv(b:changedPath, &enc, tenc)],
        \{'out_cb': 'g:Changed_show',
        \'out_mode': 'raw'})
endfunction

" function! g:Chaned_Error(ch, msg)
" 	echo a:msg
" endfunction
"
" function! g:Done(ch, msg)
" 	let g:test = a:msg
" 	echo 'done'
" endfunction

function! g:Changed_show(ch, msg)

    let diffLines = split(a:msg, '\n')
    " change encodings of paths (enc -> tenc)
    if exists('&tenc')
        let tenc = &tenc
    else
        let tenc = ''
    endif
    if strlen(tenc) == 0 | let tenc = &enc | endif
    " clear all temp files
    if has("win32") || has("win64")
        call job_start(['del', substitute(iconv(b:changedPath, &enc, tenc), '/', '\', 'g')])
    else
        call job_start(iconv('rm', iconv(b:changedPath, &enc, tenc)))
    endif

    " list lines and their signs
    let pos = 1 " changed line number
    let changedLineNums = {} " collection of pos
    let minusLevel = 0
    for line in diffLines
        if line[0] == '@'
            " reset pos
            let regexp = '@@\s*-\d\+\(,\d\+\)\?\s\++\(\d\+\)\(\(,\d\+\)\|\)\s\+@@'
	    " Eval cause an error. Now, this isn't a problem, because vim
	    " doesn't idetify strings or Integer about keys in dicts.
            " let pos = eval(substitute(line, regexp, '\2', ''))
            let pos = substitute(line, regexp, '\2', '')
            let minusLevel = 0
        elseif line[0] == '-' && line !~ '^---'
            let changedLineNums[pos] = 'SIGN_CHANGED_DELETED_VIM'
            let minusLevel += 1
        elseif line[0] == '+' && line !~ '^+++'
            if minusLevel > 0
                let changedLineNums[pos] = 'SIGN_CHANGED_VIM'
            else
                let changedLineNums[pos] = 'SIGN_CHANGED_ADDED_VIM'
            endif
            let pos += 1
            let minusLevel -= 1
        else
            let pos += 1
            let minusLevel = 0
        endif
    endfor

    let curSignedLines = s:GetPlacedSignsDic(bufnr('%'))

    " place signs
    for i in keys(changedLineNums)
	let newName = changedLineNums[i]
	let isSigned = 0
	if has_key(curSignedLines, i)
	    let oldSignsDic = curSignedLines[i]
	    let oldIdList = keys(oldSignsDic)
	    for j in oldIdList
	        if oldSignsDic[j] == newName
	    	 unlet isSigned | let isSigned = 1
	        else
	    	 execute 'sign unplace ' . j . ' buffer=' . bufnr('%')
	        endif
	    endfor
	endif
	if ! isSigned
	    let b:signId = exists('b:signId') ? b:signId+1 : s:STARTID
	    execute 'sign place ' . b:signId . ' line=' . i . ' name=' . newName . ' buffer=' . bufnr('%')
	endif
    endfor

    for i in keys(curSignedLines)
        if !has_key(changedLineNums, i)
            let oldSignsDic = curSignedLines[i]
            let oldIdList = keys(oldSignsDic)
            for j in oldIdList
                execute 'sign unplace ' . j . ' buffer=' . bufnr('%')
            endfor
        endif
    endfor
endfunction
