// The clock's popup content: a plain month grid with today highlighted in
// accent red, per the wishlist's "clock + calendar popup" -- this is also
// Wave 1's proof that ShellPopup/PopupSurface anchor and animate correctly
// from a real bar item on both monitors, not just in isolation.
//
// Explicit width/height (bound to the implicit sizes, not left to default)
// because this Item is handed to PopupSurface as a ClippingWrapperRectangle's
// `child` -- the wrapper sizes itself from the child's implicit* properties,
// so this must be self-consistent standing alone rather than relying on a
// parent to size it first.

import QtQuick
import qs.theme
import qs.components

Item {
    id: root

    implicitWidth: 272
    implicitHeight: column.implicitHeight + Sizing.spacingMd * 2
    width: implicitWidth
    height: implicitHeight

    property date _cursor: new Date()
    readonly property int _year: root._cursor.getFullYear()
    readonly property int _month: root._cursor.getMonth()
    readonly property date _today: new Date()

    readonly property var _monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]
    readonly property var _weekdayLabels: ["S", "M", "T", "W", "T", "F", "S"]

    function _daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate(); }
    function _firstWeekday(y, m) { return new Date(y, m, 1).getDay(); }

    // Leading blanks (day: 0) pad the grid to the month's real starting
    // weekday; day/isToday travel together per cell since a bare day number
    // can't tell an empty placeholder apart from "the 0th".
    readonly property var _cells: {
        const total = root._daysInMonth(root._year, root._month);
        const lead = root._firstWeekday(root._year, root._month);
        const cells = [];
        for (let i = 0; i < lead; i++)
            cells.push({ day: 0, isToday: false });
        for (let d = 1; d <= total; d++) {
            cells.push({
                day: d,
                isToday: d === root._today.getDate()
                    && root._month === root._today.getMonth()
                    && root._year === root._today.getFullYear(),
            });
        }
        return cells;
    }

    Column {
        id: column
        x: Sizing.spacingMd
        y: Sizing.spacingMd
        width: root.width - Sizing.spacingMd * 2
        spacing: Sizing.spacingSm

        Item {
            width: parent.width
            height: Sizing.iconMd

            StyledIcon {
                name: "chevron-left"
                iconSize: Sizing.iconMd
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Sizing.spacingXs
                    onClicked: root._cursor = new Date(root._year, root._month - 1, 1)
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: `${root._monthNames[root._month]} ${root._year}`
                size: "sm"
                tone: "hi"
            }

            StyledIcon {
                name: "chevron-right"
                iconSize: Sizing.iconMd
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Sizing.spacingXs
                    onClicked: root._cursor = new Date(root._year, root._month + 1, 1)
                }
            }
        }

        Grid {
            columns: 7
            width: parent.width

            Repeater {
                model: root._weekdayLabels
                delegate: StyledText {
                    width: column.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    size: "xs"
                    tone: "muted"
                }
            }
        }

        Grid {
            columns: 7
            width: parent.width
            rowSpacing: Sizing.spacingXs

            Repeater {
                model: root._cells
                delegate: Item {
                    width: column.width / 7
                    height: 32

                    Rectangle {
                        visible: modelData.isToday
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: 13
                        color: Theme.accent500
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: modelData.day > 0
                        text: modelData.day > 0 ? modelData.day : ""
                        size: "sm"
                        tone: modelData.isToday ? "onAccent" : "body"
                    }
                }
            }
        }
    }
}
