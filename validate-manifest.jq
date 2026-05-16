# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

type == "object"
  and has("id") and (.id | type == "string")
  and has("options") and (.options | type == "array" and all(.[]; type == "string"))
  and has("hotkey") and (.hotkey | type == "string")
  and has("description") and (.description | type == "string")
  and has("order") and (.order | type == "number")
  and has("entrypoint") and (
    .entrypoint | test("^[^:]+:[^:]+(:[^:]+)?$")
  )
