// The bar's background: three rounded "pill" bulges (left/center/right)
// connected by fully transparent gaps, drawn as one continuous Canvas path.
//
// Technique adapted from Brain Shell's SeamlessBarShape.qml
// (github.com/Brainitech/Brain_Shell, src/shapes/SeamlessBarShape.qml). The
// key insight that made the internal joints tractable -- and that a lot of
// hand-derived Bezier math earlier this session kept getting wrong -- is that
// the "concave bar / convex wallpaper" interlock at each JOINT is not a
// special concave curve at all. It's two ordinary CONVEX rounded corners
// (Canvas2D `arcTo`, which handles the tangent geometry internally) connected
// by a short straight vertical segment between two different heights. The
// "wallpaper bulges up" appearance is simply the natural complement of those
// two normal corners -- whatever the bar's own path doesn't cover is
// transparent, revealing the real wallpaper underneath.
//
// The TRUE outer corners (bottom-left of the left pill, bottom-right of the
// right pill) are deliberately square here, matching Brain Shell's own
// version -- an earlier pass gave them their own `arcTo` rounding, which was
// wrong in a way no amount of radius-tuning could fix: `arcTo` always curves
// AWAY from the sharp corner (narrower at the very edge, widening inward),
// which is backwards from how the screen's rounded corner actually reads in
// the reference image (full material at the edge, a normal convex wallpaper
// bulge cut in further inward). That bulge is exactly what
// framework/RoundedFrame.qml's Corner tiles already draw correctly for the
// screen frame -- so the bar leaves its own outer corners square and lets the
// frame's corner tile (sized to fully cover the bar's height when a bar is
// present -- see modules/frame/FrameOverlay.qml) do that job once, the same
// way it does when there's no bar at all.
//
// This bar window's own height is constant (see Bar.qml's header on why a
// `Behavior` on the real window height was reverted) -- the calendar's
// vertical growth lives entirely in its own popup window instead, so every
// pill here shares one uniform height with no per-segment distinction.

import QtQuick

Canvas {
    id: root

    property real leftWidth: 0
    property real centerWidth: 0
    property real rightWidth: 0

    property real radius: 12
    property color color: "black"

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLeftWidthChanged: requestPaint()
    onCenterWidthChanged: requestPaint()
    onRightWidthChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        const r = root.radius;
        const h = root.height;
        const w = root.width;

        const leftEnd = root.leftWidth;
        const centerStart = (w - root.centerWidth) / 2;
        const centerEnd = centerStart + root.centerWidth;
        const rightStart = w - root.rightWidth;

        // The center group is the only one realistically ever empty (no
        // focused window title) -- left always has at least the launcher
        // icon, right always has the clock. Below 2*r wide, the "turn down"
        // and "turn back up" joint arcs would overlap into a self
        // intersecting sliver, so skip the whole segment and let the gap
        // pass straight through instead.
        const centerVisible = (centerEnd - centerStart) >= 2 * r;

        ctx.beginPath();
        ctx.fillStyle = root.color;

        // Square outer bottom-left corner -- the frame's own corner tile
        // handles the actual rounding, one layer up.
        ctx.moveTo(0, h);

        // Left pill's bottom edge and its right-hand joint (its left side is
        // the square outer corner above, not a joint).
        ctx.lineTo(leftEnd - r, h);
        ctx.arcTo(leftEnd, h, leftEnd, h - r, r);
        ctx.lineTo(leftEnd, r);
        ctx.arcTo(leftEnd, 0, leftEnd + r, 0, r);

        if (centerVisible) {
            ctx.lineTo(centerStart - r, 0);
            ctx.arcTo(centerStart, 0, centerStart, r, r);
            ctx.lineTo(centerStart, h - r);
            ctx.arcTo(centerStart, h, centerStart + r, h, r);
            ctx.lineTo(centerEnd - r, h);
            ctx.arcTo(centerEnd, h, centerEnd, h - r, r);
            ctx.lineTo(centerEnd, r);
            ctx.arcTo(centerEnd, 0, centerEnd + r, 0, r);
        }

        // Right pill's left-hand joint (its right side is the square outer
        // corner below) and bottom edge.
        ctx.lineTo(rightStart - r, 0);
        ctx.arcTo(rightStart, 0, rightStart, r, r);
        ctx.lineTo(rightStart, h - r);
        ctx.arcTo(rightStart, h, rightStart + r, h, r);
        ctx.lineTo(w, h);

        // Square outer bottom-right corner, then close along the top and
        // left edges.
        ctx.lineTo(w, 0);
        ctx.lineTo(0, 0);
        ctx.lineTo(0, h);

        ctx.fill();
    }
}
