# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

# --- duplicate options ---
( [.[] | .options[]]
  | group_by(.)
  | map(select(length > 1))
  | .[]
  | .[]
  | "ERR_DUP_OPT\t\(.)"
),

# --- duplicate hotkeys ---
( [.[] | .hotkey]
  | group_by(.)
  | map(select(length > 1))
  | .[]
  | .[]
  | "ERR_DUP_KEY\t\(.)"
),

# --- option -> entrypoint mapping ---
( .[]
  | .entrypoint as $e
  | .options[]
  | "MAP\t\(.)\t\($e)"
),

# --- entrypoint -> icon mapping ---
( .[]
  | "ICON\t\(.entrypoint)\t\(.icon)"
)
