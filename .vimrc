set shell=/bin/bash
set tabstop=4
set shiftwidth=4
set expandtab

set laststatus=2
set statusline=%t:%=%l,%c\ (%P)
hi StatusLine ctermbg=black ctermfg=gray


au BufNewFile,BufRead *.py set smartindent
au BufNewFile,BufRead *.py set colorcolumn=80
au BufNewFile,BufRead *.py highlight OverLength ctermbg=red ctermfg=white guibg=#592929
au BufNewFile,BufRead *.py match OverLength /\%81v.\+/

call pathogen#infect()

let g:syntastic_check_on_open=0
let g:syntastic_auto_loc_list=1
let g:syntastic_python_checker = 'pylint'
let g:syntastic_enable_highlighting = 1
