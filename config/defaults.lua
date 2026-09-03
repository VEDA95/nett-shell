-- The complete default configuration. This file IS the schema: every option the
-- shell reads must appear here, because the merge step uses it to validate types,
-- fill gaps, and decide which keys are real. Adding an option means adding it here
-- first, then declaring the matching property in config/Config.qml.
--
-- Users never edit this file -- they edit config.lua and override only what they
-- want. Keep the comments here explanatory; they are the reference documentation.
--
-- GEOMETRY RULE: Hyprland has these displays at scale 1.25 (confirmed via
-- `hyprctl monitors`), so a logical value that isn't a multiple of 4 can land on
-- a fractional physical pixel (4 x 1.25 = 5) and render as a shimmering hairline.
-- Every inset, radius, height, and stroke width below comes from
-- {4, 8, 12, 16, 20, ...} for that reason.
--
-- Note: Quickshell's own ShellScreen.devicePixelRatio has been observed
-- reporting 2 rather than 1.25 on this system -- a known Qt/Wayland limitation
-- (Qt's Wayland QPA plugin falls back to the legacy integer wl_output.scale,
-- ceil(1.25) = 2, for scale factors between 100% and 200% rather than
-- negotiating wp-fractional-scale-v1). Hyprland still positions and sizes
-- windows using its own real 1.25, which is why layout is unaffected; Qt just
-- oversamples its own render buffer as a result, a memory/GPU cost rather than
-- a visual bug. The multiples-of-4 rule is chosen to stay safe under either
-- number, since 4 is also a clean multiple under the fallback integer scale.

local json = require("json")
local arr, map = json.arr, json.map

return {
  -- ---------------------------------------------------------------------------
  -- Rounded screen frame
  -- ---------------------------------------------------------------------------
  frame = {
    enabled = true,
    inset = 4,          -- thickness of the black border, logical px (-> 5 physical)
    radius = 32,        -- corner radius (-> 40 physical)
    color = "",         -- "" follows theme.void
    -- Draw the corners on the Overlay layer, above windows. When false they are
    -- drawn on the Background layer, which means windows cover them -- only
    -- useful if the overlay ever misbehaves on a future compositor version.
    aboveWindows = true,
  },

  -- ---------------------------------------------------------------------------
  -- Top bar
  -- ---------------------------------------------------------------------------
  bar = {
    enabled = true,
    position = "top",   -- "top" | "bottom"
    height = 40,        -- logical px; exclusiveZone becomes frame.inset + this
    pillRadius = 20,    -- module-group corner radius; height/2 gives a full pill
    gap = 8,            -- gap between module groups
    padding = 8,        -- inner padding within a group
    spacing = 4,        -- gap between modules inside a group
    jointRadius = 12,   -- radius of the concave joints where a group meets the frame

    -- Which monitors get a bar. Empty means all of them.
    -- During migration, set this to { "DP-1" } and point waybar at DP-3 so both
    -- can run side by side without fighting for the top edge.
    monitors = arr {},

    -- Module layout. Names resolve to files in modules/bar/. Reorder freely;
    -- remove a name to drop the module entirely.
    modules = {
      left   = arr { "launcher", "workspaces", "updates" },
      center = arr { "window" },
      right  = arr { "stats", "tray", "profile", "audio", "bluetooth",
                     "network", "clock", "notifications", "power" },
    },

    -- Weld the outermost groups into the screen corners: their outer top corner
    -- takes frame.radius and a concave joint fills the seam underneath.
    weldEnds = true,
  },

  -- ---------------------------------------------------------------------------
  -- Workspaces
  -- ---------------------------------------------------------------------------
  workspaces = {
    persistent = 6,     -- always show slots 1..N, even when empty

    -- false: every bar shows all workspaces, with the other monitor's occupied
    --   ones dimmed. Matches the current waybar behaviour.
    -- true: each bar shows only its own monitor's workspaces. Strictly correct,
    --   but workspaces appear to jump between bars as you move them, because
    --   Hyprland workspaces are global and live on one monitor at a time.
    perMonitor = false,

    showNumbers = true,
    scrollToSwitch = true,
    indicator = "pill",  -- "pill" | "underline" | "none"
  },

  -- ---------------------------------------------------------------------------
  -- Theme
  -- ---------------------------------------------------------------------------
  theme = {
    accent = "#CC0000",     -- drives the whole accent ramp
    opacity = 1.0,          -- surface opacity, 0..1
    radiusScale = 1.0,      -- multiplies every radius token
    fontScale = 1.0,        -- multiplies every font size

    fontSans = "JetBrainsMono Nerd Font Propo",
    fontMono = "JetBrainsMono Nerd Font Mono",
    fontIcon = "Material Symbols Rounded",
    fontAccent = "Symbols Nerd Font",   -- Arch logo, powerline glyphs

    -- Compositor blur behind shell surfaces. Needs the generated layerrules,
    -- so it only takes effect once nett-shell.conf is sourced.
    blur = false,

    -- Derive the accent from the current wallpaper via ColorQuantizer instead of
    -- using theme.accent. Off by default: the point of this shell is a fixed
    -- black/blood-red identity.
    accentFromWallpaper = false,

    -- Free-form overrides for any individual palette token, by name.
    -- e.g. tokens = { border = "#3A2A2C", textDim = "#A09090" }
    tokens = map {},
  },

  -- ---------------------------------------------------------------------------
  -- Popups
  -- ---------------------------------------------------------------------------
  popups = {
    -- 0 by design, not a placeholder: Brain Shell's own reference video
    -- shows every anchored popup flush against the bar, no floating gap --
    -- see framework/PopupSurface.qml. Left as a knob in case some future
    -- popup genuinely wants breathing room.
    gap = 0,
    radius = 16,
    grabFocus = true,    -- click outside to dismiss
    followFocusedMonitor = true,
    animate = true,
  },

  -- ---------------------------------------------------------------------------
  -- Animation
  -- ---------------------------------------------------------------------------
  animation = {
    enabled = true,
    scale = 1.0,         -- multiplies every duration; 0 disables motion
    fast = 160,
    base = 260,
    slow = 380,
    exit = 160,          -- always shorter than the enter it mirrors
  },

  -- ---------------------------------------------------------------------------
  -- App launcher
  -- ---------------------------------------------------------------------------
  launcher = {
    maxResults = 30,
    -- Launch through uwsm-app so apps land in their own systemd scope, matching
    -- how autostart.conf already launches everything.
    useUwsm = true,
    terminal = "ghostty",
    showIcons = true,
    iconSize = 40,
    frecency = true,     -- rank by how often and how recently you launch things
    -- Search-field mode prefixes. Set any to "" to disable that mode.
    prefixes = {
      run = ">",
      calc = "=",
      window = "?",
      file = "/",
      action = ":",
    },
  },

  -- ---------------------------------------------------------------------------
  -- Notifications
  -- ---------------------------------------------------------------------------
  notifications = {
    enabled = true,
    position = "top-right",   -- top-right | top-left | bottom-right | bottom-left
    width = 400,
    maxVisible = 5,
    spacing = 8,
    -- "" follows the focused monitor; a name like "DP-1" pins them there.
    monitor = "",
    -- Re-target the stack only when it goes empty, never while cards are live,
    -- so it cannot teleport mid-read because you changed focus.
    followFocus = true,

    timeoutLow = 4000,
    timeoutNormal = 6000,
    timeoutCritical = 0,      -- 0 = never auto-dismiss

    historyLimit = 100,
    persistHistory = true,    -- survive a shell restart

    dnd = {
      allowCritical = true,
      autoFullscreen = true,  -- suppress popups while a workspace has a fullscreen window
    },
  },

  -- ---------------------------------------------------------------------------
  -- On-screen displays
  -- ---------------------------------------------------------------------------
  osd = {
    enabled = true,
    position = "bottom",
    marginBottom = 120,
    timeout = 1800,
    width = 320,
    volumeStep = 0.05,
    volumeStepFine = 0.01,
    maxVolume = 1.5,          -- allow overshoot above 100%
    showOnTrackChange = true,

    -- No controllable backlight exists on this machine: both displays are
    -- external DisplayPort with no backlight device, so "none" is correct.
    -- "ddcutil" needs i2c-dev loaded and the user in an i2c group, and DDC/CI
    -- writes take 100-300ms, which makes an OSD feel broken.
    brightnessBackend = "none",   -- "none" | "ddcutil"
  },

  -- ---------------------------------------------------------------------------
  -- Control centre
  -- ---------------------------------------------------------------------------
  control = {
    width = 420,
    defaultSection = "audio",   -- audio | bluetooth | network | power
    showQuickRow = true,
    -- Interfaces to hide from the network section and from throughput totals.
    -- Without this, docker and bridge interfaces badly pollute the numbers.
    ignoreInterfaces = arr { "lo", "docker*", "br-*", "veth*", "virbr*" },
    -- Terminal escape hatches for what the APIs cannot do (VPNs, 802.1X, routing).
    audioTool = "wiremix",
    bluetoothTool = "bluetui",
    networkTool = "nmtui",
  },

  -- ---------------------------------------------------------------------------
  -- System monitor / dashboard
  -- ---------------------------------------------------------------------------
  dashboard = {
    -- Poll intervals in ms. The bar's mini-widgets use the idle tier; opening the
    -- dashboard raises the rate and adds groups. With no consumers, timers stop.
    intervalIdle = 3000,
    intervalActive = 1000,
    intervalDisk = 30000,
    historyLength = 120,      -- sparkline samples

    showGpu = true,
    showPerCore = true,
    showDisk = true,
    diskMounts = arr { "/", "/home" },
    -- Default to the interface holding the default route.
    netInterface = "",

    -- Temperature warning thresholds in degrees C. GPU memory idles near 82 on
    -- this card by design, so it needs a much higher threshold than the others
    -- or the chip reads red permanently.
    tempWarn = { cpu = 85, gpuEdge = 90, gpuJunction = 100, gpuMem = 95 },
  },

  -- ---------------------------------------------------------------------------
  -- Updates
  -- ---------------------------------------------------------------------------
  updates = {
    enabled = true,
    intervalRepo = 1800000,   -- 30 min
    intervalAur = 10800000,   -- 3 h
    aurHelper = "yay",        -- paru is not installed on this machine
    -- Skip the check unless connectivity is Full. Stops it hammering mirrors
    -- behind a captive portal or on a dead link.
    requireConnectivity = true,
    -- Watch the pacman database and re-check shortly after it changes, so the
    -- count is never stale after an update.
    watchPacmanDb = true,
    hideWhenZero = true,
    -- Adding one of these to the pending set flags "reboot recommended".
    rebootPackages = arr { "linux", "linux-*", "mesa", "systemd", "nvidia*" },
    terminalCommand = arr { "ghostty", "--class=update.float", "--title=Updates" },
  },

  -- ---------------------------------------------------------------------------
  -- Clipboard
  -- ---------------------------------------------------------------------------
  clipboard = {
    enabled = true,
    maxEntries = 200,
    showImages = true,
    -- Send Ctrl+V to the focused window after copying. Off by default: it
    -- misfires in terminals and modal editors.
    autoPaste = false,
  },

  -- ---------------------------------------------------------------------------
  -- Screenshots
  -- ---------------------------------------------------------------------------
  screenshot = {
    directory = "~/Pictures/Screenshots",
    filename = "Screenshot_%Y-%m-%d_%H-%M-%S.png",
    copyToClipboard = true,
    showToast = true,
    toastTimeout = 6000,
    annotateTool = "satty",
    -- slurp selection colours, so even the OS-level picker matches the shell.
    slurpArgs = arr { "-d", "-b", "00000080", "-c", "CC0000ff", "-s", "CC000020", "-w", "2" },
  },

  -- ---------------------------------------------------------------------------
  -- Colour picker
  -- ---------------------------------------------------------------------------
  colorPicker = {
    defaultFormat = "hex",    -- hex | rgb | hsl | rgba
    historyLimit = 50,
    -- Freeze every display while picking, not just the active one, so the other
    -- monitor stops animating under the magnifier.
    freezeAll = true,
  },

  -- ---------------------------------------------------------------------------
  -- Wallpaper
  -- ---------------------------------------------------------------------------
  wallpaper = {
    -- ~/Pictures is mostly screenshots on this machine, so it is not a default.
    directories = arr { "~/Wallpapers" },
    mode = "shared",          -- "shared" | "per-monitor"
    shared = "",
    perMonitor = map {},      -- { ["DP-1"] = "/path.jpg", ["DP-3"] = "..." }
    fadeMs = 700,
    fillMode = "crop",        -- crop | fit | stretch | tile
    thumbnailSize = arr { 480, 270 },
    recursive = true,
  },

  -- ---------------------------------------------------------------------------
  -- Power menu
  -- ---------------------------------------------------------------------------
  power = {
    -- SIGTERM every client and wait, so editors can save before the session ends.
    gracefulShutdown = true,
    gracePeriod = 5000,
    -- Reboot / shutdown / logout need a deliberate confirm, since the tiles are
    -- large and sit where the cursor rests.
    confirmDestructive = true,
    -- Hibernate cannot work here: swap is zram (RAM-backed, so it cannot hold a
    -- hibernation image) and there is no resume= kernel parameter. "auto" probes
    -- for both and hides the tile when they fail; true/false force it.
    hibernate = "auto",
    logoutCommand = arr { "uwsm", "stop" },
  },

  -- ---------------------------------------------------------------------------
  -- Lock screen
  -- ---------------------------------------------------------------------------
  lock = {
    -- Reuse the existing, known-good PAM service. unix_chkpwd is setuid root, so
    -- no privileged setup is needed.
    pamConfig = "hyprlock",
    background = "",          -- "" uses the current wallpaper
    backgroundDim = 0.55,
    blur = true,
    showMedia = true,
    clockFormat = "hh:mm",
    dateFormat = "dddd, MMMM d",
    -- Release the lock if the compositor never confirms all screens are covered,
    -- rather than holding a lock nothing can unlock.
    secureTimeout = 3000,
    maxTriesCooldown = 30000,
  },

  -- ---------------------------------------------------------------------------
  -- Hyprland integration (generated ~/.config/hypr/nett-shell.conf)
  -- ---------------------------------------------------------------------------
  hyprland = {
    -- Emit keybinds derived from keybinds.lua.
    emitBinds = true,
    -- Emit border colours from the theme, so window borders track the shell.
    emitColors = true,
    -- "" derives the active border from theme.accent.
    activeBorder = "",
    inactiveBorder = "#2A1E20",
    activeBorderAlpha = "ee",
    inactiveBorderAlpha = "ff",
    -- Emit gaps_out. The frame's rounded corners and the window inset must agree
    -- or the corners clip windows, so they come from one number.
    emitGaps = true,
    gapsOut = 12,
    gapsIn = 5,
    -- Emit layerrules (blur, ignorealpha) for the shell's own namespaces.
    emitLayerRules = true,
    shortcutAppId = "nett",
  },

  -- ---------------------------------------------------------------------------
  -- Debug
  -- ---------------------------------------------------------------------------
  debug = {
    -- Show a toast when config.lua fails to compile. The bar also keeps a
    -- persistent red dot while broken, so a dismissed toast cannot hide it.
    showConfigErrors = true,
    logIpc = false,
    showFps = false,
  },
}
