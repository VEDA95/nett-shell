// The animated chrome every anchored popup shares: a card that grows out of
// its anchor in both width AND height at once, flush against it with no gap
// and no colour/border seam, so the bar pill and the card genuinely read as
// one continuous surface that got taller -- not two components glued
// together, even though structurally they are still two windows.
//
// The growth mechanism is a direct port of Brain Shell's
// `NotificationsPopup.qml` (github.com/Brainitech/Brain_Shell): its `sizer`
// Item animates `width` and `height` together (`Easing.InOutCubic`, one
// shared duration), while the popup WINDOW's own implicit size stays fixed
// at the full size the whole time -- only the inner clip grows.
//
// Critically, that `sizer` does NOT start from 0: its closed width is
// `Theme.rNotchMinWidth + fw` -- the bar's own RESTING notch width, not
// nothing. `restWidth`/`restHeight` below exist for exactly that reason.
// Starting from 0 (this file's first attempt at this technique) animates the
// full distance from nothing every time, which is both a slower-feeling
// grow and, worse, visibly desynced from content: the clip crosses whatever
// width/height a reader would need to recognize the card as "the same
// pill, bigger" well after the card has already been visibly growing for a
// while. Starting from the pill's own resting size means the very first
// frame the popup is visible already matches what was on screen a moment
// before, and growth is only the delta beyond that.
//
// `sizer` (a plain Item, plain `clip: true`) is what animates -- `card`
// itself stays at its own natural full size always. This wasn't the first
// design tried: originally `card`'s own `width`/`height` animated directly,
// so its rounded-rect background would redraw correctly at every size
// (a fixed-size card clipped by an outer Item, tried before THAT, showed a
// straight cut where the rounded corner should be, since the corner only
// existed at the full, not-yet-reached size). That fix worked for the
// background, but `card` drawing its own background is exactly what this
// file no longer does -- `shape` (the Canvas below) draws the visible
// background now, independent of `card` entirely. With `card` no longer
// needing to resize for its OWN rendering, forcing it to resize just to
// drive the clip put it in an impossible spot: pin the child at natural
// size (needed so content doesn't compress into the corner as `card`
// shrinks) and the wrapper's own clip stopped reliably bounding a child
// larger than itself, visibly overflowing while shrinking. Splitting "what
// animates" (`sizer`) from "what holds content" (`card`, always natural
// size) removes that conflict rather than trading one symptom for another.
//
// The free top corner is NOT a plain rounded-rectangle corner -- it's drawn
// to match the bar's own resting pill edge, screenshotted directly and
// measured rather than re-derived from BarShape's source a third time: ONE
// quarter-circle dip (radius Sizing.barJointRadius), material receding once
// near the very top, then STRAIGHT DOWN at that recessed position for the
// rest of the card's height, ending in a normal rounded corner at that same
// inset -- not a return trip back to full flush. Two earlier attempts tried
// to bring the edge back out to x=0 below the dip (first via a second
// arcTo, then via a matched-tangent bezierCurveTo) on the assumption that
// "matching the bar's joint" meant reproducing BOTH of BarShape's arcs --
// but BarShape's second arc exists only because its own path terminates at
// the bar's actual bottom edge right there; nothing analogous applies once
// the shape keeps going for the calendar below it. Both attempts also
// produced a real, visible artifact (a shelf, then a cusp) that the single
// reference curve simply doesn't have.
//
// Three lessons from getting earlier parts of this wrong before landing here:
//   1. A plain translate slide (PopupSlide.qml, their OTHER, more general
//      popup container) does not grow the card at all -- it looks like two
//      components because there genuinely is no size change to synchronize
//      against the bar widening alongside it. Growth, not translation, is
//      what "expand vertically" in the coordinating bar behavior requires.
//   2. Colour and border are NOT incidental: a card whose fill differs from
//      the bar pill's (Theme.elev3 vs Theme.surfacePill) or that draws its
//      own border reads as a distinct object no matter how well the
//      geometry lines up. Matched exactly here -- see `card` below.
//   3. Only ONE corner is square, not both -- see above.
//
// Built on ClippingWrapperRectangle (Quickshell.Widgets), which keeps
// handling margin/child-centering the way it always has AND clips its own
// content to its own (possibly mid-animation, smaller-than-natural) rounded
// bounds -- exactly the behavior needed here, with no separate clip Item.

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme

Item {
    id: root

    /// Logical shown/hidden state. Drive this, not width/height directly.
    property bool shown: false

    /// Which screen edge this grows away from -- Edges.Left | Edges.Right --
    /// i.e. which corner of `root` stays fixed while the opposite edge
    /// sweeps out, AND which top corner stays square (the anchored side).
    property int originEdge: Edges.Right

    /// The size this popup's anchor already occupies at rest -- e.g. the bar
    /// pill's own resting width/height -- so growth animates only the delta
    /// beyond what's already visible, not the full distance from nothing.
    /// Defaults to 0 for a popup with no such matching anchor to start from.
    property real restWidth: 0
    property real restHeight: 0

    /// The content child, forwarded straight to the inner card.
    property alias child: card.child

    /// Emitted once the exit transition (the shrink back to 0) finishes.
    signal exitFinished

    /// Emitted when the resting-notch band (the region that used to hold the
    /// bar's own clickable pill content) is clicked while open. This popup
    /// now physically sits above the bar in that region -- once open, its
    /// own window is what's under the cursor there, not the bar's -- so the
    /// bar's own click-to-toggle MouseArea (still very much present in
    /// Bar.qml) is simply unreachable until this popup closes. PopupSurface
    /// doesn't mutate `shown` itself: that's driven from outside (ultimately
    /// from Bar.qml's `calendarShown`), and reaching in to flip it directly
    /// here would desync from whatever's actually driving it, the same class
    /// of bug `grabFocus` caused earlier by writing `visible` imperatively.
    signal dismissRequested

    // `root` itself is the window's real footprint and stays at card's full
    // natural size AT ALL TIMES -- only `card`'s own width/height, below,
    // animate.
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    width: root.implicitWidth
    height: root.implicitHeight
    clip: true

    onShownChanged: {
        exitTimer.stop();
        if (!root.shown)
            exitTimer.start();
    }

    // Mirrors NotificationsPopup's closeTimer: the window (see ShellPopup's
    // `_alive`) has to stay up until the shrink-back-to-0 animation below has
    // actually finished, or it would vanish mid-shrink.
    Timer {
        id: exitTimer
        interval: Anim.base + 20
        onTriggered: root.exitFinished()
    }

    // The visible background: a Canvas, not a plain rounded Rectangle, so the
    // free top corner can draw the bar's own joint curve rather than a
    // generic rounded corner. Tracks `sizer`, NOT `card` -- `card` sits at
    // its own natural full size always now (see `sizer` below), but the
    // visible background still needs to grow/shrink with the animation.
    Canvas {
        id: shape
        anchors.fill: sizer

        readonly property real jr: Sizing.barJointRadius
        readonly property real cr: Sizing.radiusLg
        readonly property bool flareLeft: root.originEdge !== Edges.Left

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Theme.surfacePill;

            const w = width, h = height;
            const R = jr, CR = Math.min(cr, h / 2, w / 2);

            ctx.beginPath();
            if (flareLeft) {
                // Square top-right (anchored, flush) -> straight top edge ->
                // ONE dip inward (arcTo: horizontal tangent in, vertical
                // tangent out -- a normal quarter-circle) -> straight down at
                // that same inset all the way to the bottom -> normal
                // rounded bottom-left corner, still at that inset -> square
                // bottom-right, flush with the anchored edge the whole way.
                //
                // Earlier attempts tried to bring the edge back OUT to full
                // flush x=0 below the dip -- that was never actually what
                // the reference shows. Screenshotted the bar's own resting
                // pill directly (not re-derived from BarShape's source a
                // third time) and its joint is a SINGLE curve: recede once
                // near the top, then straight down at that recessed
                // position for the rest of the shape's height. No return
                // trip. Trying to force one is exactly what produced the
                // "chin" (arcTo return, wrong tangent) and then the "cleft"
                // (bezierCurveTo return, technically smooth but still a
                // shape that was never actually there in the reference).
                ctx.moveTo(w, 0);
                ctx.lineTo(0, 0);
                ctx.arcTo(R, 0, R, R, R);
                ctx.lineTo(R, h - CR);
                ctx.arcTo(R, h, R + CR, h, CR);
                ctx.lineTo(w, h);
            } else {
                // Mirror image for a left-anchored popup: joint and rounding
                // on the right side instead.
                ctx.moveTo(0, 0);
                ctx.lineTo(w, 0);
                ctx.arcTo(w - R, 0, w - R, R, R);
                ctx.lineTo(w - R, h - CR);
                ctx.arcTo(w - R, h, w - R - CR, h, CR);
                ctx.lineTo(0, h);
            }
            ctx.closePath();
            ctx.fill();
        }
    }

    // `sizer` is what actually animates now, not `card`. Two earlier
    // attempts both had `card` itself resize (either drawing its own
    // rounded background, or relying on ClippingWrapperRectangle's shader
    // clip / resizeChild): the first made the corner un-round mid-growth
    // (a rounded rect's corners only exist at its real size), and fixing
    // THAT by pinning the child's own size (`resizeChild: false`) then made
    // content overflow while shrinking, because the wrapper's own clip
    // didn't reliably bound a child held at a size larger than the
    // wrapper's current one. Both problems share one cause: something was
    // being asked to be simultaneously "the thing being clipped" and "the
    // thing whose size defines the clip region," at the same time.
    //
    // Splitting those apart removes the conflict entirely. `shape` (the
    // Canvas above) already redraws the correct background at whatever size
    // it currently is, independent of anything here -- so `card` no longer
    // needs to be visible OR resized at all; it can just sit at its own
    // natural full size, always, holding Calendar undistorted. `sizer` is a
    // plain Item with a plain `clip: true` (no shader, no wrapper
    // shenanigans -- the single most basic, reliable clipping mechanism
    // QtQuick has) that animates and crops whatever of `card` currently
    // falls outside it.
    Item {
        id: sizer
        anchors.top: parent.top
        anchors.right: root.originEdge !== Edges.Left ? parent.right : undefined
        anchors.left: root.originEdge === Edges.Left ? parent.left : undefined
        clip: true

        width: root.shown ? card.implicitWidth : root.restWidth
        height: root.shown ? card.implicitHeight : root.restHeight
        Behavior on width {
            NumberAnimation { duration: Anim.base; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: Anim.base; easing.type: Easing.OutCubic }
        }

        // Declared BEFORE `card`, so `card` (and anything interactive inside
        // it, like Calendar's own month-nav chevrons) paints and hit-tests
        // ON TOP of this -- a click that lands on a chevron is consumed by
        // the chevron's own MouseArea and never reaches this one; a click
        // anywhere else in the resting-notch band falls through to here.
        // Sized to `restWidth`/`restHeight`, not the popup's current
        // (possibly wider/taller) size -- this is specifically standing in
        // for the bar's own original click target, not "close on any click
        // anywhere in the popup." Anchored to the SAME edge as `card`/`shape`
        // (originEdge) -- the resting-width area sits at whichever edge this
        // grows FROM, not wherever it's currently grown TO.
        MouseArea {
            anchors.top: parent.top
            anchors.right: root.originEdge !== Edges.Left ? parent.right : undefined
            anchors.left: root.originEdge === Edges.Left ? parent.left : undefined
            width: root.restWidth
            height: root.restHeight
            onClicked: root.dismissRequested()
        }

        ClippingWrapperRectangle {
            id: card
            anchors.top: parent.top
            anchors.right: root.originEdge !== Edges.Left ? parent.right : undefined
            anchors.left: root.originEdge === Edges.Left ? parent.left : undefined

            // Fully transparent -- `shape` above draws the actual visible
            // background. `card` only exists now to give MarginWrapperManager
            // something to auto-margin/position `child` inside of, always at
            // its own natural size (no width/height override here at all).
            color: "transparent"
            radius: 0
            border.width: 0
            margin: Sizing.spacingSm
        }
    }
}
