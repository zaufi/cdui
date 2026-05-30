# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

def pad($w): . + (" " * ($w - (. | length)));

def color_url($prefix; $suffix): $prefix + . + $suffix;

def display_url($url):
  if $home != "" and ($url | startswith($home)) then
    "~" + ($url[$home|length:])
  else
    $url
  end;

def pluralize($count; $unit): "\($count) \($unit)\(if $count == 1 then "" else "s" end) ago";

def ago_time:
  . as $timestamp
  | (now - $timestamp | floor) as $elapsed
  | if $elapsed <= 0 then "just now"
    elif $elapsed < 60 then pluralize($elapsed; "second")
    elif $elapsed < 3600 then pluralize(($elapsed / 60 | floor); "minute")
    elif $elapsed < 86400 then pluralize(($elapsed / 3600 | floor); "hour")
    elif $elapsed < 604800 then pluralize(($elapsed / 86400 | floor); "day")
    elif $elapsed < 2592000 then pluralize(($elapsed / 604800 | floor); "week")
    elif $elapsed < 31536000 then pluralize(($elapsed / 2592000 | floor); "month")
    else pluralize(($elapsed / 31536000 | floor); "year")
    end;

def entry_to_display:
  if type == "number" then
    ago_time
  elif type == "string" and test("^[0-9]{10}(\\.[0-9]+)?$") then
    tonumber | ago_time
  else
    tostring
  end;

map([.origin, (.entry | entry_to_display), .url, (.missing_url // false)]) as $rows
  | [
      ($rows | map(.[0] | length) | max),
      ($rows | map(.[1] | length) | max)
    ] as $w
  | $rows[]
  | [
      (.[0] | pad($w[0])),
      (.[1] | pad($w[1])),
      (
        .[2] as $url
        | display_url($url) as $shown_url
        | if .[3] then
            ($shown_url | color_url($missed_url_color; $reset_color))
        elif $url == $pwd then
          ($shown_url | color_url($current_url_color; $reset_color))
        else
            ($shown_url | color_url($url_color_prefix; $reset_color))
          end
      ),
    .[2]
    ]
  | @tsv
