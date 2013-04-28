colors ir_black

" some common helpful settings "
set nomodeline
set nocompatible
set history=50
set wildmode=list:longest,full
set notitle
set number
set showmode
set showcmd
set ruler
" set ls=2
set incsearch
set ignorecase
set smartcase
set gdefault

set tabstop=4
set shiftwidth=4
set shiftround
set expandtab
set autoindent

set dictionary=/usr/share/dict/words
map <F7> :set complete+=k<CR>
map <S-F7> :set complete-=k<CR>


if &term == "xterm-color"
  fixdel
endif

" set bg=dark

"stop recording accidentally"
nmap q :

" normally don't automatically format `text' as it is typed, IE only do this "
" with comments, at 79 characters: "
set formatoptions-=t
set textwidth=0

filetype on
autocmd!

" in human-language files, automatically format everything at 72 chars: "
autocmd FileType mail,human set formatoptions+=t textwidth=72
autocmd FileType c,cpp,slang,java set cindent
autocmd FileType c set formatoptions+=ro
autocmd FileType perl,css set smartindent
autocmd FileType html set formatoptions+=tl
autocmd FileType html,css set noexpandtab tabstop=4
autocmd FileType make set noexpandtab shiftwidth=4
autocmd FileType sh set shiftwidth=4 tabstop=4

" when using list, keep tabs at their full width and display 'arrows': "
execute 'set listchars+=tab:' . nr2char(187) . nr2char(183)

" php helpfuls
" let php_sql_query = 1
let php_baselib = 1
let php_htmlInStrings = 1
let php_noShortTags = 1
let php_parent_error_close = 1
let php_parent_error_open = 1
let php_folding = 1

" Correct indentation after opening a phpdocblock and automatic * on every line "
set formatoptions=qroct

" Wrap visual selections with chars "
:vnoremap ( "zdi^V(<C-R>z)<ESC>
:vnoremap { "zdi^V{<C-R>z}<ESC>
:vnoremap [ "zdi^V[<C-R>z]<ESC>
:vnoremap ' "zdi'<C-R>z'<ESC>
:vnoremap " "zdi^V"<C-R>z^V"<ESC>

" Detect filetypes "
"if exists("did_load_filetypes") "
"    finish "
"endif "
augroup filetypedetect
    au! BufRead,BufNewFile *.pp     setfiletype puppet
    au! BufRead,BufNewFile *httpd*.conf     setfiletype apache
    au! BufRead,BufNewFile *inc     setfiletype php
augroup END

" Nick wrote: Uncomment these lines to do syntax checking when you save "
augroup Programming
" clear auto commands for this group "
autocmd!
autocmd BufWritePost *.php !php -d display_errors=on -l <afile>
autocmd BufWritePost *.inc !php -d display_errors=on -l <afile>
autocmd BufWritePost *httpd*.conf !/etc/rc.d/init.d/httpd configtest
autocmd BufWritePost *.bash !bash -n <afile>
autocmd BufWritePost *.sh !bash -n <afile>
autocmd BufWritePost *.pl !perl -c <afile>
autocmd BufWritePost *.perl !perl -c <afile>
autocmd BufWritePost *.xml !xmllint --noout <afile>
autocmd BufWritePost *.xsl !xmllint --noout <afile>
autocmd BufWritePost *.js !~/jslint/jsl -conf ~/jslint/jsl.default.conf -nologo -nosummary -process <afile>
autocmd BufWritePost *.rb !ruby -c <afile>
autocmd BufWritePost *.pp !puppet --parseonly <afile>
augroup en

" Correct indentation after opening a phpdocblock and automatic * on every line"
set formatoptions=qroct

" * Keystrokes -- Formatting "
" have Q reformat the current paragraph (or selected text if there is any): "
nnoremap Q gqap
vnoremap Q gq
" have the usual indentation keystrokes still work in visual mode: "
vnoremap <C-T> >
vnoremap <C-D> <LT>
vmap <Tab> <C-T>
vmap <S-Tab> <C-D>
" have Y behave analogously to D and C rather than to dd and cc "
noremap Y y$

" * Keystrokes -- Insert Mode "
" allow <BkSpc> to delete line breaks, beyond the start of the current insertion, and over indentations: "
set backspace=eol,start,indent
" have <Tab> (and <Shift>+<Tab> where it works) change the level of indentation: "
" inoremap <Tab> <C-T>
" inoremap <S-Tab> <C-D>
" [<Ctrl>+V <Tab> still inserts an actual tab character.] "


" abbreviations / spelling errors "
abbreviate wierd weird
abbreviate restaraunt restaurant
iabbrev hse he/she

syntax on

