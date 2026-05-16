# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

def walk($p):
  (.properties // {})
  | to_entries[]
  | (.key | gsub("-"; "_")) as $key
  | ($p + [$key]) as $path
  | .value as $v
  | if $v.default != null then
      "\($path | join("."))=\($v.default)"
    else
      empty
    end,
    ($v | walk($path));

walk([])
