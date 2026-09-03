// A horizontal row of icon+label tab pills with a bottom divider -- ported
// from Brain Shell's components/TabSwitcher.qml (github.com/Brainitech/
// Brain_Shell), horizontal orientation only (their vertical, icon-only
// variant is for their ArchMenu and has no call site in this project yet),
// translated from their raw Qt.rgba literals and hardcoded pixel sizes onto
// this project's Theme/Sizing/StyledText/StyledIcon tokens.
//
// Model: [{ key: string, icon: string, label: string }] -- `icon` is a
// theme/Icons.qml name, not a raw glyph. Parent MUST set `width`;
// implicitHeight is fixed at 40 (Brain Shell's own tab height).

import QtQuick
import qs.theme

Item {
    id: root

    property var model: []
    property string currentPage: ""

    signal pageChanged(string key)

    implicitHeight: 40
    // Mirrors implicitHeight into the real height -- a plain Item's height
    // does not default-bind to implicitHeight (the same footgun documented
    // in Calendar.qml and AudioPopup.qml); without this, anything anchored
    // below this component (AudioPopup's own `list`, via `switcher.height`)
    // would measure 0 instead of the real tab-bar height.
    height: implicitHeight

    // Scroll over the tab row to cycle pages, matching Brain Shell's own
    // wheel-cycle behaviour -- cooldown so one wheel notch moves one tab, not
    // several on a fast trackpad flick.
    property bool _scrollBusy: false
    Timer {
        id: scrollCooldown
        interval: 300
        onTriggered: root._scrollBusy = false
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (root._scrollBusy || root.model.length === 0)
                return;
            root._scrollBusy = true;
            scrollCooldown.restart();
            const keys = root.model.map(m => m.key);
            let idx = keys.indexOf(root.currentPage);
            idx = event.angleDelta.y < 0 ? (idx + 1) % keys.length : (idx - 1 + keys.length) % keys.length;
            root.pageChanged(keys[idx]);
        }
    }

    // Centered on its own natural content width, NOT anchors.fill divided
    // into N equal cells -- equal cells with variable-length labels
    // (icon+"Playback" vs icon+"Recording" vs icon+"Input") leave uneven
    // slack per cell, which reads as lopsided outer margins even though the
    // cell boundaries themselves are mathematically even (confirmed live:
    // "Playback"'s pill nearly filled its whole cell while "Input"'s left
    // most of its cell empty, so the LAST cell's slack visually stacked
    // with the popup's own right-edge margin while the FIRST cell's did
    // not). Sizing each tab to its own content and centering the whole
    // cluster makes the two outer margins equal by construction instead.
    Row {
        id: hRow
        anchors.centerIn: parent
        height: parent.height
        spacing: Sizing.spacingSm

        Repeater {
            model: root.model

            delegate: Item {
                id: tab
                required property var modelData
                readonly property bool isActive: root.currentPage === modelData.key

                width: icon.implicitWidth + label.implicitWidth + Sizing.spacingXs + Sizing.spacingLg
                height: hRow.height

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: Sizing.spacingXs
                    anchors.bottomMargin: Sizing.spacingXs
                    radius: height / 2
                    color: tab.isActive ? Theme.accent500 : (hov.hovered ? Theme.hover : "transparent")
                    Behavior on color { ColorAnimation { duration: Anim.fast } }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Sizing.spacingXs

                    StyledIcon {
                        id: icon
                        name: tab.modelData.icon
                        iconSize: Sizing.iconSm
                        tone: tab.isActive ? "onAccent" : (hov.hovered ? "hi" : "muted")
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        id: label
                        text: tab.modelData.label ?? ""
                        size: "xs"
                        tone: tab.isActive ? "onAccent" : (hov.hovered ? "hi" : "muted")
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.pageChanged(tab.modelData.key)
                }
            }
        }
    }

    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: Sizing.borderHair
        color: Theme.border
    }
}
