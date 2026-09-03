// Theme-aware Text: colour and size are chosen by name (`tone`, `size`) rather
// than a raw hex/pixel value, so a palette or type-scale change updates every
// call site at once instead of needing a find-and-replace.
//
// Anything Text already does natively (font.bold, elide, wrapMode, ...) is left
// alone -- this only standardises colour and size, the two properties that
// would otherwise get a hardcoded value hand-copied into every widget.

import QtQuick
import qs.theme

Text {
    id: root

    /// hi | body (default) | dim | muted | faint | accent | error | warn |
    /// success | onAccent -- see Theme.tone().
    property string tone: "body"

    /// xxs | xs | sm | md (default) | lg | xl | xxl | h3 | h2 | h1 -- Fonts'
    /// size ramp, looked up by name for the same reason as `tone`.
    property string size: "md"

    /// Use the monospace family (Fonts.mono) instead of Fonts.sans.
    property bool mono: false

    function _sizePx(name) {
        switch (name) {
        case "xxs": return Fonts.xxs;
        case "xs": return Fonts.xs;
        case "sm": return Fonts.sm;
        case "lg": return Fonts.lg;
        case "xl": return Fonts.xl;
        case "xxl": return Fonts.xxl;
        case "h3": return Fonts.h3;
        case "h2": return Fonts.h2;
        case "h1": return Fonts.h1;
        default: return Fonts.md;
        }
    }

    color: Theme.tone(root.tone)
    font.family: root.mono ? Fonts.mono : Fonts.sans
    font.pixelSize: root._sizePx(root.size)
}
