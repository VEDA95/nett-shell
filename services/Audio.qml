pragma Singleton

// PipeWire audio: sinks/sources (hardware + virtual devices) and playback/
// recording streams (per-app), backed by Quickshell's native Pipewire service.
//
// The isStream/isSink split below was ground-truthed against this machine's
// real PipeWire graph (a temporary probe in shell.qml, since removed, driving
// `speaker-test` and `pw-record` simultaneously and dumping every node's
// flags), not assumed from the qmltypes docs alone -- the property names are
// actively misleading here. A PLAYBACK stream (audio going TO a sink, e.g. a
// browser) reports isStream=true AND isSink=true -- `isSink` describes which
// direction the stream feeds the graph, not "this is a sink device". A
// RECORDING stream (audio coming FROM a source) reports isStream=true,
// isSink=false. Hardware/virtual devices report isStream=false, with isSink
// distinguishing an actual sink device from an actual source device. So the
// four groups below are `isStream`+`isSink` PAIRS, never `isSink` alone.
//
// PwObjectTracker is mandatory, not optional polish: PwNode.audio.volume reads
// 0 and never updates without a live tracker referencing the node (a
// documented Quickshell footgun, and the reason this project's plan calls it
// out explicitly). One tracker below covers every node this service exposes,
// so nothing downstream needs its own.
//
// Ported pattern, not ported code: Brain Shell's AudioControl.qml (see
// services/AudioControl.qml as fetched, and modules/Right/Audio.qml) proves
// the same `Pipewire.nodes.values` + PwObjectTracker approach works live in a
// real shell, including list membership updating as devices/streams come and
// go -- but their popup only ever shows the CURRENT default sink/source plus a
// device-picker list, never a live per-app stream list, so their code never
// actually exercises list-membership reactivity the way playbackStreams/
// recordingStreams below need to. That was verified separately here, live,
// before AudioPopup.qml was built on top of it.

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    function _hasAudio(n) {
        return !!n && n.audio !== null;
    }

    readonly property var sinks: Pipewire.nodes.values.filter(n => root._hasAudio(n) && !n.isStream && n.isSink)
    readonly property var sources: Pipewire.nodes.values.filter(n => root._hasAudio(n) && !n.isStream && !n.isSink)
    readonly property var playbackStreams: Pipewire.nodes.values.filter(n => root._hasAudio(n) && n.isStream && n.isSink)
    readonly property var recordingStreams: Pipewire.nodes.values.filter(n => root._hasAudio(n) && n.isStream && !n.isSink)

    /// Best human-readable label: a stream prefers PipeWire's application.name
    /// property (e.g. "Firefox"); a device falls back through
    /// nickname > description > name, matching Brain Shell's own deviceName().
    function label(node) {
        if (!node)
            return "Unknown";
        const app = node.properties?.["application.name"];
        return app || node.nickname || node.description || node.name || "Unknown";
    }

    readonly property real minVolume: 0.0
    // Deliberately NOT Config.osd.maxVolume (1.5, allowing overshoot) --
    // that knob is for the not-yet-built OSD's quick keyboard-triggered
    // adjustments, a separate design decision from this popup's deliberate
    // mixer UI. Capped at a flat 100% here per explicit request: no path
    // through this shell's own sliders or scroll-to-adjust should be able
    // to blast well past 100% by accident.
    readonly property real maxVolume: 1.0

    function clampVolume(v) {
        return Math.max(root.minVolume, Math.min(root.maxVolume, v));
    }

    /// Cubic amplitude<->slider mapping (the wpctl/pavucontrol convention, and
    /// this project's own plan calls it out explicitly): PwNodeAudio.volume is
    /// linear amplitude, not perceived loudness, so a linear slider feels dead
    /// near the top and hypersensitive near the bottom. slider = amp^(1/3),
    /// amp = slider^3.
    function ampToSlider(amp) {
        return Math.cbrt(Math.max(0, amp));
    }
    function sliderToAmp(slider) {
        const s = Math.max(0, slider);
        return s * s * s;
    }

    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }
    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }
}
