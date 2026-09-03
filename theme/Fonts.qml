pragma Singleton

// Typography tokens.
//
// Material Symbols Rounded is the default icon font: its variable FILL axis
// (0 = outline, 1 = solid) lets a glyph animate its fill on hover/active state,
// which is a real affordance Nerd Font glyphs cannot give. JetBrainsMono Nerd
// Font stays for text, numerals, and the handful of accent glyphs it does better
// (the Arch logo, powerline separators) -- see theme/Icons.qml, which routes
// every glyph through one lookup so this choice is never hardcoded in a widget.

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    readonly property real scale: Config.theme.fontScale > 0 ? Config.theme.fontScale : 1.0

    readonly property string sans: Config.theme.fontSans
    readonly property string mono: Config.theme.fontMono
    readonly property string icon: Config.theme.fontIcon
    readonly property string accentFont: Config.theme.fontAccent

    function px(base) {
        return Math.round(base * root.scale);
    }

    // ---- size ramp, logical px ----
    readonly property int xxs: px(10)
    readonly property int xs: px(11)
    readonly property int sm: px(12)
    readonly property int md: px(13)
    readonly property int lg: px(14)
    readonly property int xl: px(16)
    readonly property int xxl: px(18)
    readonly property int h3: px(22)
    readonly property int h2: px(28)
    readonly property int h1: px(36)

    // ---- weights ----
    readonly property int weightNormal: Font.Normal
    readonly property int weightMedium: Font.Medium
    readonly property int weightBold: Font.Bold
}
