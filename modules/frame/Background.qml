// The wallpaper layer: WlrLayer.Background, plain fill, no rounding.
//
// Rounding used to live here (the very first version of this file wrapped the
// image in a ClippingRectangle with its own radius), which only ever rounded
// the wallpaper -- windows drawn on top stayed square, and the two edges
// didn't even line up exactly (worked out to the window's rounded corner
// sitting ~0.6px inside the wallpaper's own arc, given this machine's real
// gaps/rounding values). The rounding now happens once, in FrameOverlay,
// which sits above windows and optically crops everything at once.
//
// `sourceSize` is scaled by devicePixelRatio deliberately, not hardcoded to
// 1.25: read dynamically like this, it stays correct regardless of what Qt
// actually reports for this property (a known platform quirk on this system
// reports 2 rather than the compositor's real 1.25 -- see shell.qml's note).
// Without it, Qt decodes the image at native resolution and holds the full
// decode in memory for as long as the Image lives.

import QtQuick
import qs.config

Item {
    id: root
    required property var screen

    readonly property string _source: Config.wallpaper.mode === "per-monitor"
        ? (Config.wallpaper.perMonitor[root.screen.name] ?? Config.wallpaper.shared)
        : Config.wallpaper.shared

    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        source: root._source ? Paths.toUrl(root._source) : ""
        sourceSize.width: root.screen.width * root.screen.devicePixelRatio
        sourceSize.height: root.screen.height * root.screen.devicePixelRatio
    }
}
