-- Keybindings that nett-shell adds.
--
-- POLICY: ~/.config/hypr/bindings.conf is authoritative. This file only declares
-- binds for keys that Hyprland does NOT already handle. Nothing here overrides,
-- shadows, or duplicates an existing bind -- if a key already works, it keeps
-- working exactly as it does now, and nett-shell stays out of the way.
--
-- The compile pass emits these into ~/.config/hypr/nett-shell.conf, sourced AFTER
-- bindings.conf. Because a later `bind` for an already-bound key would override
-- rather than merge, the generator refuses to emit any key it finds in
-- bindings.conf and reports a conflict instead of silently winning.
--
-- Each entry:
--   key         "MODS, KEY" in Hyprland syntax; mods omitted for bare keys (", PRINT")
--   action      what the shell does (see the reference at the bottom)
--   arg         optional argument to the action
--   desc        shown by `hyprctl binds` and in the shell's keybind cheatsheet
--   name        explicit GlobalShortcut name; derived from action+arg otherwise
--   repeatable  fire continuously while held  -> Hyprland `bindel`
--   locked      fire even while the session is locked -> Hyprland `bindl`
--   exec        run this command through Hyprland instead of dispatching to the shell
--
-- =============================================================================
-- DELIBERATELY NOT HERE -- already implemented in bindings.conf
-- =============================================================================
--
-- Volume, mute, mic-mute, and media transport keys (XF86Audio*) are already bound
-- and routed through swayosd-client. They stay that way. nett-shell does not need
-- them, because its OSD watches Pipewire's *state* rather than listening for
-- keypresses: whatever changes the volume -- an existing keybind, a script,
-- wpctl, the control-centre slider, or a game's own mixer -- the OSD appears.
-- That is strictly better than owning the keys, and it means volume continues to
-- work when the shell is not running.
--
--   The one thing to fix at Wave 2, when swayosd-server is retired: repoint those
--   existing binds from `swayosd-client ...` to plain `wpctl` / `playerctl` calls,
--   still in bindings.conf. Keep them as `exec` -- do NOT convert them to
--   `global, nett:*`, or volume dies whenever the shell is down.
--
-- Brightness keys (XF86MonBrightness*) are also already bound, and are already
-- silent no-ops: both displays are external DisplayPort with no backlight, so
-- /sys/class/backlight is empty. Nothing to gain by touching them.
--
-- Also left alone: SUPER+RETURN, SUPER+F, SUPER+W, SUPER+SPACE, SUPER+J, SUPER+P,
-- SUPER+SHIFT+V, SHIFT/ALT+F11, SUPER+arrows, SUPER+SHIFT+arrows, ALT+TAB,
-- SUPER+1..0, SUPER+SHIFT+1..0, SUPER+mouse*, SUPER+code:20/21.
--
-- (The PANIC bind lives directly in bindings.conf, not here -- it has to exist
-- before nett-shell does, and it must survive nett-shell.conf not being sourced.)

local mod = "SUPER"

return {
  -- ---------------------------------------------------------------------------
  -- Popups and panels -- all of these keys are currently unbound
  -- ---------------------------------------------------------------------------
  { key = mod .. ", D",       action = "toggle", arg = "dashboard",     desc = "System dashboard" },
  { key = mod .. ", V",       action = "toggle", arg = "clipboard",     desc = "Clipboard history" },
  { key = mod .. ", N",       action = "toggle", arg = "notifications", desc = "Notification history" },
  { key = mod .. ", C",       action = "toggle", arg = "control",       desc = "Control centre" },
  { key = mod .. " SHIFT, D", action = "toggle", arg = "wallpaper",     desc = "Wallpaper switcher" },
  { key = mod .. " SHIFT, P", action = "toggle", arg = "power",         desc = "Power menu" },
  { key = mod .. " SHIFT, N", action = "dnd",                           desc = "Toggle do not disturb" },

  -- SUPER+SPACE is rofi today and stays rofi. Once the launcher genuinely beats
  -- it, move that one line in bindings.conf by hand -- deliberately a manual
  -- step, so the swap is a decision rather than a side effect of a config reload.

  -- ---------------------------------------------------------------------------
  -- Screenshots -- no screenshot bind exists today
  -- ---------------------------------------------------------------------------
  { key = mod .. " SHIFT, S", action = "screenshot", arg = "region",      desc = "Screenshot a region" },
  { key = mod .. " SHIFT, W", action = "screenshot", arg = "window",      desc = "Screenshot the active window" },
  { key = mod .. " SHIFT, F", action = "screenshot", arg = "output",      desc = "Screenshot this monitor" },
  { key = mod .. " SHIFT, A", action = "screenshot", arg = "annotate",    desc = "Screenshot a region and annotate" },
  { key = ", PRINT",          action = "screenshot", arg = "output-clip", desc = "Monitor to clipboard" },
  { key = mod .. ", PRINT",   action = "screenshot", arg = "region-clip", desc = "Region to clipboard" },

  -- ---------------------------------------------------------------------------
  -- Colour picker -- no bind exists today
  -- ---------------------------------------------------------------------------
  { key = mod .. " SHIFT, C", action = "colorpicker", desc = "Pick a colour" },

  -- ---------------------------------------------------------------------------
  -- Session -- no lock bind exists today
  -- ---------------------------------------------------------------------------
  -- `exec`, not a global shortcut, on purpose: locking must work even when the
  -- shell is dead. loginctl routes through hypridle's lock_cmd.
  { key = mod .. ", L", action = "exec", exec = "loginctl lock-session", desc = "Lock the session" },
}

-- Recognised actions:
--
--   toggle <popup>      toggle a registered popup by name
--   open <popup>        open it
--   close <popup>       close it
--   closeAll            close every popup
--   screenshot <mode>   region | window | output | annotate | region-clip | output-clip
--   colorpicker         pick a colour, copy it, show a swatch toast
--   volume <sign>       step by osd.volumeStep      (unbound here -- see the note above)
--   volumeFine <sign>   step by osd.volumeStepFine  (unbound here)
--   mute | micMute      toggle output / input mute  (unbound here)
--   media <op>          toggle | next | prev | stop (unbound here)
--   dnd                 toggle do-not-disturb
--   wallpaper <op>      next | prev | random
--   power <op>          lock | logout | suspend | reboot | shutdown
--   reloadConfig        recompile config.lua
--   exec                run `exec` verbatim through Hyprland
--
-- The audio and media actions still exist and are reachable via `qs ipc call`,
-- the control centre, and the OSD's own buttons -- they simply have no keybind,
-- because Hyprland already owns those keys.
