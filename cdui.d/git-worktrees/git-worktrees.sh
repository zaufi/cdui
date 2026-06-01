#!/bin/bash
#
# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#

# BEGIN Default config options
# TODO Think about to generate it, say from default (example) `config.yaml`
if [[ $(type -t cdui.config.plugins.git_worktrees.color.clean) != function ]]; then
    function cdui.config.plugins.git_worktrees.color.clean()
    {
        cdui.color2ansi 'bright_green'
    }
fi

if [[ $(type -t cdui.config.plugins.git_worktrees.color.untracked) != function ]]; then
    function cdui.config.plugins.git_worktrees.color.untracked()
    {
        cdui.color2ansi 'green dim'
    }
fi

if [[ $(type -t cdui.config.plugins.git_worktrees.color.modified) != function ]]; then
    function cdui.config.plugins.git_worktrees.color.modified()
    {
        cdui.color2ansi 'yellow'
    }
fi

if [[ $(type -t cdui.config.plugins.git_worktrees.color.staged) != function ]]; then
    function cdui.config.plugins.git_worktrees.color.staged()
    {
        cdui.color2ansi 'cyan'
    }
fi

if [[ $(type -t cdui.config.plugins.git_worktrees.color.conflict) != function ]]; then
    function cdui.config.plugins.git_worktrees.color.conflict()
    {
        cdui.color2ansi 'bright_red underline'
    }
fi

if [[ $(type -t cdui.config.plugins.git_worktrees.color.detached) != function ]]; then
    function cdui.config.plugins.git_worktrees.color.detached()
    {
        cdui.color2ansi 'magenta strike italic'
    }
fi

if [[ $(type -t cdui.config.plugins.git_worktrees.color.rebase) != function ]]; then
    function cdui.config.plugins.git_worktrees.color.rebase()
    {
        cdui.color2ansi 'bright_blue italic'
    }
fi

if [[ $(type -t cdui.config.plugins.git_worktrees.color.merge) != function ]]; then
    function cdui.config.plugins.git_worktrees.color.merge()
    {
        cdui.color2ansi 'bright_blue italic'
    }
fi

if [[ $(type -t cdui.config.plugins.git_worktrees.color.cherry_pick) != function ]]; then
    function cdui.config.plugins.git_worktrees.color.cherry_pick()
    {
        cdui.color2ansi 'bright_magenta italic'
    }
fi

if [[ $(type -t cdui.config.plugins.git_worktrees.color.revert) != function ]]; then
    function cdui.config.plugins.git_worktrees.color.revert()
    {
        cdui.color2ansi 'bright_cyan italic'
    }
fi

if [[ $(type -t cdui.config.plugins.git_worktrees.color.bisect) != function ]]; then
    function cdui.config.plugins.git_worktrees.color.bisect()
    {
        cdui.color2ansi 'bright_white italic'
    }
fi
# END Default config options

#
# Determine git worktree state.
#
# @param $1 -- worktree path
#
# @return output a state name or exit code `1` if not a Git work tree.
# A state name could be one of thefollowing:
#   clean
#   untracked
#   modified
#   staged
#   conflict
#   detached
#   rebase
#   merge
#   cherry_pick
#   revert
#   bisect
#
# NOTE The caller should make sure the passed work tree path is a really Git work tree.
#
function _cdui.git_worktrees.state()
{
    local -r worktree="${1}"

    local gitdir
    gitdir=$(git -C "${worktree}" rev-parse --git-dir 2>/dev/null) \
      || return 1

    # BEGIN Git operations in progress (highest priority)
    if [[ -d "${gitdir}"/rebase-merge || -d "${gitdir}"/rebase-apply ]]; then
        printf rebase
        return
    fi

    if [[ -f "${gitdir}"/MERGE_HEAD ]]; then
        printf merge
        return
    fi

    if [[ -f "${gitdir}"/CHERRY_PICK_HEAD ]]; then
        printf cherry_pick
        return
    fi

    if [[ -f "${gitdir}"/REVERT_HEAD ]]; then
        printf revert
        return
    fi

    if [[ -f "${gitdir}"/BISECT_LOG ]]; then
        printf bisect
        return
    fi
    # END Git operations in progress (highest priority)

    # BEGIN Content state
    local status
    status=$(git -C "${worktree}" status --porcelain 2>/dev/null)

    # Unmerged/conflicting paths.
    if grep -qE '^(DD|AU|UD|UA|DU|AA|UU)' <<< "${status}"; then
        printf conflict
        return
    fi

    # Detached HEAD.
    if ! git -C "${worktree}" symbolic-ref -q HEAD >/dev/null 2>&1; then
        printf detached
        return
    fi

    # Staged changes.
    if grep -qE '^[MADRCUT][[:space:]MADRCUT?]' <<< "${status}"; then
        printf staged
        return
    fi

    # Unstaged changes.
    if grep -qE '^.[MADRCUT]' <<< "${status}"; then
        printf modified
        return
    fi

    # Untracked files.
    if grep -q '^??' <<< "${status}"; then
        printf untracked
        return
    fi

    printf clean
    # END Content state
}

#
# Colorize a branch name based on the cleanliness of the worktree.
#
# @param $1 -- worktree path used to inspect git status
#
function _cdui.git_worktrees.colorize_branch()
{
    local -r worktree="${1}"

    local branch_state
    branch_state=$(_cdui.git_worktrees.state "${worktree}") || {
        cdui.color2ansi default
        return
    }

    local color_fn="cdui.config.plugins.git_worktrees.color.${branch_state}"
    if [[ $(type -t "${color_fn}") == function ]]; then
        "${color_fn}"
    else
        cdui.color2ansi default
    fi
}

#
# Return the Git worktrees list as a JSON array for the CDUI feed.
#
function cdui.git_worktrees.get_dirs()
{
    if ! git -C "${worktree}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf '[]\n'
        return 0
    fi

    local -a items=()
    while IFS=$'\t' read -r path ref; do
        items+=(
            "$(
                cdui.mkentry "${ref}" "${path}" "$(_cdui.git_worktrees.colorize_branch "${path}")"
              )"
          )
    done < <(
        git worktree list --porcelain \
      | awk '
            /^worktree / { path=$2 }
            /^branch refs\/heads\// { print path "\t" substr($0, 19) }
            /^HEAD / { head=$2 }
            /^detached/ { print path "\t" head }
          '
      )

    if ((${#items[@]} == 0)); then
        printf '[]\n'
        return 0
    fi

    printf '%s\n' "${items[@]}" | jq -s add
}
