// The audio icon's dropdown content: four tabs mirroring wiremix
// (github.com/tsowell/wiremix, a TUI PipeWire mixer -- this was built to
// offer the same tabs/config options it does) -- Playback, Recording, Output
// Devices, Input Devices. wiremix's fifth tab, Configuration (device
// ports/profiles), and its `c` reroute-a-stream action both need a PwDevice
// API this Quickshell version's Pipewire module doesn't expose at all (no
// ports, no profiles, no writable link routing -- confirmed against the
// installed quickshell-service-pipewire.qmltypes, not assumed) -- so neither
// is here, by explicit decision rather than an oversight.
//
// Each row is its own inline horizontal slider (StyledSlider) rather than
// Brain Shell's single big vertical ChannelColumn -- their popup only ever
// shows the CURRENT default sink/source one at a time, never a live list of
// several. wiremix's own layout (a list of rows, each with an inline bar) is
// what these tabs are actually reproducing; Brain Shell is the source for the
// surrounding chrome (TabSwitcher, the dot/click-to-default row pattern from
// their DeviceRow) instead.

import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    id: root

    readonly property var _tabs: [
        { key: "playback", icon: "play", label: "Playback" },
        { key: "recording", icon: "mic", label: "Recording" },
        { key: "output", icon: "speaker", label: "Output" },
        { key: "input", icon: "mic-external", label: "Input" },
    ]
    property string page: "playback"

    readonly property var _activeList: {
        switch (root.page) {
        case "recording": return Audio.recordingStreams;
        case "output": return Audio.sinks;
        case "input": return Audio.sources;
        default: return Audio.playbackStreams;
        }
    }
    readonly property bool _isDeviceTab: root.page === "output" || root.page === "input"
    readonly property string _emptyText: {
        switch (root.page) {
        case "recording": return "Nothing recording";
        case "output": return "No output devices";
        case "input": return "No input devices";
        default: return "Nothing playing";
        }
    }

    // width/height explicitly bound to the implicit sizes below, not left at
    // Item's own default (0) -- see Calendar.qml's identical line and header
    // comment: this Item is handed to PopupSurface as a
    // ClippingWrapperRectangle's `child`, sized from ITS OWN implicit
    // properties, so it must be self-consistent standing alone. Forgetting
    // this rendered the whole popup at an actual 0x0 (implicitWidth/Height
    // were correct, but nothing reads those for painting -- only width/
    // height do), confirmed live: the popup silently never appeared at all.
    // 408 -- TabSwitcher centers its tab row on its own content width now
    // (not divided into equal cells; see TabSwitcher.qml), so this only
    // needs to comfortably fit that content plus a bit of breathing room,
    // not accommodate the widest label's cell. Measured live via a runtime
    // geometry log: the tab row's natural width is ~353px, so 408 (minus
    // the 24px switcher inset) leaves ~15px margin on each side -- tighter
    // than the 420 used while the layout still had a (since-fixed) equal-
    // cell overflow bug, which needed the extra width as a workaround.
    implicitWidth: 408
    implicitHeight: switcher.implicitHeight + list.implicitHeight + Sizing.spacingSm * 2
    width: implicitWidth
    height: implicitHeight

    TabSwitcher {
        id: switcher
        // Same horizontal inset as `list` below (Sizing.spacingMd on both
        // sides) rather than spanning the full popup width -- the two
        // should share one consistent margin, not each pick their own.
        x: Sizing.spacingMd
        width: parent.width - Sizing.spacingMd * 2
        model: root._tabs
        currentPage: root.page
        onPageChanged: key => root.page = key
    }

    Column {
        id: list
        x: Sizing.spacingMd
        y: switcher.height + Sizing.spacingSm
        width: parent.width - Sizing.spacingMd * 2
        spacing: Sizing.spacingXs

        StyledText {
            visible: root._activeList.length === 0
            text: root._emptyText
            size: "sm"
            tone: "faint"
            topPadding: Sizing.spacingSm
            bottomPadding: Sizing.spacingSm
        }

        Repeater {
            model: root._activeList

            delegate: Item {
                id: row
                required property var modelData

                readonly property bool isDefault: root._isDeviceTab
                    && ((root.page === "output" && Audio.sink?.name === modelData.name)
                        || (root.page === "input" && Audio.source?.name === modelData.name))

                width: list.width
                implicitHeight: 36

                // Default-device indicator (Output/Input tabs only) -- a
                // separate, small click target from the slider below it, so
                // dragging volume can never accidentally reassign the
                // default (ported behaviour from Brain Shell's DeviceRow,
                // which makes the whole row the click target -- split out
                // here because these rows also carry a slider DeviceRow never
                // needed to coexist with).
                Rectangle {
                    id: dot
                    visible: root._isDeviceTab
                    width: 8
                    height: 8
                    radius: 4
                    anchors.left: parent.left
                    anchors.verticalCenter: label.verticalCenter
                    color: row.isDefault ? Theme.accent500 : Theme.textFaint
                    Behavior on color { ColorAnimation { duration: Anim.fast } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.page === "output"
                            ? Audio.setDefaultSink(row.modelData)
                            : Audio.setDefaultSource(row.modelData)
                    }
                }

                StyledText {
                    id: label
                    text: Audio.label(row.modelData)
                    size: "sm"
                    tone: row.isDefault ? "hi" : "body"
                    elide: Text.ElideRight
                    anchors.left: dot.visible ? dot.right : parent.left
                    anchors.leftMargin: dot.visible ? Sizing.spacingXs : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (dot.visible ? dot.width + Sizing.spacingXs : 0)
                        - slider.width - pct.width - muteBtn.width - Sizing.spacingXs * 3
                }

                StyledSlider {
                    id: slider
                    anchors.right: pct.left
                    anchors.rightMargin: Sizing.spacingXs
                    anchors.verticalCenter: parent.verticalCenter
                    width: 90
                    from: Audio.minVolume
                    to: Audio.ampToSlider(Audio.maxVolume)
                    value: row.modelData?.audio ? Audio.ampToSlider(row.modelData.audio.volume) : 0
                    muted: row.modelData?.audio ? row.modelData.audio.muted : false
                    onMoved: v => {
                        if (row.modelData?.audio)
                            row.modelData.audio.volume = Audio.sliderToAmp(v);
                    }
                }

                StyledText {
                    id: pct
                    anchors.right: muteBtn.left
                    anchors.rightMargin: Sizing.spacingXs
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData?.audio ? Math.round(row.modelData.audio.volume * 100) + "%" : "--%"
                    size: "xs"
                    tone: "muted"
                    mono: true
                    horizontalAlignment: Text.AlignRight
                    width: 32
                }

                StyledIcon {
                    id: muteBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: {
                        const muted = row.modelData?.audio?.muted ?? false;
                        if (root.page === "recording" || root.page === "input")
                            return muted ? "mic-off" : "mic";
                        return muted ? "volume-mute" : "volume-high";
                    }
                    iconSize: Sizing.iconSm
                    tone: (row.modelData?.audio?.muted ?? false) ? "accent" : "muted"

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Sizing.spacingXs
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (row.modelData?.audio)
                                row.modelData.audio.muted = !row.modelData.audio.muted;
                        }
                    }
                }
            }
        }
    }
}
