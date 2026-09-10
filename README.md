<!--
SPDX-FileCopyrightText: Alex Turbov <zaufi@pm.me>
SPDX-License-Identifier: CC0-1.0
-->

# cdui

`cdui` is a Bash helper that opens a terminal UI for quickly changing
directories. It collects directory candidates from small plugins, shows them
through [`skim`] fuzzy finder, and changes the current shell directory with
`pushd`.

The project is intentionally shell-native: the interactive command is a Bash
function, the feed layer speaks JSON through `jq`, and configuration is loaded
from an XDG-style YAML file.

## Features

- Interactive directory picker backed by `sk`.
- Plugin-based directory feeds.
- Runtime hotkeys for switching feeds inside the picker.
- Recent-directory tracking after each successful selection.
- User configuration in `${XDG_CONFIG_HOME:-$HOME/.config}/cdui/config.yaml`.
- Colorized entries, including missing directories and Git worktree states.

## Runtime Requirements

- Bash
- `sk`
- `jq`
- common POSIX/GNU command-line tools used by the scripts: `grep`, `sed`,
  `cut`, `sort`, and `head`

Optional runtime tools:

- `git`, for the Git worktree feed
- `awk`, for the Midnight Commander hotlist converter

## Install

Install with CMake:

```sh
cmake --install build
```

The install step places the executable scripts under the configured
`libexec/cdui` directory, installs the built-in plugins, installs
`config-example.yaml`, and installs a profile script that sources `cdui.sh`.

For a manual shell setup, source the generated or installed `cdui.sh` from an
interactive Bash startup file:

```sh
. /path/to/cdui.sh
```

After that, run:

```sh
cdui
```

When you choose an entry, `cdui` updates plugin state and runs `pushd` to move
the current shell into the selected directory.

See [DEVELOPMENT.md](DEVELOPMENT.md) for source builds, tests, and plugin
authoring details.

## Configuration

The user configuration file is:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/cdui/config.yaml
```

If the file does not exist, generated defaults are used.

Example:

```yaml
border: rounded

color:
  url: cyan italic
  current-url: white dim italic
  missed-url: red italic strike
  error: red
```

Color strings may contain ANSI style names, named colors, `fg:`/`bg:` prefixes,
hex colors such as `#ff0000`, and `rgb(R,G,B)` values.

## Built-In Plugins

### Midnight Commander Hotlist

Option: `-m`, `--mc-hotlist`

Reads a Midnight Commander hotlist and converts it to the JSON feed format.
The default hotlist path is:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/mc/hotlist
```

Set `CDUI_MC_HOTLIST` to use a different file.

### Recent Directories

Option: `-r`, `--recent`

Tracks directories selected through `cdui` and lists the most recently used
entries, with selection count as a tie-breaker.

Usage statistics are stored as a serialized Bash associative array mapping each
directory to its selection count and last-use timestamp, in:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/cdui/recent-dirs.bash
```

Set `SP_CDUI_RECENT_DIRS_COUNT` to control how many recent directories are
shown. The default is `25`. The list is built from the statistics on every
run, so a change takes effect immediately.

### Git Worktrees

Option: `-g`, `--git-worktrees`

When run inside a Git worktree, lists all worktrees for the repository. Entries
are labeled by branch name or detached HEAD and can be colorized by state:
`clean`, `untracked`, `modified`, `staged`, `conflict`, `detached`, `rebase`,
`merge`, `cherry_pick`, `revert`, and `bisect`.

### Environment Directories

Option: `-e`, `--env`

Scans environment variables for values that look like absolute or home-relative
directory paths. It supports single paths and simple `:` or space-separated
path lists.

## License

The code is licensed under GPL-3.0-or-later. Documentation and repository
metadata use CC0-1.0 where indicated by SPDX headers.

[`skim`]: https://github.com/lotabout/skim
