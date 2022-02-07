vim9script

#
# This file contains functions for handling args to the ":Floggit" command.
#

import autoload 'flog.vim'

import autoload 'flog/args.vim' as flog_args
import autoload 'flog/fugitive.vim'
import autoload 'flog/list.vim'
import autoload 'flog/shell.vim'
import autoload 'flog/state.vim' as flog_state

import autoload 'flog/floggraph/buf.vim'
import autoload 'flog/floggraph/commit.vim' as floggraph_commit

export def Parse(arg_lead: string, cmd_line: string, cursor_pos: number): list<any>
  const split_args = split(cmd_line[ : cursor_pos], '\s', true)
  const nargs = len(split_args)

  # Find command

  var command_index = 1
  var command = ''
  while command_index < nargs
    const arg = split_args[command_index]

    if !empty(arg) && arg[0] != '-'
      command = arg
      break
    endif

    command_index += 1
  endwhile

  # Return

  var is_command = false

  if command_index == nargs
    command_index = -1
  elseif command_index == nargs - 1
    is_command = true
  endif

  return [split_args, command_index, command, is_command]
enddef

export def CompleteCommitRefs(commit: dict<any>): list<string>
  var completions = []

  for ref in flog_state.GetCommitRefs(commit)
    if !empty(ref.remote)
      # Add remote
      const remote = ref.prefix .. ref.remote
      if index(completions, remote) < 0
        add(completions, remote)
      endif

      # Add remote branch
      if index(completions, ref.full) < 0
        add(completions, ref.full)
      endif

      # Add local branch
      if index(completions, ref.tail) < 0
        add(completions, ref.tail)
      endif
    elseif index(completions, ref.full) < 0
      # Add special/tag/branch
      add(completions, ref.full)
    endif

    # Add original path
    if !empty(ref.orig)
      add(completions, ref.orig)
    endif
  endfor

  return completions
enddef

export def CompleteFlog(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
  const line = line('.')
  const firstline = line("'<")
  const lastline = line("'>")

  var is_range = (line == firstline || line == lastline) && firstline != lastline
  var first_commit = {}
  var last_commit = {}

  if is_range
    first_commit = floggraph_commit.GetAtLine(firstline)
    last_commit = floggraph_commit.GetAtLine(lastline)
    is_range = first_commit != last_commit
  endif

  var completions: list<string> = []

  if is_range
    # Complete range

    const has_first = !empty(first_commit)
    const has_last = !empty(last_commit)

    if has_first
      add(completions, first_commit.hash)
    endif

    if has_last
      add(completions, last_commit.hash)
    endif

    if has_first && has_last
      add(completions, last_commit.hash .. '^..' .. first_commit.hash)
    endif

    if has_first
      completions += CompleteCommitRefs(first_commit)
      if has_last
        var last_completions = CompleteCommitRefs(last_commit)
        completions += list.Exclude(last_completions, completions)
      endif
    else
      completions += CompleteCommitRefs(last_commit)
    endif

    return completions
  else
    # Complete single line

    const commit = floggraph_commit.GetAtLine('.')
    if empty(commit)
      return []
    endif
    completions = [commit.hash] + CompleteCommitRefs(commit)
  endif

  completions = flog_args.FilterCompletions(arg_lead, completions)
  return completions
enddef

export def Complete(arg_lead: string, cmd_line: string, cursor_pos: number): list<string>
  const is_flog = buf.IsFlogBuf()
  const has_state = flog_state.HasBufState()

  const [_, command_index, command, is_command] = Parse(
    arg_lead, cmd_line, cursor_pos)

  const fugitive_completions = fugitive.Complete(
    shell.Escape(arg_lead), cmd_line, cursor_pos)

  # Complete git/command args only
  if is_command || command_index < 0
    return fugitive_completions
  endif

  var completions: list<string> = []

  # Complete line
  if is_flog
    completions += shell.EscapeList(
      CompleteFlog(arg_lead, cmd_line, cursor_pos))
  endif

  # Complete state
  if has_state
    const opts = flog_state.GetBufState().opts

    if !empty(opts.limit)
      const [range, path] = flog_args.SplitGitLimitArg(opts.limit)
      var paths = flog_args.FilterCompletions(arg_lead, [path])
      paths = shell.EscapeList(paths)
      completions += list.Exclude(paths, completions)
    endif

    if !empty(opts.path)
      var paths = flog#FilterCompletions(arg_lead, opts.paths)
      paths = shell.EscapeList(paths)
      completions += list.Exclude(paths, completions)
    endif
  endif

  # Complete Fugitive
  completions += list.Exclude(fugitive_completions, completions)

  return completions
enddef
