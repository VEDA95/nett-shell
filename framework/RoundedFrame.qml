// The screen's own rounded border: a black frame of uniform thickness
// (`inset`) around all four edges, whose inner boundary is rounded with
// `radius` -- the classic "rounded bezel" shape, standard for a rect inset by
// a margin with its own corner radius (this is exactly what
// Quickshell.Widgets.ClippingRectangle would give a single rectangle, but
// this draws it as an *overlay above windows* instead of only around the
// wallpaper, so window corners read as rounded too -- see the frame module
// that hosts this for why that split matters).
//
// Built from parts rather than one clipped shape because a straight
// full-width/height strip is much cheaper to rasterize than a rounded-rect
// path at 4K, and Corner (in "concave" mode) only has to cover the small
// corner squares where the curve actually lives:
//
//   inset ---+-------------------------------+--- inset
//            |  4 straight strips (uniform   |
//            |  `inset` thickness) along all  |
//            |  four edges, PLUS              |
//            |  4 Corner tiles (concave mode, |
//            |  radius `radius`, or `topRadius`|
//            |  for the top two) offset       |
//            |  (inset,inset) from each       |
//            |  screen corner, filling near   |
//            |  their own (screen) corner and |
//            |  receding to leave the rounded |
//            |  content boundary transparent. |
//
// Why this combination is exactly right (not just "close enough"): within an
// (inset+radius)-sized box at a screen corner, the content boundary is a
// straight line at distance `inset` along each edge, curving through a
// radius-`radius` arc centred at (inset+radius, inset+radius). The straight
// strips already cover everything up to `inset` along each axis; what is left
// uncovered, out to the corner, is exactly the concave Corner piece -- neither
// gap nor overlap.
//
// `topRadius` exists because a bar changes what "the corner" needs to cover.
// The bar draws its pills square at their true outer corners on purpose (see
// BarShape.qml) and relies entirely on THIS tile to round them -- so when a
// bar is present, `topRadius` must be at least `bar.height` (the tile starts
// at y=inset just like the bar itself, so its bottom edge at y=inset+topRadius
// has to reach at least as far as the bar's own bottom edge at
// y=inset+barHeight), or the tile falls short and leaves a flat, unrounded
// sliver between the two. With no bar, `topRadius` is just `radius` and the
// tile behaves exactly like the bottom two corners.

import QtQuick
import qs.theme
import qs.framework

Item {
    id: root

    property real inset: Sizing.frameInset
    property real radius: Sizing.frameRadius
    property real topRadius: radius
    property color color: Theme.frame

    // ---- straight edges ----
    Rectangle {
        x: 0; y: 0
        width: root.width; height: root.inset
        color: root.color
    }
    Rectangle {
        x: 0; y: root.height - root.inset
        width: root.width; height: root.inset
        color: root.color
    }
    Rectangle {
        x: 0; y: root.inset
        width: root.inset; height: Math.max(0, root.height - 2 * root.inset)
        color: root.color
    }
    Rectangle {
        x: root.width - root.inset; y: root.inset
        width: root.inset; height: Math.max(0, root.height - 2 * root.inset)
        color: root.color
    }

    // ---- corners: concave fill (frame material recedes, content shows
    // through the curve), offset (inset, inset) from each screen corner ----
    Corner {
        corner: 0; concave: true; radius: root.topRadius; fillColor: root.color
        x: root.inset; y: root.inset
    }
    Corner {
        corner: 1; concave: true; radius: root.topRadius; fillColor: root.color
        x: root.width - root.inset - root.topRadius; y: root.inset
    }
    Corner {
        corner: 2; concave: true; radius: root.radius; fillColor: root.color
        x: root.width - root.inset - root.radius; y: root.height - root.inset - root.radius
    }
    Corner {
        corner: 3; concave: true; radius: root.radius; fillColor: root.color
        x: root.inset; y: root.height - root.inset - root.radius
    }
}
