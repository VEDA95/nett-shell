pragma Singleton

// Shared animation durations and easing curves.
//
// Plain `easing.bezierCurve` arrays are used rather than Quickshell's own
// EasingCurve type: EasingCurve is an *evaluation* helper (valueAt/interpolate
// for driving something in JS), not a documented way to assign a QEasingCurve
// from a QML array literal to a NumberAnimation's `easing.bezierCurve` property.
// PropertyAnimation.easing.bezierCurve accepting a flat array is a stable,
// well-documented QtQuick feature, so that is the path used everywhere.
//
// The curves below are lifted from ~/.config/hypr/looknfeel.conf so the shell's
// motion matches the compositor's own window animations instead of feeling like
// a separate layer bolted on top:
//   easeOutQuint   bezier(0.23, 1, 0.32, 1)
//   easeInOutCubic bezier(0.65, 0.05, 0.36, 1)
//   quick          bezier(0.15, 0, 0.1, 1)
//
// Exits are always faster than the enter they mirror -- `exit` is shorter than
// every enter duration, on purpose: a popup that lingers on the way out reads as
// sluggish even when the enter felt fine.

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    readonly property real scale: Config.animation.scale >= 0 ? Config.animation.scale : 1.0
    readonly property bool enabled: Config.animation.enabled && root.scale > 0

    function ms(base) {
        return root.enabled ? Math.round(base * root.scale) : 0;
    }

    // ---- durations ----
    readonly property int instant: 0
    readonly property int fast: ms(Config.animation.fast)     // hover, press, colour
    readonly property int base: ms(Config.animation.base)     // popup enter, expand
    readonly property int slow: ms(Config.animation.slow)     // page transitions, big morphs
    readonly property int exit: ms(Config.animation.exit)     // every exit, no exceptions
    readonly property int spatial: ms(300)                    // position/size moves

    // ---- easing.bezierCurve arrays: [c1x, c1y, c2x, c2y, 1, 1] ----
    readonly property var emphasized: [0.23, 1.00, 0.32, 1.00, 1, 1]     // easeOutQuint
    readonly property var standard: [0.65, 0.05, 0.36, 1.00, 1, 1]       // easeInOutCubic
    readonly property var snappy: [0.15, 0.00, 0.10, 1.00, 1, 1]         // quick
    readonly property var almostLinear: [0.50, 0.50, 0.75, 1.00, 1, 1]

    // ---- spring presets, for SpringAnimation ----
    // A spring reads as "alive" in a way a fixed-duration curve cannot: it
    // responds to velocity, not just position, so interrupting one mid-flight
    // (closing a popup while it's still opening) continues smoothly from
    // wherever it actually is instead of snapping into a new animation from a
    // dead stop -- that continuity is a lot of what makes fluid, Caelestia-style
    // motion feel fluid. Springs are for ENTERS only: on exit a settling spring
    // reads as hesitant, where the fixed `exit` duration above with a plain
    // decisive curve reads as crisp -- keep that split rather than springing
    // both directions.
    //
    // Tuned against a Caelestia reference clip (two independent popouts there
    // settle in roughly 80-150ms) and confirmed live -- "feels perfect now".
    // Treat as the fixed default; only revisit if a specific popup genuinely
    // needs a different feel (tune `springDamping` down for more bounce, up
    // for less, `springStiffness` up to settle faster).
    readonly property real springMass: 1.0
    readonly property real springStiffness: 14.0  // SpringAnimation.spring
    readonly property real springDamping: 0.72
}
