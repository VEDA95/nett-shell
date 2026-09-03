// Transparent fullscreen overlay that dismisses every open popup when the
// user clicks anywhere else on screen, presses Escape, or switches
// workspace/monitor -- ported from Brain Shell's own
// `src/windows/PopupDismiss.qml` (github.com/Brainitech/Brain_Shell) rather
// than re-derived, after HyprlandFocusGrab (the "correct-looking" native
// option) turned out to be the wrong tool: focus-grab's built-in dismissal
// hides a popup by writing `visible` imperatively from C++, and any
// imperative write to a property PERMANENTLY breaks a prior QML binding on
// it -- see the long-standing note in ShellPopup.qml. This sidesteps that
// entirely: nothing here ever touches a popup's own `shown`/`visible`. It
// only asks, through Ipc.closeAll(), and every registered popup's own
// controller (its `setShown`) is what actually flips its own bool.
//
// Differences from the reference, both deliberate simplifications for this
// shell's flatter layout (their version excludes three separately-shaped
// notch regions matching their own bar's per-pill geometry, and reacts to a
// raw Hyprland IPC event feed this Quickshell version doesn't expose):
//   - `mask` excludes the whole bar strip (frameInset + barHeight) rather
//     than per-pill shapes. A click that lands on a pill still reaches the
//     bar underneath either way (this overlay isn't there to intercept it);
//     the only behavioral difference is a click in the bar's own transparent
//     GAPS passes through instead of dismissing -- a minor edge case next to
//     replicating per-instance, per-monitor pill geometry here.
//   - Dismissing on navigation uses `Hyprland.focusedWorkspaceChanged` /
//     `focusedMonitorChanged` (real signals on the upstream `Hyprland`
//     singleton) instead of a raw event stream, which isn't part of this
//     Quickshell version's Hyprland module.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.ipc

PanelWindow {
    id: root
    // PanelWindow already has a native `screen` property (inherited from
    // WindowInterface) -- redeclaring it as `required property var screen`
    // shadows that real property instead of setting it, the same bug fixed
    // in Bar.qml. `required screen` marks the EXISTING inherited property
    // required without redeclaring it.
    required screen

    WlrLayershell.namespace: "nett-dismiss"
    WlrLayershell.layer: WlrLayer.Top
    // On-demand, not exclusive: this only needs Escape to reach it while a
    // popup is open, never at the expense of some other surface owning
    // keyboard focus normally the rest of the time.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }

    // Input passes through entirely when false -- as if this window doesn't
    // exist -- so it costs nothing while no popup is open.
    visible: Ipc.anyOpen

    mask: Region {
        Region {
            x: 0
            y: Sizing.frameInset + Sizing.barHeight
            width: root.width
            height: root.height - (Sizing.frameInset + Sizing.barHeight)
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Ipc.closeAll()
    }

    // Keys only fire on a focused Item, and this Item's own `focus` must
    // track the window's visibility -- an Item can hold `focus: true` while
    // its window is hidden, which would leave a HIDDEN window "focused" and
    // able to silently eat the next Escape press meant for something else
    // the moment it becomes visible again out of sync with reality.
    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: Ipc.closeAll()
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { Ipc.closeAll(); }
        function onFocusedMonitorChanged() { Ipc.closeAll(); }
    }
}
