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

# --- plugin data ---
( .[]
  | .id as $id
  | .entrypoint as $e
  | .icon as $c
  | (.enabled // true) as $s
  | .options[]
  | "DATA\t\($id)\t\($e)\t\(.)\t\($s)\t\($c)"
)
