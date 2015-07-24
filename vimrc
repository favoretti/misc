syntax on
filetype plugin indent on

let python_highlight_all=1
"let g:syntastic_puppet_lint_arguments='--no-80chars-check'
syntax on
colorscheme pablo
set nocompatible    " use vim defaults
set ls=2            " allways show status line
set tabstop=4       " numbers of spaces of tab character
set shiftwidth=4    " numbers of spaces to (auto)indent
set scrolloff=3     " keep 3 lines when scrolling
set showcmd         " display incomplete commands
set hlsearch        " highlight searches
set incsearch       " do incremental searching
set ruler           " show the cursor position all the time
set visualbell t_vb=    " turn off error beep/flash
set novisualbell    " turn off visual bell
set nobackup        " do not keep a backup file
"set ignorecase      " ignore case when searching
set noignorecase   " don't ignore case
set title           " show title in console title bar
set ttyfast         " smoother changes
"set ttyscroll=0        " turn off scrolling, didn't work well with PuTTY
set modeline        " last lines in document sets vim mode
set modelines=3     " number lines checked for modelines
set shortmess=atI   " Abbreviate messages
set nostartofline   " don't jump to first character when paging

au BufRead,BufNewFile *py,*pyw,*.c,*.h,*.css set tabstop=4

au BufRead,BufNewFile *.py,*pyw,*.css set shiftwidth=4
au BufRead,BufNewFile *.py,*.pyw,*.css set expandtab
au BufRead,BufNewFile Makefile* set noexpandtab


highlight BadWhitespace ctermbg=red
au BufRead,BufNewFile *.py,*.pyw,*.pp match BadWhitespace /^\t\+/
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h,*.pp match BadWhitespace /\s\+$/

au FileType * autocmd BufWritePre <buffer> :%s/\s\+$//e

au BufRead,BufNewFile *.py,*.pyw,*.c,*.h set textwidth=800
au BufNewFile *.py,*.pyw,*.c,*.h,*.pp set fileformat=unix

call pathogen#infect()
