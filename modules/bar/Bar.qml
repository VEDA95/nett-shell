// The top bar: three content groups (left/center/right) laid over a
// BarShape background whose pill widths follow each group's actual content
// size -- see BarShape.qml for why the joints look the way they do.
//
// This is a Wave 1 pass: workspaces (real, Hyprland-backed) and a window
// title + clock for visual completeness. Tray, audio, network, and the rest
// of the waybar-equivalent module list land in Wave 2 once their backing
// services exist.
//
// The calendar lives in its own PopupWindow (framework/ShellPopup.qml), not
// merged into this window -- matching Brain Shell's own architecture, which
// keeps a dedicated PopupLayer.qml for exactly this rather than growing the
// bar's own window. That distinction is not cosmetic: this window's real
// implicit size must stay CONSTANT. A `Behavior` on `implicitHeight` here
// was tried and reverted -- it animates the actual Wayland surface size
// every frame, which is a real resize/renegotiation with the compositor on
// every tick of the animation, and it was visibly janky. The popup's own
// window has the same constraint and solves it the same way (see
// PopupSurface.qml): implicit size fixed at the popup's maximum footprint
// always; only a plain Item inside it grows.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.theme
import qs.components
import qs.framework
import qs.ipc

PanelWindow {
    id: root
    // PanelWindow already has a native `screen` property (inherited from
    // WindowInterface) -- redeclaring it as `required property var screen`
    // shadows that real property instead of setting it, so the window's
    // actual output assignment silently never happens (every instance falls
    // back to whatever PanelWindow's own default is, which is why both
    // monitors' Bar instances landed on the same output). `required screen`
    // marks the EXISTING inherited property required without redeclaring it.
    required screen

    WlrLayershell.namespace: "nett-bar"
    WlrLayershell.layer: WlrLayer.Top
    anchors { top: true; left: true; right: true }
    // Sits right where the frame's top strip ends -- see RoundedFrame.qml.
    margins.top: Sizing.frameInset
    implicitHeight: Sizing.barHeight
    exclusiveZone: Sizing.frameInset + Sizing.barHeight
    color: "transparent"

    // Only the pills are clickable; the transparent gaps between them (and
    // the strip above) fall through to whatever's beneath. `regions` is
    // Region's default property, so these three compose (Combine, the
    // default intersection mode) without needing an explicit list.
    mask: Region {
        Region { item: leftGroup }
        Region { item: centerGroup }
        Region { item: rightGroup }
    }

    BarShape {
        anchors.fill: parent
        color: Theme.surfacePill
        radius: Sizing.barJointRadius
        leftWidth: leftGroup.width
        centerWidth: centerGroup.width
        rightWidth: rightGroup.width
    }

    // Left/right groups pad their OUTER edge (the one welded to a screen
    // corner) by `barEdgeClearance` on top of the normal `barPadding` --
    // that edge sits directly under the frame's enlarged corner tile (see
    // Sizing.barCornerRadius), which paints over anything closer to the
    // corner than its own arc has receded to at content height. The INNER
    // edge (the joint into the next pill/wallpaper) has no such overlap and
    // keeps plain `barPadding`. Skipping this asymmetry is exactly what was
    // clipping the launcher icon and the clock -- both sat inside the
    // frame's corner arc, not past it.
    Item {
        id: leftGroup
        height: parent.height
        x: 0
        width: leftContent.implicitWidth + Sizing.barPadding + Sizing.barEdgeClearance

        Row {
            id: leftContent
            anchors.left: parent.left
            anchors.leftMargin: Sizing.barEdgeClearance
            anchors.verticalCenter: parent.verticalCenter
            spacing: Sizing.barSpacing

            StyledIcon {
                name: "apps"
                iconSize: Sizing.iconMd
                tone: "accent"
                anchors.verticalCenter: parent.verticalCenter
            }
            Workspaces {
                screen: root.screen
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Item {
        id: centerGroup
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        width: centerContent.implicitWidth > 0 ? centerContent.implicitWidth + Sizing.barPadding * 2 : 0
        visible: width > 0

        Row {
            id: centerContent
            anchors.centerIn: parent
            StyledText {
                text: Hyprland.activeToplevel?.title ?? ""
                size: "sm"
                elide: Text.ElideRight
                maximumLineCount: 1
                width: Math.min(implicitWidth, 480)
            }
        }
    }

    // Widens in lockstep with the calendar popup growing beneath it, so the
    // two read as one continuous surface -- the "notch expands" look. Same
    // duration AND same easing curve as PopupSurface's growth (Easing.OutCubic,
    // Anim.base) on purpose: two independent Behaviors in two different files
    // stay visually locked together only as long as their timing parameters
    // are identical, not because anything here actually shares an animation
    // Deliberately NOT animated (tried, reverted): with the popup now
    // overlapping the notch from the top instead of sitting flush below it
    // (see ShellPopup.qml's `edges: Edges.Top`), the popup's own growth is
    // already the sole visual surface once it's open -- it's drawn above
    // this pill and simply covers it, so rightGroup widening in lockstep is
    // no longer load-bearing for the illusion, only a second clock trying
    // (and, per live testing, failing) to stay pixel-synced with the first
    // across two independently-scheduled window repaints. One clock, one
    // surface actually doing the growing.
    readonly property real _rightRestWidth: rightContent.implicitWidth + Sizing.barPadding + Sizing.barEdgeClearance

    Item {
        id: rightGroup
        height: parent.height
        x: parent.width - width
        width: root._rightRestWidth

        // The one persistent click target for toggling -- separate from
        // rightContent below, since that Row fades out (and stops accepting
        // clicks once `visible` goes false) exactly when a right-side popup
        // overlaps this same area, matching RightContent.qml's own opacity
        // fade on its icon row when a right-side popup opens. Falls through
        // to whichever icon's own MouseArea sits on top of it (AudioIndicator
        // below), since rightContent is declared AFTER this in the same
        // parent and stacks above it -- so this only fires for a click on
        // empty pill area (e.g. the clock), which opens the calendar.
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.calendarShown = !root.calendarShown;
                if (root.calendarShown)
                    root.audioShown = false;
            }
        }

        Row {
            id: rightContent
            anchors.right: parent.right
            anchors.rightMargin: Sizing.barEdgeClearance
            anchors.verticalCenter: parent.verticalCenter
            spacing: Sizing.barSpacing

            // Fades for EITHER popup -- both are anchored to rightGroup and
            // physically cover this same area once open, exactly like
            // Calendar alone used to.
            opacity: (root.calendarShown || root.audioShown) ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Anim.fast } }

            AudioIndicator {
                anchors.verticalCenter: parent.verticalCenter
                onToggleRequested: {
                    root.audioShown = !root.audioShown;
                    if (root.audioShown)
                        root.calendarShown = false;
                }
            }

            StyledText {
                id: clock
                size: "sm"
                mono: true
                anchors.verticalCenter: parent.verticalCenter

                property var _now: new Date()
                text: Qt.formatDateTime(_now, "hh:mm:ss  AP")

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clock._now = new Date()
                }
            }
        }
    }

    property bool calendarShown: false

    // Screen-qualified name ("calendar-DP-1", "calendar-DP-3") -- each
    // monitor's Bar instance owns its own calendar, and Ipc.popups is one
    // flat map shared by every screen; an unqualified "calendar" would have
    // the second monitor's registration silently clobber the first's.
    // Registering at all (rather than keeping this purely local, as it was
    // before) is what lets DismissOverlay.qml's click-anywhere-else/Escape
    // handling discover this popup through Ipc.anyOpen/Ipc.closeAll()
    // without hardcoding a name.
    readonly property string _calendarPopupName: "calendar-" + root.screen.name
    Component.onCompleted: {
        Ipc.registerPopup(root._calendarPopupName, {
            setShown: (v) => root.calendarShown = v,
            isShown: () => root.calendarShown,
        });
        Ipc.registerPopup(root._audioPopupName, {
            setShown: (v) => root.audioShown = v,
            isShown: () => root.audioShown,
        });
    }
    Component.onDestruction: {
        Ipc.unregisterPopup(root._calendarPopupName);
        Ipc.unregisterPopup(root._audioPopupName);
    }

    property bool audioShown: false
    readonly property string _audioPopupName: "audio-" + root.screen.name

    // TEMPORARY DEBUG -- reopened briefly for another round of pixel
    // verification, remove before this segment is done.
    Timer {
        interval: 700
        running: true
        onTriggered: root.audioShown = true
    }

    // Anchored to rightGroup itself, not the clock -- rightGroup's right
    // edge (x + width == parent.width, always, by construction, regardless
    // of its own width animation) is the SAME reference the pill uses for
    // its own right alignment.
    //
    // restWidth/restHeight match rightGroup's own resting size exactly --
    // the popup's very first visible frame is then pixel-identical to the
    // pill already on screen, and growth is only the delta beyond it. See
    // PopupSurface.qml's header for why starting from 0 instead visibly
    // desyncs the width animation from the calendar's own content.
    ShellPopup {
        anchorItem: rightGroup
        shown: root.calendarShown
        side: Edges.Right
        restWidth: root._rightRestWidth
        restHeight: Sizing.barHeight
        content: Component { Calendar {} }
        // The popup physically sits above rightGroup's own MouseArea once
        // open, so that toggle is unreachable until this fires -- see
        // ShellPopup.qml's `dismissRequested` for why the fix lives here
        // (mutating `calendarShown`, the actual source of truth) rather than
        // inside the popup itself.
        onDismissRequested: root.calendarShown = false
    }

    // Same mechanism as Calendar's own popup above, just a second instance --
    // see AudioIndicator.qml's header for why this lives here rather than
    // inside AudioIndicator itself.
    ShellPopup {
        anchorItem: rightGroup
        shown: root.audioShown
        side: Edges.Right
        restWidth: root._rightRestWidth
        restHeight: Sizing.barHeight
        content: Component { AudioPopup {} }
        onDismissRequested: root.audioShown = false
        // TEMPORARY DEBUG
        onVisibleChanged: console.log(`AUDIOPOPUPDEBUG screen=${root.screen.name} visible=${visible} implicitWidth=${implicitWidth} implicitHeight=${implicitHeight}`)
    }
}
