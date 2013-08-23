" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU Lesser General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU Lesser General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>.


" File: excess-lines.vim
" Author: Dirk Wallenstein
" Description: Highlight surplus characters of long lines
" License: LGPLv3
" Version: 0.0.0

if exists('loaded_excess_lines')
    finish
endif
let loaded_excess_lines = 1

"
" --- Configuration
"

if ! exists("g:excess_lines_match_setup")
    " A dictionary with filetype keys, or '*' as a fallback entry.  Each entry
    " maps to another dictionary with three possible keys: 'permanent', 'insert'
    " and 'normal'.  Each maps to a list of lists of arguments to matchadd().
    "
    "       [["highlight-group", 'pattern', priority], ...]
    "
    " Each of those match specifications are active in the corresponding mode
    " (insert/normal or all the time) in the filetype given as top level key.
    " Each of the mode keys in a filetype specific entry falls back to the mode
    " key in the fallback entry individually.  Specify empty lists to override.
    "
    " Actually, the normal mode key comprises all the modes that are not the
    " insert mode.
    "
    " Can be overridden buffer locally.
    highlight EL_EXP_InsertTail gui=undercurl guisp=Magenta
                \ term=reverse ctermfg=15 ctermbg=12
    highlight EL_EXP_Warning guifg=Black guibg=Yellow
                \ term=standout cterm=bold ctermfg=0 ctermbg=3
    highlight EL_EXP_Error guifg=White guibg=Red
                \ term=reverse cterm=bold ctermfg=7 ctermbg=1

    let s:exp_permanent_matches = [
        \   ["EL_EXP_Error", '\%81v.\+', -70],
        \   ]
    let s:exp_insert_mode_matches = [
        \   ["EL_EXP_Warning",  '\zs\%70v.\ze.*\%#', -50],
        \   ["EL_EXP_Warning",  '\%#.*\zs\%70v.\ze', -50],
        \   ["EL_EXP_InsertTail",  '\%81v.\+\%#.*$', -50],
        \   ["EL_EXP_InsertTail",  '\%#.*\zs\%81v.\+\ze$', -50],
        \   ]
    let s:exp_normal_mode_matches = []

    let g:excess_lines_match_setup = {
        \ '*': {
        \       'permanent': s:exp_permanent_matches,
        \       'normal': s:exp_normal_mode_matches,
        \       'insert': s:exp_insert_mode_matches,
        \       },
        \ }
endif

" ---

if !exists("g:excess_lines_off_filetypes")
    " A list of filetypes for which not to highlight excess-lines initially.
    let g:excess_lines_off_filetypes = ['qf']
endif

if !exists("g:excess_lines_on_filetypes")
    " A list of filetypes for which to exclusively highlight excess-lines
    " initially.  For all other filetypes excess-lines highlighting will be
    " turned off initially.  An empty list has no effect.  Items in the
    " off-filetypes list will be overridden if included here.
    let g:excess_lines_on_filetypes = []
endif

if !exists("g:textwidth_zero_turns_off_initially")
    " Hide excess-lines initially if textwidth=0.  Set this variable to nonzero
    " if you want that.
    let g:textwidth_zero_turns_off_initially = 0
endif


"
" --- Diverse
"

fun! s:GetDisplayOnOffDefaultForFiletype()
    " Compute the on/off default according to the configuration options.
    if !empty(g:excess_lines_on_filetypes)
        let l:on_filtypes = filter(copy(g:excess_lines_on_filetypes),
                    \ 'v:val == &ft')
        if empty(l:on_filtypes)
            return 0
        else
            return 1
        endif
    endif
    let l:off_filtypes = filter(copy(g:excess_lines_off_filetypes),
                \ 'v:val == &ft')
    if empty(l:off_filtypes)
        return 1
    else
        return 0
    endif
endfun

" ---

fun! s:VariableFallback(variableList)
    " Return the value of the first existing variable in a:variableList.
    for l:variable in a:variableList
        if exists(l:variable)
            let l:result = eval(l:variable)
            return l:result
        endif
    endfor
    throw "VariableFallback: None of the variables exists: "
                \ . string(a:variableList)
endfun

fun! s:GetMatchSetup()
    " The match setup can be overridden buffer locally.  Return the active one.
    let l:variableList = [
                \ "b:excess_lines_override_setup",
                \ "b:excess_lines_match_setup",
                \ "g:excess_lines_match_setup"
                \ ]
    return s:VariableFallback(l:variableList)
endfun

fun! s:GetMatchSpecs(mode)
    " Return the list of match-specs for the given a:mode.  Valid modes are
    " 'permanent', 'insert' and 'normal'.
    let l:match_setup = s:GetMatchSetup()
    if !empty(&ft)
        try
            let l:ft_dict = l:match_setup[&ft]
            let l:ft_match_specs = l:ft_dict[a:mode]
            return l:ft_match_specs
        catch /E716/ " Key not present in Dictionary
        endtry
    endif
    try
        let l:default_dict = l:match_setup['*']
        let l:fallback_match_specs = l:default_dict[a:mode]
        return l:fallback_match_specs
    catch /E716/ " Key not present in Dictionary
    endtry
    return []
endfun

"
" --- General Match Processors
"

fun! s:InstallMatches_ABS(all_specs, record_var_name)
    " Install the match specifications given in the list a:all_specs and
    " record them in the variable given in a:record_var_name.  Deletes existing
    " matches recorded in a:record_var_name first.
    if !b:excess_lines_show
        return 0
    endif
    call s:DeleteMatches_ABS(a:record_var_name)
    for [l:highlight, l:pattern, l:priority] in a:all_specs
        exe 'let l:next_id = matchadd("' . l:highlight . '", '''
                    \ . l:pattern . ''', ' . l:priority . ')'
        call add(eval(a:record_var_name), l:next_id)
    endfor
    return 1
endfun

fun! s:DeleteMatches_ABS(record_var_name)
    " Delete the excess line matches in this window recorded in
    " a:record_var_name and clear that list.
    if !exists(a:record_var_name)
        exe "let " . a:record_var_name . " = []"
        return
    endif
    for l:id in eval(a:record_var_name)
        call matchdelete(l:id)
    endfor
    exe "let " . a:record_var_name . " = []"
endfun

"
" --- Override Matches
"

fun! s:GetPermanentMatchSpecs()
    return s:GetMatchSpecs('permanent')
endfun

fun! s:DeletePermanentMatches()
    " Delete the excess line matches in this window
    call s:DeleteMatches_ABS("w:excess_lines_match_ids")
endfun

fun! s:SetPermanentMatches()
    return s:InstallMatches_ABS(s:GetPermanentMatchSpecs(),
                \ "w:excess_lines_match_ids")
endfun

"
" --- Insert Mode Matches
"

fun! s:GetInsertModeMatchSpecs()
    return s:GetMatchSpecs('insert')
endfun

fun! s:DeleteInsertModeMatches()
    " Delete the insert mode matches in this window
    call s:DeleteMatches_ABS("w:excess_lines_match_ids_insert_mode")
endfun

fun! s:SetInsertModeMatches()
    return s:InstallMatches_ABS(s:GetInsertModeMatchSpecs(),
                \ "w:excess_lines_match_ids_insert_mode")
endfun

"
" --- Normal Mode Matches
"

fun! s:GetNormalModeMatchSpecs()
    return s:GetMatchSpecs('normal')
endfun

fun! s:DeleteNormalModeMatches()
    " Delete the insert mode matches in this window
    call s:DeleteMatches_ABS("w:excess_lines_match_ids_normal_mode")
endfun

fun! s:SetNormalModeMatches()
    return s:InstallMatches_ABS(s:GetNormalModeMatchSpecs(),
                \ "w:excess_lines_match_ids_normal_mode")
endfun

"
" --- Init and Controls
"

fun! s:SwitchToMode(new_mode)
    " Switch the active matches (insert/normal)
    if a:new_mode == 'insert'
        call s:DeleteNormalModeMatches()
        call s:SetInsertModeMatches()
    elseif a:new_mode == 'normal'
        call s:DeleteInsertModeMatches()
        call s:SetNormalModeMatches()
    else
        throw "Invalid mode request: " . a:new_mode
    endif
endfun

fun! s:InitializeBuffer_cond()
    " Determine the initial state of the display (on/off)
    if exists("b:excess_lines_show")
        return
    endif
    let l:textwidth_off = g:textwidth_zero_turns_off_initially && &tw == 0
    if &modifiable && !&wrap && !l:textwidth_off
        let b:excess_lines_show = s:GetDisplayOnOffDefaultForFiletype()
    else
        let b:excess_lines_show = 0
    endif
endfun

fun! s:SyncExcessLines()
    " Sync the display to the current state of the buffer (show/hide).
    " Initialize the buffer if that hasn't already been done.
    call s:InitializeBuffer_cond()
    if b:excess_lines_show
        call s:ShowExcessLines()
    else
        call s:HideExcessLines()
    endif
endfun

fun! s:ShowExcessLines()
    " Highlight the matches
    let b:excess_lines_show = 1
    call s:SetPermanentMatches()
    if mode() == "i"
        call s:SwitchToMode("insert")
    else
        call s:SwitchToMode("normal")
    endif
endfun

fun! s:HideExcessLines()
    " Delete all matches
    let b:excess_lines_show = 0
    call s:DeletePermanentMatches()
    call s:DeleteNormalModeMatches()
    call s:DeleteInsertModeMatches()
endfun

fun! s:ToggleExcessLines()
    " Toggle between hiding and showing matches.
    if b:excess_lines_show
        call s:HideExcessLines()
    else
        call s:ShowExcessLines()
    endif
endfun

"
" --- Auto-Commands
"

" The entry point:
autocmd WinEnter,BufWinEnter,ColorScheme,FileType * call <SID>SyncExcessLines()
" Insert mode matches are added/removed by autocommands:
autocmd InsertEnter * call <SID>SwitchToMode("insert")
autocmd InsertLeave * call <SID>SwitchToMode("normal")

"
" --- Public Interface
"
fun! g:EL_GetActivePattern(index)
    " Return the pattern for a currently installed match pattern.  The argument
    " for a:index is the index into the currently installed patterns.  If normal
    " or insert mode patterns are active, they come after the permanent
    " patterns.  Throw an exception if there is no pattern at that index.
    let l:ordered_records = [
                \ "w:excess_lines_match_ids",
                \ "w:excess_lines_match_ids_normal_mode",
                \ "w:excess_lines_match_ids_insert_mode",
                \ ]
    let l:recorded_ids = []
    for l:record in l:ordered_records
        if exists(l:record)
            call extend(l:recorded_ids, eval(l:record))
        endif
    endfor
    try
        let l:match_id = l:recorded_ids[a:index]
    catch /E684/ " list index out of range
        throw "No pattern at index " . a:index
    endtry
    for l:matchrecord in getmatches()
        if l:matchrecord['id'] == l:match_id
            return l:matchrecord['pattern']
        endif
    endfor
    return ''
endfun

" ---

fun! g:EL_InstallOverridePatterns(match_setup)
    " Install a match-setup in the current buffer only.  The a:match_setup
    " format is the same as for g:excess_lines_match_setup
    call s:HideExcessLines()
    let b:excess_lines_override_setup = a:match_setup
    call s:ShowExcessLines()
endfun

fun! g:EL_UninstallOverridePatterns()
    " Uninstall override patterns installed with g:EL_InstallOverridePatterns
    " and return to the previous configuration.
    call s:HideExcessLines()
    unlet b:excess_lines_override_setup
    call s:ShowExcessLines()
endfun

" ---

" Turn the display of excess lines on/off or toggle it.
command! ElShowExcessLines call <SID>ShowExcessLines()
command! ElHideExcessLines call <SID>HideExcessLines()
command! ElToggleExcessLines call <SID>ToggleExcessLines()
" Set the search pattern to the first excess-lines pattern
command! ElSetSearchPatternToFirstActivePattern
            \ let @/ = g:EL_GetActivePattern(0)
