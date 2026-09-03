// A Material Symbols glyph, looked up by name through theme/Icons.qml.
//
// Material Symbols is an OpenType ligature font: the rendered `text` is the
// glyph's documented name (e.g. "close"), and the font's own ligature table
// substitutes the icon shape -- see Icons.qml for why that is used instead of
// hardcoded private-use-area codepoints. `font.features` requests the liga/
// dlig features explicitly rather than relying on Qt's default feature set
// (confirmed present on Text.font in this Qt version).
//
// `fill` drives Material Symbols' variable FILL axis (0 = outline, 1 = solid)
// via `font.variableAxes` (also confirmed present on Text.font here) -- an
// icon can animate from outline to solid on hover/active, which a fixed-glyph
// icon font cannot do. The Behavior below makes that automatic: a caller only
// needs to set `fill: hovered ? 1 : 0`.
//
// If `name` has an entry in Icons.accent() (the Nerd Font accent glyphs), that
// takes priority and switches the font family accordingly -- so a caller never
// needs to know which font a given icon actually lives in.

import QtQuick
import qs.theme

Text {
    id: root

    property string name: "unknown"
    property int iconSize: Sizing.iconMd

    /// hi | body (default) | dim | muted | faint | accent | error | warn |
    /// success | onAccent -- see Theme.tone().
    property string tone: "body"

    /// 0 = outline, 1 = solid. Animated automatically; just set the target.
    property real fill: 0

    readonly property string _accentGlyph: Icons.accent(root.name)

    text: root._accentGlyph.length > 0 ? root._accentGlyph : Icons.get(root.name)
    font.family: root._accentGlyph.length > 0 ? Fonts.accentFont : Fonts.icon
    font.pixelSize: root.iconSize
    font.features: ({ "liga": 1, "dlig": 1 })
    font.variableAxes: ({ "FILL": root.fill })
    color: Theme.tone(root.tone)

    Behavior on fill {
        NumberAnimation { duration: Anim.fast }
    }
}
