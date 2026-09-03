pragma Singleton

// Last config-compile error, if any.
//
// compile.lua writes its failure text to both stderr and Paths.configErr, never
// touching config.json on a bad compile -- so the shell keeps rendering the last
// good config while this singleton surfaces what went wrong. ConfigWatcher calls
// `fail()`/`clear()` directly from the compile Process's exit handler, which is
// the primary path; the FileView below is a second line of defense that also
// picks up a stale error already on disk when the shell starts fresh (e.g. if
// config.lua was broken before the shell was ever launched).

import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property string raw: ""
    property int code: 0
    readonly property bool ok: code === 0 && raw === ""

    // compile.lua's own errors look like "config:14: unexpected symbol near '}'".
    readonly property string line: {
        const m = /^config:(\d+):/.exec(root.raw);
        return m ? m[1] : "";
    }

    readonly property string summary: {
        if (root.ok)
            return "";
        return root.line ? `config.lua:${root.line} — ${_afterColon(root.raw)}` : root.raw;
    }

    function _afterColon(text) {
        // Strip the "config:N:" prefix compile.lua's Lua errors carry, so the
        // toast shows the message, not a repeat of the line number.
        const idx = text.indexOf(":", text.indexOf(":") + 1);
        return idx >= 0 ? text.slice(idx + 1).trim() : text;
    }

    /// Called by ConfigWatcher when the compile Process exits non-zero.
    function fail(exitCode, text) {
        root.code = exitCode;
        root.raw = (text ?? "").trim();
    }

    /// Called by ConfigWatcher when a compile succeeds.
    function clear() {
        root.code = 0;
        root.raw = "";
    }

    // Secondary source: whatever compile.lua last wrote to disk. This is what
    // makes a config that was already broken before the shell started visible
    // immediately, without waiting for the next edit to trigger a recompile.
    FileView {
        id: errFile
        path: Paths.configErr
        watchChanges: true
        blockWrites: true
        printErrors: false
        onLoaded: {
            const text = (errFile.text() ?? "").trim();
            if (text.length > 0 && root.raw === "")
                root.raw = text;
        }
    }
}
