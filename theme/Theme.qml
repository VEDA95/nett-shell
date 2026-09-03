pragma Singleton

// The black / blood-red palette.
//
// Hardcoded defaults with Lua overrides, not fully Lua-driven: the shell must
// still render correctly when config.lua fails to compile, and a 60+ entry
// colour table in a Lua file is unreviewable. Config.theme.tokens patches any
// single named token; Config.theme.accent re-derives the whole accent ramp so
// one hex re-tones the shell.
//
// THE RULE THAT MAKES A RED ACCENT COEXIST WITH RED ERRORS, enforced here rather
// than left to per-widget discipline: the accent is reserved for identity and
// selection. `error` is never `accent500` -- it is deliberately lighter and
// pinker, and error states pair it with an icon and `errorBg`. With a red accent,
// colour alone is not a readable signal.

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    // ---- knobs that re-derive everything below ----
    readonly property color accentBase: _validColor(Config.theme.accent, "#CC0000")
    readonly property real surfaceOpacity: Config.theme.opacity > 0 ? Config.theme.opacity : 1.0
    readonly property real radiusScale: Config.theme.radiusScale > 0 ? Config.theme.radiusScale : 1.0
    readonly property real fontScale: Config.theme.fontScale > 0 ? Config.theme.fontScale : 1.0
    readonly property bool blur: !!Config.theme.blur

    function _validColor(hex, fallback) {
        if (!hex)
            return fallback;
        const c = Qt.color(hex);
        return c.a > 0 || hex === "transparent" ? hex : fallback;
    }

    /// Look up an override in Config.theme.tokens by name, else fall through.
    function _tok(name, fallback) {
        const t = Config.theme.tokens;
        if (t && Object.prototype.hasOwnProperty.call(t, name))
            return _validColor(t[name], fallback);
        return fallback;
    }

    // -------------------------------------------------------------------
    // Neutrals -- pulled a few degrees toward red at very low saturation,
    // so they read as one family with the accent rather than red-on-grey.
    // -------------------------------------------------------------------
    readonly property color void_: _tok("void", "#000000")
    readonly property color bg: _tok("bg", "#0A0708")
    readonly property color surfacePill: _tok("surfacePill", "#0A0A0A")
    readonly property color surfaceRaised: _tok("surfaceRaised", "#0F0F0F")
    readonly property color elev2: _tok("elev2", "#141414")
    readonly property color elev3: _tok("elev3", "#221819")
    readonly property color elev4: _tok("elev4", "#2B1E20")

    readonly property color hover: _tok("hover", "#14FFFFFF")   // white @ ~8%
    readonly property color press: _tok("press", "#1FFFFFFF")   // white @ ~12%

    readonly property color border: _tok("border", "#2A1E20")
    readonly property color borderStrong: _tok("borderStrong", "#3D2A2C")
    readonly property color borderAccent: _tok("borderAccent", "#8C1218")

    readonly property color textHi: _tok("textHi", "#F2EDEE")
    readonly property color text: _tok("text", "#E2E2E2")
    readonly property color textDim: _tok("textDim", "#919191")
    readonly property color textMuted: _tok("textMuted", "#919191")
    readonly property color textFaint: _tok("textFaint", "#474747")
    readonly property color textOnAccent: _tok("textOnAccent", "#FFF3F3")

    // -------------------------------------------------------------------
    // Accent ramp, derived from accentBase unless individually overridden.
    // Lighter stops lighten toward white, darker stops darken toward black --
    // Qt.tint keeps the hue instead of just scaling lightness, which is what
    // keeps the ramp reading as "the same red" at every stop.
    // -------------------------------------------------------------------
    readonly property color accent50: _tok("accent50", Qt.tint(accentBase, "#E6FFFFFF"))
    readonly property color accent100: _tok("accent100", Qt.tint(accentBase, "#CCFFFFFF"))
    readonly property color accent200: _tok("accent200", Qt.tint(accentBase, "#80FFFFFF"))
    readonly property color accent300: _tok("accent300", Qt.tint(accentBase, "#40FFFFFF"))
    readonly property color accent400: _tok("accent400", Qt.lighter(accentBase, 1.12))
    readonly property color accent500: _tok("accent500", accentBase)
    readonly property color accent600: _tok("accent600", Qt.darker(accentBase, 1.20))
    readonly property color accent700: _tok("accent700", Qt.darker(accentBase, 1.45))
    readonly property color accent800: _tok("accent800", Qt.darker(accentBase, 1.90))
    readonly property color accent900: _tok("accent900", Qt.darker(accentBase, 2.60))
    readonly property color accentGlow: _tok("accentGlow", Qt.lighter(accentBase, 1.30))

    readonly property color accent: accent500

    // -------------------------------------------------------------------
    // Semantics -- chosen to stay legible next to a red accent. `warn` is
    // pushed yellow rather than orange, or it collides with accent300; `error`
    // is deliberately lighter and pinker than accent500 rather than reusing it.
    // -------------------------------------------------------------------
    readonly property color success: _tok("success", "#3FB950")
    readonly property color warn: _tok("warn", "#E3A008")
    readonly property color error: _tok("error", "#FF5C5C")
    readonly property color errorBg: _tok("errorBg", "#2A0C0C")
    readonly property color info: _tok("info", "#4A9EFF")

    // -------------------------------------------------------------------
    // Frame colour: what the rounded screen border and corner wedges paint.
    // -------------------------------------------------------------------
    readonly property color frame: Config.frame.color && Config.frame.color.length > 0
        ? _validColor(Config.frame.color, void_) : void_

    // -------------------------------------------------------------------
    // Named lookups shared by components/ -- one place mapping a short,
    // stable name to a token, so StyledText/StyledIcon/StyledRect don't each
    // carry their own copy of the same switch statement.
    // -------------------------------------------------------------------

    /// Foreground colour by name: hi | body (default) | dim | muted | faint |
    /// accent | error | warn | success | onAccent.
    function tone(name) {
        switch (name) {
        case "hi": return root.textHi;
        case "dim": return root.textDim;
        case "muted": return root.textMuted;
        case "faint": return root.textFaint;
        case "accent": return root.accent;
        case "error": return root.error;
        case "warn": return root.warn;
        case "success": return root.success;
        case "onAccent": return root.textOnAccent;
        default: return root.text;
        }
    }

    /// Background/surface colour by name: void | bg | surfacePill |
    /// surfaceRaised | elev2 (default) | elev3 | elev4.
    function surface(name) {
        switch (name) {
        case "void": return root.void_;
        case "bg": return root.bg;
        case "surfacePill": return root.surfacePill;
        case "surfaceRaised": return root.surfaceRaised;
        case "elev3": return root.elev3;
        case "elev4": return root.elev4;
        default: return root.elev2;
        }
    }

    /// Border colour by name: border (default) | strong | accent.
    function borderTone(name) {
        switch (name) {
        case "strong": return root.borderStrong;
        case "accent": return root.borderAccent;
        default: return root.border;
        }
    }

    /// Most-saturated candidate from a ColorQuantizer result that still
    /// contrasts against bg, for the optional wallpaper-derived accent.
    /// The flag defaults off (Config.theme.accentFromWallpaper); this is the
    /// seam left open for Wave 5, not something called by default.
    function pickAccent(colors) {
        if (!colors || colors.length === 0)
            return accent500;
        let best = null, bestScore = -1;
        for (const c of colors) {
            const sat = c.hslSaturation;
            const lum = c.hslLightness;
            if (lum < 0.18 || lum > 0.72)
                continue;
            const score = sat * 2 + (1 - Math.abs(lum - 0.42));
            if (score > bestScore) {
                bestScore = score;
                best = c;
            }
        }
        return best ?? accent500;
    }

    // Wired up once services/Wall.qml exists (Wave 1): it will set this from a
    // ColorQuantizer over the current wallpaper. Until then this is always
    // accent500, so accentFromWallpaper is a documented no-op rather than a
    // hard dependency on an unbuilt service.
    property var wallpaperColors: []
    readonly property color effectiveAccent: Config.theme.accentFromWallpaper
        ? pickAccent(wallpaperColors) : accent500
}
