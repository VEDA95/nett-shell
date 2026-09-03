// The rounded border, drawn above every window.
//
// An empty Region as `mask` makes the entire window click-through -- nothing
// here should ever intercept a click, since it's purely decorative chrome
// sitting on top of real windows.

import QtQuick
import qs.config
import qs.theme
import qs.framework

Item {
    id: root
    required property var screen

    // The bar leaves its own outer corners square on purpose (see
    // BarShape.qml) and relies entirely on the frame's top corner tiles to
    // round them -- so when a bar is present on this screen, those tiles
    // must be enlarged to fully cover the bar's height, or a flat unrounded
    // sliver shows between the bar's square corner and the tile's normal
    // (smaller) curve. See RoundedFrame.qml.
    readonly property bool _barHere: Config.barOnMonitor(root.screen.name)

    RoundedFrame {
        anchors.fill: parent
        topRadius: root._barHere ? Sizing.barCornerRadius : Sizing.frameRadius
    }
}
