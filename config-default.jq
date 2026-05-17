# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

def walk($p):
  (.properties // {})
  | to_entries[]
  | (.key | gsub("-"; "_")) as $key
  | ($p + [$key]) as $path
  | .value as $v
  | if $v.default != null then
      ($path | join(".")) as $config_path
      | ($v.default | tostring) as $default_value
      | "function cdui.config.\($config_path)()\n{\n    "
          + if ".\($config_path)." | contains(".color.") then
              "cdui.color2ansi \($default_value | @sh)"
            else
              "printf '%s' \($default_value | @sh)"
            end
          + "\n}\n"
    else
      empty
    end,
    ($v | walk($path));

walk([])
