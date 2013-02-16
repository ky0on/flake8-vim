" Check python support
if !has('python')
    echo "Error: PyFlake.vim required vim compiled with +python."
    finish
endif

if !exists('b:PyFlake_initialized')
    let b:PyFlake_initialized = 1

    au BufWritePost <buffer> call flake8#on_write()
    au CursorHold <buffer> call flake8#get_message()
    au CursorMoved <buffer> call flake8#get_message()
    
    " Commands
    command! -buffer PyFlakeToggle :let b:PyFlake_disabled = exists('b:PyFlake_disabled') ? b:PyFlake_disabled ? 0 : 1 : 1
    command! -buffer PyFlake :call flake8#run()
    command! -buffer PyFlakeAuto :call flake8#auto()

    let b:showing_message = 0
    
    " Signs definition
    sign define W text=WW texthl=Todo
    sign define C text=CC texthl=Comment
    sign define R text=RR texthl=Visual
    sign define E text=EE texthl=Error
endif

 "Check for flake8 plugin is loaded
if exists("g:PyFlakeDirectory")
    finish
endif

if !exists('g:PyFlakeOnWrite')
    let g:PyFlakeOnWrite = 1
endif

" Init variables
let g:PyFlakeDirectory = expand('<sfile>:p:h')

if !exists('g:PyFlakeCheckers')
    let g:PyFlakeCheckers = 'pep8,mccabe,pyflakes'
endif
if !exists('g:PyFlakeDefaultComplexity')
    let g:PyFlakeDefaultComplexity=10
endif
if !exists('g:PyFlakeDissabledMessages')
    let g:PyFlakeDissabledMessages = ''
endif
if !exists('g:PyFlakeCWindow')
    let g:PyFlakeCWindow = 6
endif
if !exists('g:PyFlakeSigns')
    let g:PyFlakeSigns = 1
endif

python << EOF

import sys
import vim

sys.path.insert(0, vim.eval("g:PyFlakeDirectory"))
from flake8 import run_checkers, fix_file

def check():
    checkers=vim.eval('g:PyFlakeCheckers').split(',')
    ignore=vim.eval('g:PyFlakeDissabledMessages').split(',')
    filename=vim.current.buffer.name
    parse_result(run_checkers(filename, checkers, ignore=[], select=[]))

def parse_result(result):
    vim.command(('let g:qf_list = %s' % repr(result)).replace('\': u', '\': '))

EOF

function! flake8#on_write()
    if !g:PyFlakeOnWrite || exists("b:PyFlake_disabled") && b:PyFlake_disabled
        return
    endif
    call flake8#check()
endfunction

function! flake8#run()
    if &modifiable && &modified
        write
    endif
    call flake8#check()
endfun

function! flake8#check()
    py check()
    let s:matchDict = {}
    for err in g:qf_list
        let s:matchDict[err.lnum] = err.text
    endfor
    call setqflist(g:qf_list, 'r')

    " Place signs
    if g:PyFlakeSigns
        call flake8#place_signs()
    endif

    " Open cwindow
    if g:PyFlakeCWindow
        cclose
        if len(g:qf_list)
            let l:winsize = len(g:qf_list) > g:PyFlakeCWindow ? g:PyFlakeCWindow : len(g:qf_list)
            exec l:winsize . 'cwindow'
        endif
    endif
endfunction

function! flake8#auto() "{{{
    if &modifiable && &modified
        try
            write
        catch /E212/
            echohl Error | echo "File modified and I can't save it. Cancel operation." | echohl None
            return 0
        endtry
    endif
    py fix_file(vim.current.buffer.name)
    cclose
    edit
endfunction "}}}

function! flake8#place_signs()
    "first remove all sings
    sign unplace *

    "now we place one sign for every quickfix line
    let l:id = 1
    for item in getqflist()
        execute(':sign place '.l:id.' name='.l:item.type.' line='.l:item.lnum.' buffer='.l:item.bufnr)
        let l:id = l:id + 1
    endfor
endfunction

" keep track of whether or not we are showing a message
" WideMsg() prints [long] message up to (&columns-1) length
" guaranteed without "Press Enter" prompt.
function! flake8#wide_msg(msg)
    let x=&ruler | let y=&showcmd
    set noruler noshowcmd
    redraw
    echo strpart(a:msg, 0, &columns-1)
    let &ruler=x | let &showcmd=y
endfun


function! flake8#get_message()
    let s:cursorPos = getpos(".")

    " Bail if RunPyflakes hasn't been called yet.
    if !exists('s:matchDict')
        return
    endif

    " if there's a message for the line the cursor is currently on, echo
    " it to the console
    if has_key(s:matchDict, s:cursorPos[1])
        let s:pyflakesMatch = get(s:matchDict, s:cursorPos[1])
        call flake8#wide_msg(s:pyflakesMatch)
        let b:showing_message = 1
        return
    endif

    " otherwise, if we're showing a message, clear it
    if b:showing_message == 1
        echo
        let b:showing_message = 0
    endif
endfunction

