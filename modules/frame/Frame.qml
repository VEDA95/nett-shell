// Per-screen wallpaper + rounded border: two windows, not one.
//
// Background and FrameOverlay are deliberately separate PanelWindows on
// different layers (Background vs Overlay) rather than one window containing
// both -- the whole point of the split is that FrameOverlay sits above every
// application window while Background sits below all of them, and a single
// window can only occupy one layer.

import Quickshell
import Quickshell.Wayland
import qs.theme

Scope {
    id: root
    required property var screen

    PanelWindow {
        screen: root.screen
        WlrLayershell.namespace: "nett-background"
        WlrLayershell.layer: WlrLayer.Background
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: Theme.void_

        Background { anchors.fill: parent; screen: root.screen }
    }

    PanelWindow {
        screen: root.screen
        WlrLayershell.namespace: "nett-frame"
        WlrLayershell.layer: WlrLayer.Overlay
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        mask: Region {}

        FrameOverlay { anchors.fill: parent; screen: root.screen }
    }
}
