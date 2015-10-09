" ============================================================================
" FILE: serverutil.vim
" AUTHOR: koturn <jeak.koutan.apple@gmail.com>
" DESCRIPTION: {{{
" Clientserver utility for Vim.
" This plugin is a simple wrapper of clientserver functions of Vim.
" So this plugin requires +clientserver.
" }}}
" ============================================================================
let s:save_cpo = &cpo
set cpo&vim

let g:serverutil#name = get(g:, 'serverutil#name', 'SERVERUTIL')
let g:serverutil#_reply_dict = {}
let g:serverutil#vim = get(g:, 'serverutil#vim', 'vim')
let g:serverutil#vim_option = get(g:, 'serverutil#vim_option', '-u NONE -i NONE -n -N')

let s:VimServer = {'lazy_read_messages': [], '_task_queue': []}
let s:server_list = []
let s:default_name_counter = 0
function! s:get_sid() abort
  return matchstr(expand('<sfile>'), '^function <SNR>\zs\d\+\ze_get_sid$')
endfun
let s:sid = s:get_sid()
delfunction s:get_sid


function! serverutil#new(...) abort
  if !has('clientserver')
    echoerr 'This vim cannot use serverclient functions'
    return {}
  endif
  let server = copy(s:VimServer)
  if a:0 > 0
    let server.name = a:1
  else
    let server.name = g:serverutil#name . s:default_name_counter
    let s:default_name_counter += 1
  endif
  let server._instance_id = len(s:server_list)
  call add(s:server_list, server)
  return server
endfunction


function! s:VimServer.start(...) abort
  call s:system_bg(printf('%s %s --servername %s',
        \ g:serverutil#vim, g:serverutil#vim_option, self.name))
  execute 'sleep' (a:0 > 0 ? a:1 : '1000') 'm'
  let self.id = s:get_server_id(self.name)
endfunction

function! s:VimServer.halt() abort
  call remote_send(self.name, '<Esc>:<C-u>quitall!<CR>')
endfunction

function! s:VimServer.lazy_start(...) abort
  call s:system_bg(printf('%s %s --servername %s -c "call remote_expr(%s, %s)"',
        \ g:serverutil#vim, g:serverutil#vim_option, self.name,
        \ string(v:servername),
        \ string(s:to_global_name(s:sid, 'on_vim_server_start') . '(' . self._instance_id . ')')))
  if a:0 > 0
    let self.lazy_start_callback = a:1
  endif
endfunction

function! s:VimServer.lazy_start2(...) abort
  call s:system_bg(printf('%s %s --servername %s',
        \ g:serverutil#vim, g:serverutil#vim_option, self.name))
  let self._clock = 1000
  let self._wait = a:0 > 0 ? a:1 : 1000
  if a:0 > 1
    let self.lazy_start_callback = a:2
  endif
  let group = 'VimServer' . self._instance_id
  execute 'augroup' group
  execute '  autocmd!'
  execute '  autocmd' group 'CursorHold,CursorHoldI * call s:server_list[' . self._instance_id . ']._update()'
  execute 'augroup END'
endfunction

function! s:VimServer.execute(cmd) abort
  if type(a:cmd) == type([])
    call remote_send(self.name, '<Esc>gQ' . join(a:cmd, '<CR>') . '<CR>visual<CR>')
  else
    call remote_send(self.name, '<Esc>:<C-u>' a:cmd . '<CR>')
  endif
endfunction

function! s:VimServer.source(file) abort
  call remote_send(self.name, '<Esc>:<C-u>source ' . expand(a:file) . '<CR>')
endfunction

function! s:VimServer.define_function(name, args, attr, body) abort
  call remote_send(self.name, '<Esc>:<C-u>function! ' . a:name . a:args . ' '
        \ . a:attr . '<CR>' . join(a:body, '<CR>') . '<CR>endfunction<CR>')
endfunction

function! s:VimServer.send_function(function, ...) abort
  if type(a:function) == type('')
    if !stridx(function, 's:')
      throw "serverutil.vim: Script local function cannot to be read it's definition by name only"
    endif
    let function = a:function
    let funcname_on_server = a:0 > 0 ? a:1 : substitute(a:function, '^s:', 'S_', '')
  elseif type(a:function) == type([])
    let function = s:to_global_name(a:function[0], substitute(a:function[1], '^s:', '', ''))
    let funcname_on_server = a:0 > 1 ? a:1 : ('S_' . substitute(a:function[1], '^s:', '', ''))
  elseif type(a:function) == type({})
    let function = s:to_global_name(a:function.sid, substitute(a:function.name, '^s:', '', ''))
    let funcname_on_server = a:0 > 1 ? a:1 :
          \ has_key(a:function, 'sid') ? ('S_' . substitute(a:function.name, '^s:', '', '')) :
          \ a:function
  elseif type(a:function) == type(function('function'))
    let function = matchstr(string(a:function), "function('\\zs.\\+\\ze')")
    let funcname_on_server = substitute(function, '^<SNR>\d\+', 'S', '')
  endif
  let save_list = &l:list
  setlocal nolist
  call remote_send(self.name, '<Esc>:<C-u>' . join(map(split(substitute(s:redir(
        \ 'function ' . function),
        \ '\zsfunction \(.\{-}\)\ze(', 'function! ' . funcname_on_server, ''),
        \ "\n"),
        \ 'substitute(v:val, "^\\%(\\d\\{3,}\\|[0-9 ]\\{3}\\)", "", "")'),
        \ '<CR>') . '<CR><CR>')
  let &l:list = save_list
endfunction

function! s:VimServer.send_var(varname, ...) abort
  let value = eval(a:0 > 0 ? a:1 : a:varname)
  let varname_on_server = a:0 > 0 ? a:1 : substitute(a:varname, '^\([ablstvw]\):', '\1_', '')
  call remote_send(self.name, '<Esc>:<C-u>let ' . varname_on_server . ' = ' . string(value))
endfunction

function! s:VimServer.foreground() abort
  call remote_foreground(self.name)
endfunction

function! s:VimServer.send(msg) abort
  call remote_send(self.name, a:msg)
endfunction

function! s:VimServer.expr(expr) abort
  return remote_expr(self.name, a:expr)
endfunction

function! s:VimServer.peek(...) abort
  return a:0 == 0 ? remote_peek(self.id) : remote_peek(self.id, a:1)
endfunction

function! s:VimServer.read() abort
  return remote_read(self.id)
endfunction

function! s:VimServer.lazy_read(...) abort
  if a:0 > 0
    call self.add_task({'function': a:1, 'eval_args': ['self.read()']})
  elseif has_key(self, 'lazy_read_callback')
    call self.add_task({'function': self.lazy_read_callback, 'eval_args': ['self.read()']})
  else
    call self.add_task('call self.read(self.id)')
  endif
endfunction


function! s:VimServer.add_task(task) abort
  call add(self._task_queue, a:task)
endfunction

function! s:VimServer._update() abort
  if self._clock < self._wait
    call feedkeys(mode() ==# 'i' ? "\<C-g>\<ESC>" : "g\<ESC>", 'n')
    let self._clock += &updatetime
  else
    execute 'autocmd! VimServer' . self._instance_id 'CursorHold,CursorHoldI *'
    let self.id = s:get_server_id(self.name)
    if !has_key(self, 'lazy_start_callback')
      return
    endif
    let self._callback = self.lazy_start_callback
    call self._execute_callback()
  endif
endfunction

function! s:VimServer._execute_callback() abort
  if type(self._callback) == type(function('function'))
    call self._callback()
  elseif type(self._callback) == type('')
    execute self._callback
  elseif type(self._callback) == type([])
    for _ in self._callback
      execute _
    endfor
  elseif type(self._callback) == type({})
    let args = (has_key(self._callback, 'args') ? self._callback.args : [])
          \ + (has_key(self._callback, 'eval_args') ? map(copy(self._callback.eval_args), 'string(eval(v:val))') : [])
    call call(self._callback.function, args, self._callback)
  endif
  unlet self._callback
endfunction


function! s:system_bg(cmd) abort
  if has('win95') || has('win16') || has('win32') || has('win64')
    execute 'silent !start /min' a:cmd
  else
    silent call system(a:cmd . ' &')
  endif
endfunction

function! s:on_vim_server_start(instance_id) abort
  let server = s:server_list[a:instance_id]
  let server.id = s:get_server_id(server.name)
  if !has_key(server, 'lazy_start_callback')
    return
  endif
  let server._callback = server.lazy_start_callback
  call server._execute_callback()
endfunction

function! s:get_server_id(server_name) abort
  call remote_send(a:server_name, '', 'id')
  return id
endfunction

function! s:redir(cmd) abort
  let [save_verbose, save_verbosefile] = [&verbose, &verbosefile]
  set verbose=0 verbosefile=
  redir => str
  execute 'silent!' a:cmd
  redir END
  let [&verbose, &verbosefile] = [save_verbose, save_verbosefile]
  return str
endfunction

function! s:to_global_name(sid, funcname) abort
  return '<SNR>' . a:sid . '_' . a:funcname
endfunction


augroup VimServer
  autocmd!
  autocmd RemoteReply * call s:on_reply(expand('<amatch>'))
augroup END

function! s:on_reply(id) abort
  let servers = filter(copy(s:server_list), 'v:val.id ==# a:id')
  if empty(servers)
    return
  endif
  let server = servers[0]
  if !empty(server._task_queue)
    let server._callback = remove(server._task_queue, 0)
    call server._execute_callback()
  endif
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
