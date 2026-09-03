pragma Singleton

// String-keyed registry: popups register themselves by name, actions register
// themselves by name, and everything else -- IpcHandler, GlobalShortcut,
// eventually bar modules -- talks to those names instead of to each other
// directly.
//
// This is the reason adding a popup never touches ipc/Handlers.qml: a new
// module calls Ipc.registerPopup("dashboard", ctl) once, and every existing
// entry point (IpcHandler's `shell` target, every GlobalShortcut, a future bar
// click handler) can already reach it through `toggle`/`open`/`close`.
//
// A popup registers a controller object shaped as { setShown(bool), isShown() }
// -- deliberately not the popup Item/window itself, so this file never needs to
// know anything about PopupWindow, PanelWindow, or QML at all. Any object with
// those two members qualifies, including a test stub.

import QtQuick
import Quickshell

Singleton {
    id: root

    property var popups: ({})    // name -> { setShown(bool), isShown() }
    property var actions: ({})   // name -> function(arg)

    readonly property var popupNames: Object.keys(root.popups)
    readonly property var actionNames: Object.keys(root.actions)

    /// True while at least one registered popup reports itself open --
    /// drives framework/DismissOverlay.qml, which only intercepts clicks/Esc
    /// while there's actually something to dismiss.
    readonly property bool anyOpen: Object.values(root.popups).some(p => p.isShown())

    // ---- registration ----

    function registerPopup(name, controller) {
        if (root.popups[name])
            console.warn(`Ipc: popup "${name}" registered twice; replacing the previous controller`);
        // Object spread isn't supported by this QML JS engine (confirmed by a
        // parse error at runtime) -- build the replacement object by hand.
        const next = Object.assign({}, root.popups);
        next[name] = controller;
        root.popups = next;
    }

    function unregisterPopup(name) {
        if (!root.popups[name])
            return;
        const next = Object.assign({}, root.popups);
        delete next[name];
        root.popups = next;
    }

    function registerAction(name, fn) {
        if (root.actions[name])
            console.warn(`Ipc: action "${name}" registered twice; replacing the previous handler`);
        const next = Object.assign({}, root.actions);
        next[name] = fn;
        root.actions = next;
    }

    // ---- popups ----

    function open(name) {
        const p = root.popups[name];
        if (!p) {
            console.warn(`Ipc: no popup registered as "${name}"`);
            return;
        }
        p.setShown(true);
    }

    function close(name) {
        root.popups[name]?.setShown(false);
    }

    function toggle(name) {
        const p = root.popups[name];
        if (!p) {
            console.warn(`Ipc: no popup registered as "${name}"`);
            return;
        }
        p.setShown(!p.isShown());
    }

    function isOpen(name) {
        return root.popups[name]?.isShown() ?? false;
    }

    function closeAll() {
        for (const name in root.popups)
            root.popups[name].setShown(false);
    }

    // ---- actions ----

    /// Invoke a registered action by name, e.g. from a GlobalShortcut's
    /// pressed() handler or an IpcHandler function. Unknown actions are logged,
    /// not thrown -- a keybind for a not-yet-built feature should be a no-op
    /// with a visible trace, not a crash.
    function dispatch(action, arg) {
        const fn = root.actions[action];
        if (!fn) {
            console.warn(`Ipc: no action registered as "${action}"`);
            return;
        }
        fn(arg);
    }
}
