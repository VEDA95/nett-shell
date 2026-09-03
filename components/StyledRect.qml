// A themed surface: background chosen by elevation name rather than a raw
// hex value (Theme.surface()), with an optional themed border. This is the
// base almost every card/pill/row in the shell sits on.

import QtQuick
import qs.theme

Rectangle {
    id: root

    /// void | bg | surfacePill | surfaceRaised | elev2 (default) | elev3 | elev4
    property string surface: "elev2"

    property bool bordered: false

    /// border (default) | strong | accent -- see Theme.borderTone().
    property string borderTone: "border"

    color: Theme.surface(root.surface)
    radius: Sizing.radiusMd
    border.width: root.bordered ? Sizing.borderHair : 0
    border.color: Theme.borderTone(root.borderTone)
}
