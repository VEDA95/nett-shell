// Workspace switcher: persistent numbered slots with a sliding active
// indicator, backed by live Hyprland.workspaces.
//
// perMonitor defaults false (Config.workspaces.perMonitor): always render
// slots 1..N on every bar, dimming the ones occupied on the OTHER monitor
// rather than hiding them. Hyprland workspaces are global -- a strict
// per-monitor filter would make workspace 3 vanish from this bar the instant
// it's dragged to the other screen, which reads as workspaces randomly
// disappearing rather than a stable, glanceable set of slots. Matches the
// user's existing waybar behaviour (persistent-workspaces with empty output
// arrays = shown everywhere).
//
// The indicator is a single Rectangle whose x/width follow whichever
// delegate reports itself active, animated with the same spring used for bar
// popouts (this reads as a "bar popout"-adjacent, persistent piece of chrome,
// not a notification -- see theme/Anim.qml's springStiffness/springDamping).

import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.theme
import qs.components

Item {
    id: root
    required property var screen

    readonly property var _monitor: Hyprland.monitorFor(root.screen)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Rebuilt whenever the live workspace/monitor state changes. Persistent
    // slots 1..N always appear; any live workspace beyond N (dynamically
    // created) is appended so it's never silently hidden.
    readonly property var _slots: {
        void Hyprland.workspaces.values; // establish the binding dependency
        const live = Hyprland.workspaces.values.filter(w => w.id > 0);
        const byId = new Map(live.map(w => [w.id, w]));
        const mon = root._monitor;
        const persistent = Config.workspaces.persistent;
        const out = [];

        for (let i = 1; i <= persistent; i++) {
            const w = byId.get(i) ?? null;
            out.push(_describe(i, w, mon));
        }
        for (const w of live) {
            if (w.id > persistent) {
                if (Config.workspaces.perMonitor && mon && w.monitor !== mon)
                    continue;
                out.push(_describe(w.id, w, mon));
            }
        }
        return out;
    }

    function _describe(id, w, mon) {
        const onThisMonitor = !!w && !!mon && w.monitor === mon;
        return {
            id,
            ws: w,
            occupied: !!w && w.toplevels.values.length > 0,
            onThisMonitor,
            active: onThisMonitor && mon.activeWorkspace === w,
            urgent: !!w && w.urgent,
            hasFullscreen: !!w && w.hasFullscreen,
        };
    }

    property Item _activeDelegate: null

    Rectangle {
        id: indicator
        visible: root._activeDelegate !== null
        x: root._activeDelegate ? root._activeDelegate.x : 0
        width: root._activeDelegate ? root._activeDelegate.width : 0
        y: 0
        height: parent.height
        radius: height / 2
        color: Theme.accent
        z: -1

        Behavior on x {
            SpringAnimation { spring: Anim.springStiffness; damping: Anim.springDamping; mass: Anim.springMass }
        }
        Behavior on width {
            SpringAnimation { spring: Anim.springStiffness; damping: Anim.springDamping; mass: Anim.springMass }
        }
    }

    Row {
        id: row
        spacing: Sizing.spacingXs

        Repeater {
            model: root._slots

            delegate: Item {
                id: slot
                required property var modelData

                implicitWidth: Math.max(24, label.implicitWidth + Sizing.spacingSm * 2)
                implicitHeight: 24

                onXChanged: if (slot.modelData.active) root._activeDelegate = slot
                Component.onCompleted: if (slot.modelData.active) root._activeDelegate = slot
                onModelDataChanged: if (slot.modelData.active) root._activeDelegate = slot

                StyledText {
                    id: label
                    anchors.centerIn: parent
                    text: String(slot.modelData.id)
                    size: "sm"
                    mono: true
                    tone: slot.modelData.active ? "onAccent"
                        : slot.modelData.urgent ? "error"
                        : slot.modelData.occupied ? (slot.modelData.onThisMonitor ? "hi" : "dim")
                        : "faint"
                    font.bold: slot.modelData.active

                    Behavior on color { ColorAnimation { duration: Anim.fast } }
                }

                // Small urgent-state pulse -- deliberately not a Behavior,
                // since it needs to loop rather than settle once.
                SequentialAnimation on opacity {
                    running: slot.modelData.urgent && !slot.modelData.active
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.4; duration: 450 }
                    NumberAnimation { from: 0.4; to: 1.0; duration: 450 }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (slot.modelData.ws)
                            slot.modelData.ws.activate();
                        else
                            Hyprland.dispatch(`workspace ${slot.modelData.id}`);
                    }
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => Hyprland.dispatch(event.angleDelta.y < 0 ? "workspace e+1" : "workspace e-1")
    }
}
