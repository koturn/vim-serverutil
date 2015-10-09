vim-serverutil
==============

Clientserver utility for Vim.

This plugin is a simple wrapper of clientserver functions of Vim.
So this plugin requires +clientserver.


## Usage

#### Example

```vim
let s:vs = serverutil#new()
function! s:vs.lazy_start_callback() abort
  call self.send(':<C-u>set visualbell t_vb=<CR>')
  call self.execute([
        \ 'set updatetime=1000',
        \ 'let g:time_to_stop = 3000',
        \ 'let g:clock = &updatetime'
        \])
  call self.define_function('Update', '()', 'abort', [
        \ '  echo (g:clock / 1000.0)',
        \ '  if g:clock < g:time_to_stop',
        \ '    call feedkeys(mode() ==# "i" ? "\<lt>C-g>\<lt>ESC>" : "g\<lt>ESC>", "n")',
        \ '    let g:clock += &updatetime',
        \ '  else',
        \ '    call server2client(expand("<client>"), "Hello, World! from server")',
        \ '    call server2client(expand("<client>"), "3 seconds elapsed")',
        \ '    quitall!',
        \ '  endif'
        \])
  call self.execute([
        \ 'augroup Server',
        \ '  autocmd!',
        \ '  autocmd CursorHold,CursorHoldI * call Update()',
        \ 'augroup END'
        \])
endfunction
call s:vs.lazy_start()

function! s:vs.lazy_read_callback(message) abort
  echomsg 'Message from server #01:' a:message
endfunction
call s:vs.lazy_read()

function! s:vs.lazy_read_callback(message) abort
  echomsg 'Message from server #02:' a:message
endfunction
call s:vs.lazy_read()
```


## Installation

With [NeoBundle](https://github.com/Shougo/neobundle.vim).

```vim
NeoBundle 'koturn/vim-serverutil'
```

If you want to use ```:NeoBundleLazy```, write following code in your .vimrc.

```vim
NeoBundleLazy 'koturn/vim-serverutil'
if neobundle#tap('vim-serverutil')
  call neobundle#config({
        \ 'autoload': {
        \   'function_prefix': 'serverutil'
        \ }
        \})
  call neobundle#untap()
endif
```

With [Vundle](https://github.com/VundleVim/Vundle.vim).

```vim
Plugin 'koturn/vim-serverutil'
```

With [vim-plug](https://github.com/junegunn/vim-plug).

```vim
Plug 'koturn/vim-serverutil'
```

If you don't want to use plugin manager, put files and directories on
```~/.vim/```, or ```%HOME%/vimfiles``` on Windows.


## LICENSE

This software is released under the MIT License, see [LICENSE](LICENSE).
