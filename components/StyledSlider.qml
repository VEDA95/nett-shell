// A horizontal slider: drag or scroll to change `value` within [from, to].
// Controlled, not stateful -- like StyledButton's `clicked` signal, this
// never owns `value` itself; a caller binds it in and reacts to `moved`.
//
// Interaction logic (drag-to-position, wheel-to-step) is the same shape as
// Brain Shell's AudioControl.qml `ChannelColumn` slider, rotated from their
// single big vertical bar to a horizontal one sized for a list row -- this
// project's audio popup shows many rows at once (per-app streams, per-device
// rows), where one vertical bar per row doesn't fit a list; wiremix
// (github.com/tsowell/wiremix, the reference for the audio popup's tabs) uses
// this same inline horizontal-bar-per-row shape.

import QtQuick
import qs.theme

Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0.05
    property bool muted: false

    signal moved(real value)

    implicitWidth: 120
    implicitHeight: 20

    function _clamp(v) {
        return Math.max(root.from, Math.min(root.to, v));
    }
    function _valueAt(mx) {
        return root._clamp(root.from + (mx / root.width) * (root.to - root.from));
    }

    readonly property real _frac: root.to > root.from ? root._clamp((root.value - root.from) / (root.to - root.from)) : 0

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.elev4

        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: Math.max(parent.radius * 2, track.width * root._frac)
            radius: parent.radius
            color: root.muted ? Theme.textFaint : Theme.accent500
            Behavior on color { ColorAnimation { duration: Anim.fast } }
            Behavior on width {
                enabled: !area.pressed
                NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            id: thumb
            width: 12
            height: 12
            radius: 6
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(track.width - width, track.width * root._frac - width / 2))
            color: root.muted ? Theme.textFaint : Theme.textHi
            Behavior on color { ColorAnimation { duration: Anim.fast } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.moved(root._valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(root._valueAt(mouse.x));
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta = event.angleDelta.y > 0 ? root.stepSize : -root.stepSize;
                root.moved(root._clamp(root.value + delta));
            }
        }
    }
}
