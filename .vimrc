set shell=/bin/bash
set hlsearch
set tabstop=4
set shiftwidth=4
set expandtab

set laststatus=2
set statusline=%t:%=%l,%c\ (%P)
set wildignore+=*.doc,*.ebuild,*.gz,*.jpeg,*.jpg,*.mp3,*.o,*.obj,*.pdf,*.png,*.pot,*.ppt,*.pptx,*.pyc,*.rng,*.rtf,*.tar,*.tiff,*.zip,.git,dropbox,projects
hi StatusLine ctermbg=black ctermfg=gray


au BufNewFile,BufRead *.py set smartindent
au BufNewFile,BufRead *.py set colorcolumn=80

call pathogen#infect()

let g:CommandTMaxHeight=20
let g:CommandTMatchWindowAtTop=1
let g:CommandTAcceptSelectionMap='<C-o>'
let g:CommandTAcceptSelectionTabMap='<CR>'

let g:startify_change_to_dir=0
let g:startify_lists = ['files', 'sessions', 'bookmarks']
let g:startify_files_number=20

let g:syntastic_check_on_open=0
let g:syntastic_auto_loc_list=1
let g:syntastic_python_checker = 'pylint'
let g:syntastic_enable_highlighting = 1

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
