// IpcHandler instances -- the `qs -c nett-shell ipc call ...` surface.
//
// Instantiated exactly once from shell.qml, never inside a per-screen Variants:
// IpcHandler registers itself under a fixed `target` name, and a second copy in
// a second window would either collide or silently only serve one screen.
//
// Every function here is a thin adapter onto Ipc's registry -- this file adds no
// logic of its own, so the CLI and GlobalShortcut (ipc/Shortcuts.qml) can never
// drift out of agreement about what an action named "screenshot" or a popup
// named "dashboard" actually does.
//
// Reminder for every function below, because it is easy to get wrong silently:
// argument AND return types must be explicitly annotated or Quickshell does not
// register the function at all -- no error, it just does not show up in
// `qs ipc show`.

import Quickshell
import Quickshell.Io
import qs.ipc

Scope {
    IpcHandler {
        target: "shell"

        function toggle(name: string): void {
            Ipc.toggle(name);
        }

        function open(name: string): void {
            Ipc.open(name);
        }

        function close(name: string): void {
            Ipc.close(name);
        }

        function closeAll(): void {
            Ipc.closeAll();
        }

        function isOpen(name: string): bool {
            return Ipc.isOpen(name);
        }

        /// Returns a JSON array of registered popup names -- the scalar-only
        /// return restriction means structured data has to leave as a string.
        function list(): string {
            return JSON.stringify(Ipc.popupNames);
        }

        function reloadConfig(): void {
            Ipc.dispatch("reloadConfig", "");
        }
    }

    IpcHandler {
        target: "action"

        function screenshot(mode: string): void {
            Ipc.dispatch("screenshot", mode);
        }

        function colorpicker(): void {
            Ipc.dispatch("colorpicker", "");
        }

        function lock(): void {
            Ipc.dispatch("lock", "");
        }

        function wallpaper(op: string): void {
            Ipc.dispatch("wallpaper", op);
        }

        function power(op: string): void {
            Ipc.dispatch("power", op);
        }
    }

    IpcHandler {
        target: "osd"

        function volume(delta: real): void {
            Ipc.dispatch("volume", delta);
        }

        function mute(): void {
            Ipc.dispatch("mute", "");
        }

        function micMute(): void {
            Ipc.dispatch("micMute", "");
        }

        function media(op: string): void {
            Ipc.dispatch("media", op);
        }
    }

    IpcHandler {
        target: "notifs"

        function dismissAll(): void {
            Ipc.dispatch("dismissAll", "");
        }

        function dnd(): void {
            Ipc.dispatch("dnd", "");
        }
    }
}
