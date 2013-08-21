Vim Excess Lines
================

This is kind of a frontend to the the `matchadd()` mechanism in Vim with
the focus on one particular use case: Highlighting surplus characters
in long lines.

The configuration is a bit involved, but in return you can specify what you want
to see when and where.  Actually, you can use it to highlight anything.  Not
just excess lines.

**Features:**

- Configure different highlighting for buffers of different filetype
- Match different patterns during insert and normal mode
- Turn highlighting on/off or toggle it
- Select in which filetypes to start in on/off mode
- Start in off mode when the buffer is not modifiable or has the `wrap` option
  set
- Extract patterns of installed matches to search for or act on affected lines


Configuration
-------------
The dictionary `g:excess_lines_match_setup` can be used to configure the
matches.  The keys are filetypes to which the values apply.  Each value is
another dictionary where the keys are the mode in which the list of
match-specifications they map to are active.

The three valid modes are:

- `'permanent'` : active in all modes
- `'insert'` : only active in insert mode
- `'normal'` : only active when not in insert mode

For example, to add special behavior for `markdown` files you can add an entry
similar to this one:

    let g:excess_lines_match_setup['markdown'] = {
        \   'permanent': s:expl_permanent_matches,
        \   'insert': s:expl_insert_mode_matches,
        \   'normal': [],
        \ }

The match specifications consist of arguments to `matchadd()`.

    [['highlight-group', 'pattern', priority], ...]

To highlight all characters beyond column 80 you could use this list of match
specifications:

    let s:expl_permanent_matches = [
        \   ["LineNr", '\%81v.\+', -70],
        \ ]

In insert mode, you might want to override the permanent match from above
with an unobtrusive undercurl and place a warning sign at column 70.  This is
what the following list of match-specifications does.

    let s:expl_insert_mode_matches = [
        \   ["Todo",  '\zs\%70v.\ze.*\%#', -50],
        \   ["Todo",  '\%#.*\zs\%70v.\ze', -50],
        \   ["Undercurl",  '\%81v.\+\%#.*$', -50],
        \   ["Undercurl",  '\%#.*\zs\%81v.\+\ze$', -50],
        \ ]

So there is a lot possible, but if you just want to highlight excess chars in
selected filetypes starting at different columns, you can use something like
this:

    let g:excess_lines_match_setup = {
        \ '*': { 'permanent': ["Error", '\%81v.\+', -50]},
        \ 'html': { 'permanent': ["Error", '\%91v.\+', -50]},
        \ 'text': { 'permanent': ["Error", '\%101v.\+', -50]},
        \ }

Note that each of the missing mode-keys of a specific filetype falls back to the
one in the default entry `*` individually.
