let s:STARTID=30999

function! vim_changed#Changed_clear()
    if exists('b:signId')
	let i = s:STARTID
        while b:signId >= i
            execute 'sign unplace ' . i . ' buffer=' . bufnr('%')
	    let i = i + 1
        endwhile
    endif
    if exists('b:signId') | unlet b:signId | endif
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

function! vim_changed#Changed_timerset() abort
    if exists('s:timer')
        call timer_stop(s:timer)
        unlet s:timer
    endif
    let s:timer = timer_start(g:changed_delay, function('vim_changed#Changed_execute', [b:changedtick]))
endfunction

function! vim_changed#Changed_execute(...)
    let l:changedtick = get(a:, 1, b:changedtick)

    " not changed from the last called this function
     if exists('b:completed_changedtick') && b:completed_changedtick == l:changedtick
            return
     endif

    if !&modified
        call vim_changed#Changed_clear()
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
    let b:completed_changedtick = l:changedtick
    let b:job = job_start(
        \['diff', '-u', iconv(originalPath, &enc, tenc), iconv(b:changedPath, &enc, tenc)],
        \{'close_cb': function('g:Changed_show', [l:changedtick, bufnr('%')]),
        \'out_mode': 'raw'})
    " let diffResult = vimproc#system(['diff', '-u', iconv(originalPath, &enc, tenc), iconv(b:changedPath, &enc, tenc)])
endfunction

" function! g:Chaned_Error(ch, msg)
" 	echo a:msg
" endfunction
"
" function! g:Done(ch, msg)
" 	let g:test = a:msg
" 	echo 'done'
" endfunction

function! g:Changed_show(changedtick, bufnr, ch) abort

    " not the latest change
    if b:changedtick > a:changedtick || a:bufnr != bufnr('%')
        return
    endif
    if ch_status(a:ch, {'part': 'out'}) == 'buffered'
        let diffLines = split(ch_read(a:ch), '\n')
    else
        return
    endif

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
