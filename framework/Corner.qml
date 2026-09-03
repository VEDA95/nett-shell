// A single rounded-corner wedge, drawn as a cubic Bezier rather than
// QtQuick.Shapes' PathArc: PathArc needs `direction` + `useLargeArc` to
// disambiguate between two candidate circle centres, and getting either wrong
// silently renders a *convex* wedge where a concave one was wanted (or vice
// versa) with no error. A cubic sidesteps that: with
// k = 4/3*(sqrt(2)-1) = 0.5522847498307936, it approximates a quarter circle
// to within 0.02%, and its control points are unambiguous.
//
// Two fill modes, sharing the identical arc (only the anchor point differs):
//
//   concave: true   material fills the tile's OWN corner (local 0,0) and
//                    recedes toward the far corner (radius,radius), which
//                    ends up fully transparent. This is what the screen frame
//                    needs where its rounded border eats into a straight
//                    corner -- see framework/RoundedFrame.qml.
//   concave: false  (convex) material fills the pie-slice out of the FAR
//                    corner (radius,radius) instead -- the wallpaper "bulging
//                    up" to fill the notch a bar segment's concave joint
//                    leaves behind. See modules/bar/BarJoint.qml.
//
// Midpoint check (why the constant above is correct, not just plausible): the
// cubic's value at t=0.5 is (radius*(1-k)*3/4 + radius/8, same) which reduces
// to 0.29289*radius in both dimensions. The true circle centred at
// (radius,radius) has its closest point to the origin at distance
// radius*sqrt(2) - radius = radius*(sqrt(2)-1), i.e. offset
// radius - radius/sqrt(2) = 0.29289*radius from each axis. Exact match.
//
// `corner` rotates the same local shape to sit at any of the four corners of
// whatever box it's placed in: 0=top-left (no rotation needed -- the local
// shape already fills-near-origin/recedes-to-far-corner, which for an
// unrotated tile anchored at a box's top-left *is* the top-left corner)
// 1=top-right, 2=bottom-right, 3=bottom-left, each a further 90 degree turn
// around the tile's own centre.

import QtQuick
import QtQuick.Shapes

Shape {
    id: root

    property int corner: 0
    property real radius: 32
    property color fillColor: "black"
    property bool concave: true

    readonly property real _k: 0.5522847498307936

    width: radius
    height: radius
    preferredRendererType: Shape.CurveRenderer

    transform: Rotation {
        origin.x: root.width / 2
        origin.y: root.height / 2
        angle: root.corner * 90
    }

    ShapePath {
        fillColor: root.fillColor
        strokeWidth: 0
        strokeColor: "transparent"

        startX: root.concave ? 0 : root.radius
        startY: root.concave ? 0 : root.radius

        PathLine { x: root.radius; y: 0 }
        PathCubic {
            x: 0; y: root.radius
            control1X: root.radius * (1 - root._k); control1Y: 0
            control2X: 0; control2Y: root.radius * (1 - root._k)
        }
        PathLine {
            x: root.concave ? 0 : root.radius
            y: root.concave ? 0 : root.radius
        }
    }
}
