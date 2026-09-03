// One GlobalShortcut per entry in Config.keybinds, dispatching into Ipc.
//
// Instantiator rather than Repeater: GlobalShortcut is not an Item, and
// ObjectRepeater does not exist in this Quickshell build (confirmed absent from
// the installed qmltypes) -- Instantiator (QtQml) is the standard vehicle for a
// model of non-visual objects.
//
// GlobalShortcut only registers the *name*; the actual key combination lives in
// the generated ~/.config/hypr/nett-shell.conf as
// `bind = MODS, KEY, global, <appid>:<name>`. The `name` here and the name baked
// into that generated line come from the exact same derivation
// (hyprgen.shortcut_name in config/lib/hyprgen.lua), carried through
// config.json's `keybinds` array -- so this file never invents a name of its
// own, it only plays back what compile.lua already decided.
//
// Instantiated exactly once from shell.qml, never inside a per-screen Variants:
// duplicate GlobalShortcut objects sharing an appid+name pair can crash per the
// upstream docs.

import QtQml
import Quickshell.Hyprland
import qs.config
import qs.ipc

Instantiator {
    model: Config.keybinds

    delegate: GlobalShortcut {
        id: shortcut
        required property var modelData

        appid: Config.hyprland.shortcutAppId
        name: modelData.name
        description: modelData.desc ?? ""

        onPressed: Ipc.dispatch(modelData.action, modelData.arg)
        // released() is available for hold-to-x interactions; nothing in the
        // current keybind set needs it yet.
    }
}
