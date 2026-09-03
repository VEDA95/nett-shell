pragma Singleton

// Path resolution shared by everything that touches the filesystem.
//
// The state directory is computed the same way compile.lua computes it --
// $XDG_STATE_HOME/nett-shell, falling back to ~/.local/state/nett-shell -- and
// that agreement is the whole point. Quickshell's own statePath() would be the
// natural choice, but compile.lua runs before `qs` exists (Hyprland reads the
// generated keybind file at login), so it cannot ask Quickshell for a shell id.
// An XDG path is the one location both sides can derive independently.

import Quickshell

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") ?? ""

    function _dir(envVar, fallback) {
        const v = Quickshell.env(envVar);
        return (v && v.length > 0) ? v : root.home + fallback;
    }

    readonly property string stateDir: _dir("XDG_STATE_HOME", "/.local/state") + "/nett-shell"
    readonly property string cacheDir: _dir("XDG_CACHE_HOME", "/.cache") + "/nett-shell"
    readonly property string configHome: _dir("XDG_CONFIG_HOME", "/.config")

    // Compiled artefacts, written by config/compile.lua.
    readonly property string configJson: stateDir + "/config.json"
    readonly property string configErr: stateDir + "/config.err"

    // Sources, inside the shell directory.
    readonly property string shellDir: Quickshell.shellDir
    readonly property string configLua: shellDir + "/config/config.lua"
    readonly property string keybindsLua: shellDir + "/config/keybinds.lua"
    readonly property string compileLua: shellDir + "/config/compile.lua"

    readonly property string hyprDir: configHome + "/hypr"
    readonly property string hyprGenerated: hyprDir + "/nett-shell.conf"

    // Per-feature state and caches.
    readonly property string frecencyJson: stateDir + "/frecency.json"
    readonly property string wallpaperJson: stateDir + "/wallpaper.json"
    readonly property string colorsJson: stateDir + "/colors.json"
    readonly property string notificationsJson: stateDir + "/notifications.json"
    readonly property string hwPathsJson: cacheDir + "/hwpaths.json"
    readonly property string updatesJson: cacheDir + "/updates.json"
    readonly property string thumbsDir: cacheDir + "/thumbs"
    readonly property string clipCacheDir: cacheDir + "/clip"

    /// Expand a leading ~ so config values can use it freely.
    function expand(path) {
        if (!path)
            return "";
        if (path.startsWith("~/"))
            return root.home + path.slice(1);
        if (path === "~")
            return root.home;
        return path;
    }

    /// Turn a filesystem path into a file:// URL for Image.source and friends.
    function toUrl(path) {
        const p = root.expand(path);
        if (!p)
            return "";
        return p.startsWith("file://") ? p : "file://" + p;
    }
}
