pragma Singleton

// Geometry tokens.
//
// GEOMETRY RULE: Hyprland runs these displays at scale 1.25, so only logical
// values that are multiples of 4 reliably land on whole physical pixels
// (4 x 1.25 = 5). Every value below is chosen from {4, 8, 12, 16, 20, 24, 28,
// 32}. compile.lua warns if a Lua override breaks this; nothing here enforces
// it a second time, since these are the shell's own defaults and are already
// compliant.
//
// Note: Quickshell's ShellScreen.devicePixelRatio has been observed reporting
// 2 rather than 1.25 here -- see the longer note in config/defaults.lua. It is
// a Qt/Wayland platform quirk, not something this file should try to correct;
// the multiples-of-4 choice is safe under both the compositor's real 1.25 and
// Qt's reported 2.
//
// Sizing reuses the numbers already in ~/.config/hypr/looknfeel.conf
// (gaps_in 5, gaps_out 12, rounding 10) so the frame lines up with window gaps
// instead of fighting them -- gapsOut/gapsIn below are exactly what compile.lua
// emits back into nett-shell.conf, so there is one source of truth in both
// directions.

import Quickshell
import qs.config

Singleton {
    id: root

    readonly property real s: Config.theme.radiusScale > 0 ? Config.theme.radiusScale : 1.0

    // ---- spacing ----
    readonly property int spacingNone: 0
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 12
    readonly property int spacingLg: 16
    readonly property int spacingXl: 24
    readonly property int spacingXxl: 32

    // ---- radius ----
    readonly property int radiusSm: Math.round(8 * s)
    readonly property int radiusMd: Math.round(12 * s)
    readonly property int radiusLg: Math.round(16 * s)
    readonly property int radiusXl: Math.round(20 * s)
    readonly property int radiusPill: 9999

    // ---- frame + bar, mirroring config/defaults.lua ----
    readonly property int frameInset: Config.frame.inset
    readonly property int frameRadius: Config.frame.radius
    readonly property int barHeight: Config.bar.height
    readonly property int barPillRadius: Config.bar.pillRadius
    readonly property int barGap: Config.bar.gap
    readonly property int barPadding: Config.bar.padding
    readonly property int barSpacing: Config.bar.spacing
    readonly property int barJointRadius: Config.bar.jointRadius
    readonly property int barExclusiveZone: frameInset + barHeight

    // The frame's top corner tiles are enlarged to this radius so they fully
    // cover the bar's height and do the bar's outer-corner rounding for it
    // (BarShape's own outer corners are square -- see modules/bar/BarShape.qml
    // and modules/frame/FrameOverlay.qml). Single source so the bar's own edge
    // padding below can stay in exact agreement with what the frame will draw.
    readonly property int barCornerRadius: Math.max(frameRadius, barHeight)

    // How far the leftmost/rightmost pill's content must clear the pill's own
    // OUTER edge (the one welded to a screen corner) before the enlarged frame
    // corner tile above stops painting over it. Derived from where that
    // corner's arc actually sits at the height real content occupies, not a
    // guessed constant -- see the geometry note in modules/bar/Bar.qml.
    readonly property int barEdgeClearance: {
        const r = barCornerRadius;
        const ry = Math.max(0, (barHeight - iconMd) / 2);
        const safe = r - Math.sqrt(Math.max(0, r * r - (r - ry) * (r - ry)));
        return Math.ceil((safe + 4) / 4) * 4;
    }

    // ---- borders ----
    readonly property int borderHair: 1
    readonly property int borderThin: 2

    // ---- from looknfeel.conf, re-emitted by compile.lua so it stays one number ----
    readonly property int gapsOut: Config.hyprland.gapsOut
    readonly property int gapsIn: Config.hyprland.gapsIn

    // ---- icon sizes ----
    readonly property int iconSm: 16
    readonly property int iconMd: 20
    readonly property int iconLg: 24
    readonly property int iconXl: 32
}
