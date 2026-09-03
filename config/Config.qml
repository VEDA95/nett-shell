pragma Singleton

// The compiled configuration, as QML properties.
//
// Mirrors config/defaults.lua. Adding an option means adding it in BOTH places:
// defaults.lua defines it for the merge/validation pass, this file exposes it to
// the shell. That duplication is deliberate -- JsonAdapter reflects only declared
// properties and silently drops the rest, so a declaration here is what makes an
// option real, and the QML default is the backstop when config.json is missing,
// truncated, or written by an older version.
//
// Two conventions worth knowing:
//
//   * Scalars are declared with their type, so they get validation and defaults.
//   * Variable-shape data -- module lists, token overrides, per-monitor maps --
//     is `property var`, arriving as plain JS objects and arrays. This is how a
//     type that structurally cannot do arbitrary keys still supports a free-form
//     token map.
//
// blockWrites is MANDATORY, not a precaution: without it JsonAdapter writes back
// on any property change, which the watcher sees as a file change, which triggers
// a recompile, which writes again -- an infinite loop.

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property alias fileView: view
    readonly property bool loaded: view.loaded

    // ---- section accessors, so nothing reaches into fileView.adapter ----
    readonly property JsonObject frame: adapter.frame
    readonly property JsonObject bar: adapter.bar
    readonly property JsonObject workspaces: adapter.workspaces
    readonly property JsonObject theme: adapter.theme
    readonly property JsonObject popups: adapter.popups
    readonly property JsonObject animation: adapter.animation
    readonly property JsonObject launcher: adapter.launcher
    readonly property JsonObject notifications: adapter.notifications
    readonly property JsonObject osd: adapter.osd
    readonly property JsonObject control: adapter.control
    readonly property JsonObject dashboard: adapter.dashboard
    readonly property JsonObject updates: adapter.updates
    readonly property JsonObject clipboard: adapter.clipboard
    readonly property JsonObject screenshot: adapter.screenshot
    readonly property JsonObject colorPicker: adapter.colorPicker
    readonly property JsonObject wallpaper: adapter.wallpaper
    readonly property JsonObject power: adapter.power
    readonly property JsonObject lock: adapter.lock
    readonly property JsonObject hyprland: adapter.hyprland
    readonly property JsonObject debug: adapter.debug

    // Not a config.lua option -- compile.lua derives this from keybinds.lua and
    // injects it post-merge, purely so Shortcuts.qml has something to build
    // GlobalShortcut instances from. Excludes `exec` entries, which Hyprland
    // dispatches directly and never involve the shell.
    readonly property var keybinds: adapter.keybinds

    FileView {
        id: view
        path: Paths.configJson
        watchChanges: true
        blockWrites: true      // see the note above -- do not remove
        printErrors: false     // ConfigError owns error reporting

        onLoadFailed: error => {
            // Missing on first run, before compile.lua has been invoked. Every
            // property below already holds its default, so the shell still runs.
            ConfigError.noteLoadFailure(error);
        }

        JsonAdapter {
            id: adapter

            property JsonObject frame: JsonObject {
                property bool enabled: true
                property int inset: 4
                property int radius: 32
                property string color: ""
                property bool aboveWindows: true
            }

            property JsonObject bar: JsonObject {
                property bool enabled: true
                property string position: "top"
                property int height: 40
                property int pillRadius: 20
                property int gap: 8
                property int padding: 8
                property int spacing: 4
                property int jointRadius: 12
                property bool weldEnds: true
                property var monitors: []
                property var modules: ({
                        left: ["launcher", "workspaces", "updates"],
                        center: ["window"],
                        right: ["stats", "tray", "profile", "audio", "bluetooth",
                                "network", "clock", "notifications", "power"]
                    })
            }

            property JsonObject workspaces: JsonObject {
                property int persistent: 6
                property bool perMonitor: false
                property bool showNumbers: true
                property bool scrollToSwitch: true
                property string indicator: "pill"
            }

            property JsonObject theme: JsonObject {
                property string accent: "#CC0000"
                property real opacity: 1.0
                property real radiusScale: 1.0
                property real fontScale: 1.0
                property string fontSans: "JetBrainsMono Nerd Font Propo"
                property string fontMono: "JetBrainsMono Nerd Font Mono"
                property string fontIcon: "Material Symbols Rounded"
                property string fontAccent: "Symbols Nerd Font"
                property bool blur: false
                property bool accentFromWallpaper: false
                property var tokens: ({})
            }

            property JsonObject popups: JsonObject {
                property int gap: 8
                property int radius: 16
                property bool grabFocus: true
                property bool followFocusedMonitor: true
                property bool animate: true
            }

            property JsonObject animation: JsonObject {
                property bool enabled: true
                property real scale: 1.0
                property int fast: 160
                property int base: 260
                property int slow: 380
                property int exit: 160
            }

            property JsonObject launcher: JsonObject {
                property int maxResults: 30
                property bool useUwsm: true
                property string terminal: "ghostty"
                property bool showIcons: true
                property int iconSize: 40
                property bool frecency: true
                property var prefixes: ({
                        run: ">", calc: "=", window: "?", file: "/", action: ":"
                    })
            }

            property JsonObject notifications: JsonObject {
                property bool enabled: true
                property string position: "top-right"
                property int width: 400
                property int maxVisible: 5
                property int spacing: 8
                property string monitor: ""
                property bool followFocus: true
                property int timeoutLow: 4000
                property int timeoutNormal: 6000
                property int timeoutCritical: 0
                property int historyLimit: 100
                property bool persistHistory: true
                property var dnd: ({ allowCritical: true, autoFullscreen: true })
            }

            property JsonObject osd: JsonObject {
                property bool enabled: true
                property string position: "bottom"
                property int marginBottom: 120
                property int timeout: 1800
                property int width: 320
                property real volumeStep: 0.05
                property real volumeStepFine: 0.01
                property real maxVolume: 1.5
                property bool showOnTrackChange: true
                property string brightnessBackend: "none"
            }

            property JsonObject control: JsonObject {
                property int width: 420
                property string defaultSection: "audio"
                property bool showQuickRow: true
                property var ignoreInterfaces: ["lo", "docker*", "br-*", "veth*", "virbr*"]
                property string audioTool: "wiremix"
                property string bluetoothTool: "bluetui"
                property string networkTool: "nmtui"
            }

            property JsonObject dashboard: JsonObject {
                property int intervalIdle: 3000
                property int intervalActive: 1000
                property int intervalDisk: 30000
                property int historyLength: 120
                property bool showGpu: true
                property bool showPerCore: true
                property bool showDisk: true
                property var diskMounts: ["/", "/home"]
                property string netInterface: ""
                property var tempWarn: ({ cpu: 85, gpuEdge: 90, gpuJunction: 100, gpuMem: 95 })
            }

            property JsonObject updates: JsonObject {
                property bool enabled: true
                property int intervalRepo: 1800000
                property int intervalAur: 10800000
                property string aurHelper: "yay"
                property bool requireConnectivity: true
                property bool watchPacmanDb: true
                property bool hideWhenZero: true
                property var rebootPackages: ["linux", "linux-*", "mesa", "systemd", "nvidia*"]
                property var terminalCommand: ["ghostty", "--class=update.float", "--title=Updates"]
            }

            property JsonObject clipboard: JsonObject {
                property bool enabled: true
                property int maxEntries: 200
                property bool showImages: true
                property bool autoPaste: false
            }

            property JsonObject screenshot: JsonObject {
                property string directory: "~/Pictures/Screenshots"
                property string filename: "Screenshot_%Y-%m-%d_%H-%M-%S.png"
                property bool copyToClipboard: true
                property bool showToast: true
                property int toastTimeout: 6000
                property string annotateTool: "satty"
                property var slurpArgs: ["-d", "-b", "00000080", "-c", "CC0000ff",
                                         "-s", "CC000020", "-w", "2"]
            }

            property JsonObject colorPicker: JsonObject {
                property string defaultFormat: "hex"
                property int historyLimit: 50
                property bool freezeAll: true
            }

            property JsonObject wallpaper: JsonObject {
                property var directories: ["~/Wallpapers"]
                property string mode: "shared"
                property string shared: ""
                property var perMonitor: ({})
                property int fadeMs: 700
                property string fillMode: "crop"
                property var thumbnailSize: [480, 270]
                property bool recursive: true
            }

            property JsonObject power: JsonObject {
                property bool gracefulShutdown: true
                property int gracePeriod: 5000
                property bool confirmDestructive: true
                // "auto" | true | false -- string or bool, so it stays `var`
                property var hibernate: "auto"
                property var logoutCommand: ["uwsm", "stop"]
            }

            property JsonObject lock: JsonObject {
                property string pamConfig: "hyprlock"
                property string background: ""
                property real backgroundDim: 0.55
                property bool blur: true
                property bool showMedia: true
                property string clockFormat: "hh:mm"
                property string dateFormat: "dddd, MMMM d"
                property int secureTimeout: 3000
                property int maxTriesCooldown: 30000
            }

            property JsonObject hyprland: JsonObject {
                property bool emitBinds: true
                property bool emitColors: true
                property string activeBorder: ""
                property string inactiveBorder: "#2A1E20"
                property string activeBorderAlpha: "ee"
                property string inactiveBorderAlpha: "ff"
                property bool emitGaps: true
                property int gapsOut: 12
                property int gapsIn: 5
                property bool emitLayerRules: true
                property string shortcutAppId: "nett"
            }

            property JsonObject debug: JsonObject {
                property bool showConfigErrors: true
                property bool logIpc: false
                property bool showFps: false
            }

            // See the readonly alias above -- injected by compile.lua, not part
            // of the user-facing schema in defaults.lua.
            property var keybinds: []
        }
    }

    // -----------------------------------------------------------------------
    // Helpers used across the shell
    // -----------------------------------------------------------------------

    /// Should this monitor get a bar? An empty list means all of them.
    function barOnMonitor(name) {
        const list = root.bar.monitors;
        if (!list || list.length === 0)
            return true;
        return list.indexOf(name) !== -1;
    }

    /// Match a name against a glob list such as control.ignoreInterfaces.
    /// Supports a trailing/embedded `*` only, which is all these patterns need.
    function matchesAny(name, patterns) {
        if (!patterns)
            return false;
        for (const p of patterns) {
            if (p === name)
                return true;
            if (p.indexOf("*") !== -1) {
                const rx = new RegExp("^" + p.replace(/[.+?^${}()|[\]\\]/g, "\\$&")
                                             .replace(/\*/g, ".*") + "$");
                if (rx.test(name))
                    return true;
            }
        }
        return false;
    }
}
