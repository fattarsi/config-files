" switch between windows with alt+arrow keys
nnoremap <C-Left> <C-w>h
nnoremap <C-Right> <C-w>l
nnoremap <C-Up> <C-w>k
nnoremap <C-Down> <C-w>j

" close tabs similar to browser
map <C-w> :q<Enter>
imap <C-w> <Esc>:q<Enter>

" move between tabs with shift+arrow keys
map <S-Left> gT
map <S-Right> gt
imap <S-Left> <Esc>gT
imap <S-Right> <Esc>gt

" Vundle
set nocompatible
filetype off

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" After updating run `vim +PluginInstall +qall`
Plugin 'gmarik/Vundle.vim'
Plugin 'scrooloose/syntastic'
Plugin 'wincent/command-t'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'eugen0329/vim-esearch'
Plugin 'tpope/vim-fugitive'
Bundle 'hrj/vim-DrawIt'

Bundle 'mattn/webapi-vim'
Bundle 'mattn/gist-vim'
Bundle 'mhinz/vim-startify'

call vundle#end()
filetype plugin indent on

" end Vundle
set shell=/bin/bash
set hlsearch
set ignorecase
set smartcase
set tabstop=4
set shiftwidth=4
set expandtab
set incsearch

set laststatus=2
set statusline=%t:%=%l,%c\ (%P)
set wildignore+=*.doc,*.ebuild,*.gz,*.jpeg,*.jpg,*.mp3,*.o,*.obj,*.pdf,*.png,*.pot,*.ppt,*.pptx,*.pyc,*.rng,*.rtf,*.tar,*.tiff,*.zip,.git,dropbox,projects,misc,**/node_modules/*,bin/*,eggs/*

"rg project
set wildignore+=mobile/plugins/**,mobile/platforms/**


inoremap # X<BS>#
hi StatusLine ctermbg=black ctermfg=gray

au BufNewFile,BufRead *.py set smartindent
" show vertical line at 80 chars
"au BufNewFile,BufRead *.py set colorcolumn=80

let g:jedi#use_tabs_not_buffers = 0

let g:pydiction_location='~/.vim/bundle/pydiction/complete-dict'

let g:CommandTMaxHeight=20
let g:CommandTMatchWindowReverse=0
let g:CommandTAcceptSelectionMap='<C-o>'
let g:CommandTAcceptSelectionTabMap='<CR>'
let g:CommandTTraverseSCM='pwd'

let g:startify_change_to_dir=0
let g:startify_lists = ['files', 'sessions', 'bookmarks']
let g:startify_files_number=20
let g:startify_enable_special=0

let g:syntastic_check_on_open=0
let g:syntastic_auto_loc_list=1
let g:syntastic_python_checkers=['pylint']
let g:syntastic_rst_checkers=[]
let g:syntastic_enable_highlighting = 1

let @i='oimport ipdb;ipdb.set_trace()'
" Set title string and push it to xterm/screen window title
" vim <truncate><fullpath>
set titlestring=%F%m%r%h
set titlelen=70

if &term =~? "screen"
  " Make sure set title works for screen
  set t_ts=k
  set t_fs=\
  set title
endif

if &term =~? "xterm*"
  set title
  set t_Sb=^[4%dm
  set t_Sf=^[3%dm
  set ttymouse=xterm2
endif

if &term ==? "rxvt-unicode" || &term ==? "screen"
    set t_Co=256
endif

if &t_Co > 2 || has("gui_running")
    syntax on
endif
