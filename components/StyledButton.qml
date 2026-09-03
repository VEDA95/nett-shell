// A clickable themed surface with an optional icon and/or label, hover/press
// states, and an `accent` variant for primary actions. StyledIcon and
// StyledText are sibling files in this same directory -- QML resolves them by
// name with no import needed.
//
// `enabled` is not redeclared here: Item already has one, and shadowing it
// would either be a duplicate-property error or silently fight the real thing.

import QtQuick
import qs.theme

Rectangle {
    id: root

    signal clicked

    property string text: ""
    property string icon: ""
    property bool accent: false

    implicitWidth: row.implicitWidth + Sizing.spacingMd * 2
    implicitHeight: Math.max(32, row.implicitHeight + Sizing.spacingSm * 2)
    radius: Sizing.radiusSm
    border.width: Sizing.borderHair
    border.color: root.accent ? Theme.borderAccent : Theme.border
    opacity: root.enabled ? 1.0 : 0.5

    color: {
        if (!root.enabled)
            return Theme.elev2;
        if (root.accent)
            return area.pressed ? Theme.accent600 : area.containsMouse ? Theme.accent400 : Theme.accent500;
        return area.pressed ? Theme.press : area.containsMouse ? Theme.hover : Theme.elev2;
    }

    Behavior on color {
        ColorAnimation { duration: Anim.fast }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Sizing.spacingXs

        StyledIcon {
            visible: root.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            iconSize: Sizing.iconSm
            tone: root.accent ? "onAccent" : "body"
        }

        StyledText {
            visible: root.text.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            size: "sm"
            tone: root.accent ? "onAccent" : "body"
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
