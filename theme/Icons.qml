pragma Singleton

// Name -> glyph lookup, so no widget ever contains a raw icon literal.
//
// Material Symbols ships as an OpenType ligature font: setting a Text element's
// content to the icon's documented name (e.g. "close", "volume_up") and the
// font's own ligature table substitutes the glyph -- that is Google's intended
// usage, not a workaround. This is deliberately used here instead of hardcoded
// private-use-area codepoints: a codepoint typo is invisible until you eyeball
// every glyph against the real font, while a misspelled ligature name just fails
// to substitute and renders as literal fallback text, which is obvious at a
// glance. See components/StyledIcon.qml for the Text element that enables the
// ligature feature explicitly, so substitution does not depend on Qt's default
// font-feature set.
//
// The Nerd Font accent glyphs (Icons.accent) are different: Nerd Fonts assign a
// distinct private-use codepoint per glyph with no ligature fallback, and there
// is no tool in this environment to read the installed font's cmap and confirm
// a codepoint against it (fc-query exposes coverage ranges, not per-glyph
// names). Rather than ship guessed codepoints that would render as tofu if
// wrong, `_accent` starts empty; fill it in by picking the glyph from the
// Nerd Fonts cheat sheet (https://www.nerdfonts.com/cheat-sheet) or a local
// glyph picker, once one is needed. accent() returns "" until then, and
// StyledIcon treats "" as "fall back to the Material Symbols name instead".

import Quickshell

Singleton {
    id: root

    // ---- Material Symbols Rounded (theme.fontIcon), ligature names ----
    readonly property var _material: ({
            // navigation / structure
            "close": "close",
            "menu": "menu",
            "chevron-right": "chevron_right",
            "chevron-left": "chevron_left",
            "chevron-up": "keyboard_arrow_up",
            "chevron-down": "keyboard_arrow_down",
            "more": "more_horiz",
            "drag-handle": "drag_handle",

            // bar / system
            "workspace": "workspaces",
            "window": "web_asset",
            "search": "search",
            "settings": "settings",
            "apps": "apps",
            "terminal": "terminal",
            "folder": "folder",

            // audio
            "volume-high": "volume_up",
            "volume-medium": "volume_down",
            "volume-low": "volume_mute",
            "volume-mute": "volume_off",
            "mic": "mic",
            "mic-off": "mic_off",
            "speaker": "speaker",
            "mic-external": "mic_external_on",

            // network / bluetooth / power
            "wifi": "wifi",
            "wifi-off": "wifi_off",
            "ethernet": "settings_ethernet",
            "bluetooth": "bluetooth",
            "bluetooth-off": "bluetooth_disabled",
            "battery": "battery_full",
            "power": "power_settings_new",
            "power-profile": "tune",

            // notifications
            "bell": "notifications",
            "bell-off": "notifications_off",
            "bell-ring": "notifications_active",
            "dnd": "do_not_disturb_on",
            "check-circle": "check_circle",
            "error": "error",
            "warning": "warning",
            "info": "info",

            // media
            "play": "play_arrow",
            "pause": "pause",
            "skip-next": "skip_next",
            "skip-prev": "skip_previous",

            // launcher / actions
            "delete": "delete",
            "copy": "content_copy",
            "edit": "edit",
            "reveal": "folder_open",
            "open": "open_in_new",
            "refresh": "refresh",
            "calculator": "calculate",
            "image": "image",
            "palette": "palette",
            "screenshot": "screenshot_monitor",

            // power menu
            "lock": "lock",
            "logout": "logout",
            "suspend": "bedtime",
            "reboot": "restart_alt",
            "shutdown": "power_settings_new",
            "hibernate": "ac_unit",

            // dashboard
            "cpu": "memory",
            "memory": "developer_board",
            "gpu": "developer_board",
            "disk": "storage",
            "thermometer": "thermostat",
            "speed": "speed",

            // misc
            "arrow-up": "arrow_upward",
            "arrow-down": "arrow_downward",
            "expand": "expand_more",
            "collapse": "expand_less",
            "pin": "push_pin",
            "unknown": "help",
        })

    // ---- Symbols Nerd Font (theme.fontAccent) -- see the header note ----
    readonly property var _accent: ({
            // "arch": "\uXXXX",             -- TODO: verify against the cheat sheet
            // "separator-round-r": "\uXXXX",
            // "separator-round-l": "\uXXXX",
        })

    /// Look up a Material Symbols ligature name. Falls back to "unknown" rather
    /// than an empty string, so a typo'd name is visibly wrong (renders as the
    /// literal fallback glyph "help") instead of silently invisible.
    function get(name) {
        return root._material[name] ?? root._material["unknown"];
    }

    /// Look up an accent-font (Nerd Font) codepoint by name. Returns "" until
    /// the entry above is filled in and verified -- callers should treat an
    /// empty result as "use the Material Symbols equivalent instead".
    function accent(name) {
        return root._accent[name] ?? "";
    }

    /// Does a Material Symbols entry exist for this name?
    function has(name) {
        return Object.prototype.hasOwnProperty.call(root._material, name);
    }
}
