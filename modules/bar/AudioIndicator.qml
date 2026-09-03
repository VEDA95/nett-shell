// The bar's audio icon: click requests the popup toggle, scroll adjusts the
// default sink's volume by Config.osd.volumeStep (this project's own plan
// calls for "volume (scroll +-5% per Waybar's existing scroll-step)" -- this
// shell's own prior CSS/config, not Brain Shell), right-click toggles mute --
// icon selection (by volume/mute) and hover-reveal percentage are ported from
// Brain Shell's modules/Right/Audio.qml.
//
// This is a plain icon with no popup of its own -- Bar.qml owns the actual
// ShellPopup, anchored to rightGroup exactly like Calendar's, because that
// (not a small standalone dropdown under the icon) turned out to be the real
// Brain Shell pattern: their own NetworkPopup.qml (which hosts Wifi/
// Bluetooth/VPN/Hotspot) uses the identical sizer+PopupShape flush-flare
// growth as their Calendar-equivalent, anchored to a fixed screen corner, not
// itemRect-anchored to whichever icon was clicked. An earlier version of this
// file owned a standalone dropdown popup instead, based on a read of
// AudioPopup.qml alone (which genuinely IS a different, smaller mechanism in
// their code) generalized too far to "every right-group icon" without
// checking the others first -- corrected after actually reading
// NetworkPopup.qml.

import QtQuick
import qs.theme
import qs.config
import qs.components
import qs.services

Item {
    id: root

    signal toggleRequested

    implicitWidth: row.implicitWidth + Sizing.spacingXs * 2
    implicitHeight: Sizing.barHeight

    readonly property var _sink: Audio.sink
    readonly property bool _muted: root._sink?.audio ? root._sink.audio.muted : false
    readonly property real _volume: root._sink?.audio ? root._sink.audio.volume : 0

    readonly property string _icon: {
        if (!root._sink?.ready || root._muted)
            return "volume-mute";
        if (root._volume > 0.6)
            return "volume-high";
        if (root._volume > 0.2)
            return "volume-medium";
        if (root._volume > 0)
            return "volume-low";
        return "volume-mute";
    }

    HoverHandler {
        id: hov
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Sizing.spacingXs

        StyledIcon {
            name: root._icon
            iconSize: Sizing.iconMd
            tone: hov.hovered ? "accent" : "body"
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            id: pctWrapper
            readonly property bool show: hov.hovered
            implicitWidth: show ? pctText.implicitWidth : 0
            implicitHeight: pctText.implicitHeight
            clip: true
            anchors.verticalCenter: parent.verticalCenter
            Behavior on implicitWidth {
                NumberAnimation { duration: Anim.fast; easing.type: Easing.InOutCubic }
            }

            StyledText {
                id: pctText
                text: Math.round(root._volume * 100) + "%"
                size: "xs"
                tone: hov.hovered ? "accent" : "body"
                mono: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (root._sink?.audio)
                    root._sink.audio.muted = !root._sink.audio.muted;
            } else {
                root.toggleRequested();
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (!root._sink?.audio)
                    return;
                const step = Config.osd.volumeStep;
                const delta = event.angleDelta.y > 0 ? step : -step;
                root._sink.audio.volume = Audio.clampVolume(root._sink.audio.volume + delta);
            }
        }
    }
}
