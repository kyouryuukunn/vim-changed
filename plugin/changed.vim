" Changed
"
" Description:
"   Displays signs on changed lines.
" Last Change: 2018-9-22
" Maintainer: Takuma Inagaki <akakyouryuu@gmail.com>
" Requirements:
"   * vim8.1 or more
"   * +signs (appears in :version)
"   * +job (appears in :version)
"   * +timers (appears in :version)
"   * diff command
"   * setting &termencoding
" Installation:
"   Just source this file. (Put this file into the plugin directory.)
" Usage:
"   [Settings]
"    1. augroup vim-changed
"      	autocmd!
"      	au BufReadPost  * Changed
"      	au BufWritePost * Changed
"      	au TextChanged  * ChangedTimerSet
"      	au TextChangedI * ChangedTimerSet
"      augroup END
"      " Changed is executed g:changed_delay ms after the last change
"      let g:changed_delay = 500
"
"   2. Setting &termencoding
"       Set &termencoding option according to your terminal encoding. 
"       Its default value is same as &encoding.
"       example:
"           set termencoding=cp932
"
"   3. Changing signs
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
if exists('g:vim_changed_loaded')
    finish
endif
let g:vim_changed_loaded = 1

command Changed         :call vim_changed#Changed_execute()
command ChangedTimerSet :call vim_changed#Changed_timerset()
command ChangedClear    :call vim_changed#Changed_clear()

let g:changed_delay = get(g:, 'changed_delay', 100)
let g:changed_sign_priority = get(g:, 'changed_sign_priority', 9)

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
