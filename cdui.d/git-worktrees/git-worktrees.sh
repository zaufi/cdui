#!/bin/bash
#
# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#

# BEGIN Default config options
function cdui.config.plugin.git_worktrees.green()
{
    cdui.color2ansi 'green'
}

function cdui.config.plugin.git_worktrees.dirty()
{
    cdui.color2ansi 'yellow'
}
# END Default config options

#
# Colorize a branch name based on the cleanliness of the worktree.
#
# @param $1 -- worktree path used to inspect git status
#
function _cdui.git_worktrees.colorize_branch()
{
    local -r worktree="${1}"

    local branch_color
    if [[ -z $(git -C "${worktree}" status --short 2>/dev/null) ]]; then
        branch_color=$(cdui.config.plugin.git_worktrees.green)
    else
        branch_color=$(cdui.config.plugin.git_worktrees.dirty)
    fi

    printf '%s' "${branch_color}"
}

#
# Return the Git worktrees list as a JSON array for the CDUI feed.
#
function cdui.git_worktrees.get_dirs()
{
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
