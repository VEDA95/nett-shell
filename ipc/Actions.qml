pragma Singleton

// Action implementations, reachable from both GlobalShortcut and IpcHandler
// through Ipc.dispatch(name, arg) -- see ipc/Ipc.qml for the registry itself.
//
// Deliberately uneven: screenshot and colorpicker are real, tested Process
// calls, because the underlying tools (grim, slurp, hyprpicker, wl-copy) are
// already installed and the logic is genuinely a handful of lines. lock,
// wallpaper, power, and audio are stubs -- they depend on subsystems this wave
// does not build yet (WlSessionLock+PAM, the Wall service, a confirmation UI,
// Pipewire) -- and each says so explicitly rather than pretending to work.
// Every stub is still registered, so a keybind for it dispatches cleanly to a
// visible warning instead of silently doing nothing or crashing.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

Singleton {
    id: root

    Component.onCompleted: {
        Ipc.registerAction("screenshot", root.screenshot);
        Ipc.registerAction("colorpicker", root.colorPick);
        Ipc.registerAction("lock", root.lock);
        Ipc.registerAction("wallpaper", root.wallpaper);
        Ipc.registerAction("power", root.power);
        Ipc.registerAction("dnd", root.dnd);
        Ipc.registerAction("volume", root.volume);
        Ipc.registerAction("volumeFine", root.volumeFine);
        Ipc.registerAction("mute", root.mute);
        Ipc.registerAction("micMute", root.micMute);
        Ipc.registerAction("media", root.media);
    }

    function _stub(name, waveNote) {
        console.warn(`Actions.${name}: not implemented yet (${waveNote}) -- registered as a no-op so the keybind/IPC path still resolves`);
    }

    // -------------------------------------------------------------------
    // Screenshot -- real
    // -------------------------------------------------------------------

    /// Shell-quote a single argument for embedding in an `sh -c` string.
    function _shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function _timestampedPath() {
        const d = new Date();
        const pad = n => String(n).padStart(2, "0");
        const name = Config.screenshot.filename
            .replace("%Y", d.getFullYear())
            .replace("%m", pad(d.getMonth() + 1))
            .replace("%d", pad(d.getDate()))
            .replace("%H", pad(d.getHours()))
            .replace("%M", pad(d.getMinutes()))
            .replace("%S", pad(d.getSeconds()));
        return Paths.expand(Config.screenshot.directory) + "/" + name;
    }

    Process { id: mkdirProc }
    Process { id: grimProc }

    // Set immediately before slurpProc.running = true, read in its
    // StdioCollector once selection completes -- simpler and leak-free
    // compared to constructing a fresh collector per capture.
    property bool _regionToFile: true

    Process {
        id: slurpProc
        stdout: StdioCollector {
            onStreamFinished: {
                const geom = this.text.trim();
                if (geom.length === 0) {
                    console.log("Actions.screenshot: region selection cancelled");
                    return;
                }
                root._runCapture(`-g ${root._shq(geom)}`, root._regionToFile);
            }
        }
    }

    /// mode: "region" | "window" | "output" | "annotate" | "region-clip" | "output-clip"
    function screenshot(mode) {
        switch (mode) {
        case "region":
            _captureRegion(true);
            break;
        case "region-clip":
            _captureRegion(false);
            break;
        case "output":
            _captureOutput(true);
            break;
        case "output-clip":
            _captureOutput(false);
            break;
        case "window":
            _captureWindow();
            break;
        case "annotate":
            _stub("screenshot(annotate)", "needs satty, installed in Wave 3");
            break;
        default:
            console.warn(`Actions.screenshot: unknown mode "${mode}"`);
        }
    }

    function _ensureDir() {
        mkdirProc.command = ["mkdir", "-p", Paths.expand(Config.screenshot.directory)];
        mkdirProc.running = true;
    }

    function _runCapture(geomArgs, toFile) {
        root._ensureDir();
        const path = toFile ? root._timestampedPath() : "";
        const dest = toFile
            ? `tee ${root._shq(path)} | wl-copy -t image/png`
            : "wl-copy -t image/png";
        const cmd = `grim ${geomArgs} - | ${dest}`;
        grimProc.command = ["sh", "-c", cmd];
        grimProc.running = true;
        if (toFile)
            console.log(`Actions.screenshot: saved ${path}`);
    }

    // A slurp cancellation (Esc) exits non-zero with empty stdout -- the
    // StdioCollector above checks for that and skips grim entirely, since a
    // blank -g argument would capture the whole layout instead of doing
    // nothing.
    function _captureRegion(toFile) {
        if (slurpProc.running)
            return;
        root._regionToFile = toFile;
        const args = (Config.screenshot.slurpArgs ?? []).map(a => root._shq(a)).join(" ");
        slurpProc.command = ["sh", "-c", `slurp ${args}`];
        slurpProc.running = true;
    }

    function _captureOutput(toFile) {
        const name = Hyprland.focusedMonitor?.name;
        if (!name) {
            console.warn("Actions.screenshot: no focused monitor from Hyprland");
            return;
        }
        root._runCapture(`-o ${root._shq(name)}`, toFile);
    }

    function _captureWindow() {
        // HyprlandToplevel has no direct x/y/width/height -- only the raw IPC
        // object (equivalent to one `hyprctl clients -j` entry), which carries
        // `.at` (position) and `.size`. Verified against the installed
        // qmltypes: HyprlandToplevel = { address, handle, wayland, title,
        // activated, urgent, lastIpcObject, workspace, monitor }.
        const t = Hyprland.activeToplevel;
        const obj = t?.lastIpcObject;
        if (!obj || !obj.at || !obj.size) {
            console.warn("Actions.screenshot: no active window geometry available");
            return;
        }
        const geom = `${obj.at[0]},${obj.at[1]} ${obj.size[0]}x${obj.size[1]}`;
        root._runCapture(`-g ${root._shq(geom)}`, true);
    }

    // -------------------------------------------------------------------
    // Colour picker -- real
    // -------------------------------------------------------------------

    Process {
        id: pickerProc
        command: ["hyprpicker", "-f", "hex", "-l", "-r", "-q"]
        stdout: StdioCollector {
            onStreamFinished: {
                const hex = this.text.trim();
                if (hex.length === 0) {
                    console.log("Actions.colorPick: cancelled");
                    return;
                }
                Quickshell.clipboardText = hex;
                console.log(`Actions.colorPick: picked ${hex} (copied to clipboard)`);
                // History persistence and the swatch toast land in Wave 3
                // alongside the rest of the colour picker UI.
            }
        }
    }

    function colorPick() {
        if (pickerProc.running)
            return;
        pickerProc.running = true;
    }

    // -------------------------------------------------------------------
    // Stubs -- depend on subsystems not built yet
    // -------------------------------------------------------------------

    function lock() {
        _stub("lock", "needs WlSessionLock + PamContext, built in Wave 4 as a separate qs -c nett-lock instance");
    }

    function wallpaper(op) {
        _stub(`wallpaper(${op})`, "needs the Wall service, built in Wave 3");
    }

    function power(op) {
        _stub(`power(${op})`, "needs the confirmation UI, built in Wave 2");
    }

    function dnd() {
        _stub("dnd", "needs the Notifs service, built in Wave 2");
    }

    function volume(step) {
        _stub(`volume(${step})`, "needs the Audio/Pipewire service, built in Wave 2");
    }

    function volumeFine(step) {
        _stub(`volumeFine(${step})`, "needs the Audio/Pipewire service, built in Wave 2");
    }

    function mute() {
        _stub("mute", "needs the Audio/Pipewire service, built in Wave 2");
    }

    function micMute() {
        _stub("micMute", "needs the Audio/Pipewire service, built in Wave 2");
    }

    function media(op) {
        _stub(`media(${op})`, "needs the Media/Mpris service, built in Wave 2");
    }
}
