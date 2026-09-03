-- nett-shell configuration.
--
-- This is your file. Everything is optional: whatever you leave out falls back to
-- config/defaults.lua, which doubles as the reference documentation -- read it
-- when you want to know what an option does or what values it accepts.
--
-- It is real Lua, so variables, arithmetic, functions, and conditionals all work.
-- Saving this file recompiles and hot-reloads the shell; if it fails to compile,
-- the shell keeps the last good config and shows the error instead of going blank.
--
-- Helpers available here (needed only for EMPTY containers, where Lua cannot tell
-- a list from a map):
--     arr {}   an empty list        e.g. monitors = arr {}
--     map {}   an empty free-form map
--
-- GEOMETRY: Hyprland runs your displays at scale 1.25, so stick to multiples of 4
-- for insets/radii/heights -- they land on whole physical pixels, while other
-- values can render as a shimmering hairline. The compiler warns when it spots
-- one. (Qt itself has been observed reporting devicePixelRatio as 2 rather than
-- 1.25 here -- a known Qt/Wayland quirk, not something to work around; Hyprland
-- still positions and sizes windows using its own real 1.25.)

-- A couple of local values, to show why this is Lua and not JSON.
local red = "#CC0000"

return {
  theme = {
    accent = red,

    -- Compositor blur behind shell surfaces. Needs nett-shell.conf sourced from
    -- hyprland.conf, since the blur comes from generated layerrules.
    blur = false,
  },

  frame = {
    inset = 4,
    radius = 32,
    color = "",
  },

  bar = {
    height = 40,

    -- MIGRATION: while waybar still runs, give it one monitor and nett-shell the
    -- other so they never fight for the top edge. Two identical 4K panels makes
    -- this a genuinely good way to compare them side by side.
    --
    --   1. set this to { "DP-1" }
    --   2. in ~/.config/waybar/config.jsonc set  "output": ["DP-3"]
    --   3. killall -SIGUSR2 waybar     (reloads config without restarting)
    --
    -- Empty means every monitor.
    monitors = arr {},

    -- Reorder or remove freely. Names map to files in modules/bar/.
    -- modules = {
    --   left   = { "launcher", "workspaces", "updates" },
    --   center = { "window" },
    --   right  = { "stats", "tray", "profile", "audio", "bluetooth",
    --              "network", "clock", "notifications", "power" },
    -- },
  },

  workspaces = {
    persistent = 6,

    -- false keeps the current waybar behaviour: every bar shows all workspaces,
    -- with the other monitor's occupied ones dimmed. Setting this true shows only
    -- this monitor's workspaces, which is stricter but makes them appear to jump
    -- between bars as you move them -- Hyprland workspaces are global and live on
    -- one monitor at a time.
    perMonitor = false,
  },

  wallpaper = {
    -- ~/Pictures is mostly screenshots, so it is not a default. Add it if you
    -- keep wallpapers there too.
    directories = { "~/Wallpapers" },

    -- "shared" puts the same image on both monitors; "per-monitor" uses the
    -- perMonitor table below.
    mode = "shared",
    shared = "~/Pictures/nebula-2560x1600-red-hd-9375.jpg",

    -- perMonitor = {
    --   ["DP-1"] = "~/Wallpapers/left.jpg",
    --   ["DP-3"] = "~/Wallpapers/right.jpg",
    -- },
  },

  -- Keybinds live in config/keybinds.lua, not here -- they are generated into
  -- ~/.config/hypr/nett-shell.conf, and only for keys Hyprland does not already
  -- bind. Your existing bindings.conf always wins.

  hyprland = {
    -- Emit border colours and gaps derived from this theme, so window chrome
    -- tracks the shell instead of drifting from it. Set either to false to keep
    -- looknfeel.conf fully in charge.
    emitColors = true,
    emitGaps = true,

    -- The frame's rounded corners and the window inset must agree, or the corners
    -- clip windows. This is that one number.
    gapsOut = 12,
    gapsIn = 5,
  },

  notifications = {
    position = "top-right",

    -- "" follows the focused monitor. Set to "DP-1" or "DP-3" to pin them.
    monitor = "",
  },

  osd = {
    -- Volume and media keys stay bound in bindings.conf as they are today. The
    -- OSD watches Pipewire's state rather than the keypress, so it appears no
    -- matter what changed the volume.
    volumeStep = 0.05,
    maxVolume = 1.5,

    -- Both displays are external DisplayPort with no backlight, so there is
    -- nothing to control. Leave this alone unless the hardware changes.
    brightnessBackend = "none",
  },

  updates = {
    aurHelper = "yay",
  },

  power = {
    -- Hibernate cannot work on this machine: swap is zram, and there is no
    -- resume= kernel parameter. "auto" probes for both and hides the tile.
    hibernate = "auto",
  },

  debug = {
    logIpc = true, -- TEMPORARY DEBUG, remove before this segment is done
  },
}
