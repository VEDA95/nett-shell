// A popup anchored to a bar item (or any Item), positioned automatically on
// whichever screen that item lives on, with a lazily-loaded content component
// and a proper exit animation.
//
// Two problems this solves that would otherwise leak into every feature widget:
//
// 1. Multi-monitor placement. `anchor.window` is set to
//    `anchorItem.QsWindow.window` -- the window the anchor item itself belongs
//    to -- and `anchor.rect` to that same window's `itemRect(anchorItem)`. The
//    popup therefore always appears on the correct monitor with no `screen`
//    assignment and no coordinate math: whichever bar owns the clicked item is
//    where the popup opens. (Both QsWindowAttached and PopupAnchor.rect were
//    confirmed against the installed qmltypes -- QsWindowAttached exposes
//    `window` and `itemRect(item)`, and PopupAnchor.rect accepts the QRectF that
//    returns.)
//
// 2. The exit-animation problem. `PopupWindow.visible = false` destroys the
//    window immediately, and the content is its child -- so a naive
//    `visible: shown` gives zero exit animation, ever. `shown` here is the
//    *logical* state a caller drives; `_alive` keeps the window (and therefore
//    its content) alive until PopupSurface's exit transition reports it is
//    actually done.
//
// Content is provided via the `content` alias (a Component), loaded lazily so
// nothing behind an unopened popup is ever instantiated.

import QtQuick
import Quickshell
import qs.theme
import qs.config
import qs.framework

PopupWindow {
    id: root

    /// Logical shown/hidden state -- drive this, never `visible` directly.
    property bool shown: false

    /// Emitted when the popup's own resting-notch click zone is clicked
    /// while open (see PopupSurface.qml's `dismissRequested` -- this just
    /// re-emits it). The CALLER should react by setting whatever property
    /// it bound `shown` to back to false (e.g. Bar.qml's `calendarShown`).
    /// This deliberately does NOT set `root.shown = false` itself: `shown`
    /// here is normally a BINDING to that caller-owned property, and an
    /// imperative write to a bound property permanently breaks the binding
    /// -- the exact bug `grabFocus` caused earlier by doing this to
    /// `visible`. Bubbling the request up and letting the caller mutate its
    /// OWN property keeps that binding intact.
    signal dismissRequested

    /// The item this popup anchors to. Determines both screen and position.
    required property Item anchorItem

    /// Which corner of the anchor item's own rect this popup grows out of --
    /// Edges.Left | Edges.Right | Edges.None. Serves double duty: it is both
    /// the `PopupAdjustment.Slide` gravity for on-screen positioning AND
    /// (forwarded to PopupSurface.originEdge) which side stays fixed while
    /// the opposite edge sweeps out during growth. These have to agree --
    /// positioning and growth direction are the same corner by construction,
    /// not two things that could independently disagree.
    property int side: Edges.Right

    /// Forwarded straight to PopupSurface.restWidth/restHeight -- the size
    /// this popup's anchor already occupies at rest, so growth animates only
    /// the delta beyond what's already on screen. See PopupSurface.qml's
    /// header for why starting from 0 instead visibly desyncs from content.
    property real restWidth: 0
    property real restHeight: 0

    /// The popup's content, instantiated only once `shown` first becomes true.
    /// LazyLoader uses `component`, not QtQuick.Loader's `sourceComponent`.
    property alias content: loader.component

    // ---- window lifetime ----
    // Stays alive (visible) through the exit animation even after `shown` goes
    // false; PopupSurface.exitFinished is what finally releases it.
    property bool _alive: false
    visible: root.shown || root._alive

    color: "transparent"

    // grabFocus is OFF, not wired to Config.popups.grabFocus, despite that
    // option existing. Observed bug: reopening a popup after its first full
    // close would flash and immediately vanish again. Best explanation:
    // grabFocus's built-in click-outside dismissal appears to hide the window
    // by writing `visible` imperatively from C++ -- and any imperative write to
    // a property PERMANENTLY breaks a prior QML binding on it, which is exactly
    // what `visible: root.shown || root._alive` is. Once broken, `visible` is a
    // dead property stuck wherever that write left it, and nothing here can
    // ever show the popup again. Click-outside-dismiss will come back properly
    // via HyprlandFocusGrab instead, whose `cleared()` signal this file can
    // route through `shown = false` itself -- keeping `shown` as the one
    // authority a binding can safely depend on, rather than something else
    // reaching in and mutating `visible` directly.
    grabFocus: false

    implicitWidth: surface.implicitWidth
    implicitHeight: surface.implicitHeight

    // Guard on `.window` itself, not just the attached object's truthiness --
    // QsWindowAttached always exists once accessed, but itemRect() throws if
    // the item isn't yet a member of a window (confirmed at runtime: "Cannot
    // call itemRect before item is a member of a window"). `.window` stays
    // null until then, and the binding re-evaluates once it changes.
    readonly property var _anchorWindow: root.anchorItem?.QsWindow?.window ?? null

    anchor {
        window: root._anchorWindow
        // itemRect() is an imperative call, not a bound property -- QML only
        // re-evaluates this binding when something it reads changes, and
        // `_anchorWindow` typically goes non-null once, very early (as soon
        // as the bar's own window exists), well before sibling layout
        // (anchors, implicit widths from font metrics) has settled the
        // anchor item's real position. Without a further dependency, the
        // rect silently freezes at whatever near-zero position existed at
        // that first evaluation -- observed live as the popup opening at the
        // window's origin instead of under its anchor. Reading `root.shown`
        // here (its value is unused) forces a fresh itemRect() on every
        // open, which is the only moment position freshness actually matters.
        rect: {
            void root.shown;
            return root._anchorWindow
                ? root.anchorItem.QsWindow.itemRect(root.anchorItem)
                : Qt.rect(0, 0, 0, 0);
        }
        // Edges.Top, not Bottom: the anchor point sits at the TOP of the
        // anchor rect (the resting notch's own top edge, y=0 in the bar
        // window), and gravity: Bottom still means "grow downward" from
        // there -- so the popup's own top OVERLAPS the notch's full resting
        // height instead of starting flush below it. That overlap is the
        // point: the bar's own content over that same area fades to
        // transparent (see Bar.qml's rightContent), so the popup's
        // identically-coloured card is the only thing left showing there,
        // with no seam because there was never a second surface butting up
        // against the first -- one is simply drawn on top of the other.
        edges: Edges.Top
        gravity: Edges.Bottom | root.side
        adjustment: PopupAdjustment.Slide
        margins.top: Config.popups.gap
    }

    onShownChanged: if (root.shown) root._alive = true

    // Cheap diagnostics, left in deliberately: if a lifecycle bug like the
    // grabFocus one above turns up again, this is what will show it -- a
    // `visible` change with no matching `shown`/`_alive` change just before it
    // means something outside this file wrote to `visible` directly.
    onVisibleChanged: if (Config.debug.logIpc)
        console.log(`ShellPopup: visible=${root.visible} shown=${root.shown} _alive=${root._alive}`)
    Connections {
        target: root
        function onClosed() {
            console.log("ShellPopup: closed() fired -- something asked the window to close directly");
            root.shown = false;
        }
    }

    LazyLoader {
        id: loader
        active: root.shown || root._alive
        // Synchronous: this content is small, and an async gap between the
        // window becoming visible and its content actually loading is a
        // plausible second source of the reopen glitch above (a moment with a
        // real, visible window but no sized content yet). Revisit once
        // popups carry heavier content and the load time is worth hiding.
        activeAsync: false
    }

    PopupSurface {
        id: surface
        shown: root.shown
        originEdge: root.side
        restWidth: root.restWidth
        restHeight: root.restHeight
        child: loader.item
        onExitFinished: root._alive = false
        // Re-emit only -- see `root.dismissRequested` above for why this
        // must not set `root.shown` directly.
        onDismissRequested: root.dismissRequested()
    }
}
