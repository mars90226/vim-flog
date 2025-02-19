"
" This file contains functions for generating the commit graph in Vim.
"

function! flog#graph#vim#Get(git_cmd) abort
  call flog#floggraph#buf#AssertFlogBuf()

  let l:lua_path_info = flog#lua#SetLuaPath()
  let l:graph = v:none

  try
    if flog#lua#ShouldUseInternal()
      let l:graph = flog#graph#vim#internal#Get(a:git_cmd)
    else
      let l:graph = flog#graph#vim#bin#Get(a:git_cmd)
    endif
  finally
    call flog#lua#ResetLuaPath(l:lua_path_info)
  endtry

  return l:graph
endfunction

function! flog#graph#vim#Update(git_cmd) abort
  call flog#floggraph#buf#AssertFlogBuf()

  let l:lua_path_info = flog#lua#SetLuaPath()
  let l:graph = v:none

  try
    if flog#lua#ShouldUseInternal()
      let l:graph = flog#graph#vim#internal#Update(a:git_cmd)
    else
      let l:graph = flog#graph#vim#bin#Update(a:git_cmd)
    endif
  finally
    call flog#lua#ResetLuaPath(l:lua_path_info)
  endtry

  return l:graph
endfunction
