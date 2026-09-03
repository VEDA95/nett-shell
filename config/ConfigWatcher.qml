// Watches config.lua and keybinds.lua, recompiles on change, reloads Config.
//
// Instantiated exactly once from shell.qml (this is a Scope, not a Singleton --
// it has no reason to be reachable by name, and Scope keeps it out of the
// service/singleton namespace). FileView already provides inotify inside the
// process that needs to react, so there is no separate watcher daemon: a daemon
// would need its own supervision and version-skew handling against the shell for
// no benefit over a Process spawned directly from here.
//
// The debounce exists because editors commonly fire two or three inotify events
// per save (truncate, write, rename-into-place); without it, a single save could
// trigger two overlapping compiles.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Scope {
    id: root

    property bool compiling: false
    property int lastExitCode: 0

    signal compileFinished(bool ok, bool hyprChanged)

    function recompile() {
        if (compileProcess.running)
            return;
        root.compiling = true;
        compileProcess.running = true;
    }

    // ---- watch sources; a change here means "recompile", not "reload config" ----
    FileView {
        path: Paths.configLua
        watchChanges: true
        blockWrites: true
        printErrors: false
        onFileChanged: debounce.restart()
    }

    FileView {
        path: Paths.keybindsLua
        watchChanges: true
        blockWrites: true
        printErrors: false
        onFileChanged: debounce.restart()
    }

    Timer {
        id: debounce
        interval: 80
        onTriggered: root.recompile()
    }

    // ---- the compile itself ----
    Process {
        id: compileProcess
        command: ["lua", Paths.compileLua, "--quiet"]

        property string stderrText: ""
        property string stdoutText: ""

        stdout: StdioCollector {
            onStreamFinished: compileProcess.stdoutText = this.text
        }
        stderr: StdioCollector {
            onStreamFinished: compileProcess.stderrText = this.text
        }

        onExited: (exitCode, exitStatus) => {
            root.compiling = false;
            root.lastExitCode = exitCode;

            if (exitCode === 0) {
                ConfigError.clear();
                // config.json changed on disk; Config's FileView will pick it up
                // via its own watchChanges, but an explicit reload keeps the
                // update from waiting on a second inotify round-trip.
                Config.fileView.reload();

                const hyprChanged = compileProcess.stdoutText.indexOf("HYPR_CHANGED") !== -1;
                root.compileFinished(true, hyprChanged);
            } else {
                const text = compileProcess.stderrText.trim();
                ConfigError.fail(exitCode, text.length > 0 ? text : `compile.lua exited ${exitCode}`);
                root.compileFinished(false, false);
            }
        }
    }

    Component.onCompleted: root.recompile()
}
