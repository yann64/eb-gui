# eb-gui

The shared contract for [eBasic](https://github.com/yann64/ebasic)'s
universal, cross-toolkit `Application`/`Window` API, managed with `ebpm`.

## Status

Phase 1: `Application`/`Window`, plus `StatusBar`/`Timer` and now
`Menu`/`Toolbar`/`Action` from the Phase 2 slice. GTK4 removed its own
classic `GtkMenuBar`/`GtkToolbar` widgets entirely upstream, so the
`eb-gtk4` side of this needed a real design pass over its modern
`GMenuModel`/`GAction`/`GtkPopoverMenuBar` replacement (see
`GuiMenuAddAction`'s own doc comment below for the resulting capability
mismatch this contract had to paper over: GTK4 actions are natively
shareable across menus, Qt6's binding creates one fresh per call - this
contract follows Qt6's simpler shape). Two real backend adapters exist:
[`eb-gui-gtk4`](https://github.com/yann64/eb-gui-gtk4) and
[`eb-gui-qt6`](https://github.com/yann64/eb-gui-qt6), each with a
near-identical `examples/hello_window.bas` (same calls, differing only
in the `#include` target and two string literals) - this project's own
cross-backend proof, both screenshot-verified live producing the same
behavior, plus a per-adapter headless `examples/verify` exercising
every contract function. **Both existing adapters already run on Haiku
unmodified** (confirmed 2026-09-04: real HaikuPorts `gtk4`/`qt6_base`
packages, `eb-gui-gtk4`/`eb-gui-qt6`'s own `examples/verify` pass in
full, `eb-gtk4`'s `examples/menu_toolbar` renders live with Haiku's
native window decorations) - so a *separate*, BWindow-native
`eb-gui-haiku` adapter is not required just to get eBasic GUI apps
running on Haiku; it would only matter for apps that want to avoid a
GTK4/Qt6 runtime dependency in favor of Haiku's own native toolkit, a
narrower motivation than originally assumed when Haiku support was
scoped as a from-scratch adapter. **A native BWindow adapter was built
anyway** (the user's own choice, on that narrower motivation):
[`eb-gui-haiku`](https://github.com/yann64/eb-gui-haiku), needing zero
native code of its own - all prerequisite work landed in `eb-haiku`
itself. Three real backend adapters now exist and are all published.
Win32 has no eBasic binding at all yet, so that adapter remains
unstarted.

**Widgets and layout (Round 1)**: `GuiButton`/`GuiLabel`/`GuiEntry` +
`GuiBox`/`GuiGrid`, the lowest-common-denominator already real on all
three backends (create, append/attach-with-span, whole-layout
spacing) - the one piece of the user's original request left after the
three adapters existed. **Deliberately no expand/fill/weight/alignment/
min-max constraints yet** - real investigation (not assumed) found
`eb-haiku` already has a rich per-view constraint model
(`HViewSetExplicitMinSize`/`MaxSize`/`PreferredSize`/`Alignment`, plus
per-item/per-column/per-row weight), but GTK4 and Qt6 have **no
binding for any of this at all** (`hexpand`/`vexpand`/`halign`/`valign`
don't exist in `eb-gtk4`'s raw layer; `eb-qt6` has no stretch factor,
alignment-in-layout, or `QSizePolicy` binding) - a "constraints"
contract today would silently do nothing on two of three backends, so
that's a separate, later round needing real prerequisite native work
in both. CheckBox/RadioButton/ComboBox are a similar three-way gap
(rich on Qt6, absent on GTK4 and Haiku) deferred the same way.

## Why this package is just plain-data `TYPE`s, no polymorphism

**Correction (this README originally claimed eBasic has no virtual
methods at all - wrong, found via a case-sensitive grep that missed the
real `Virtual`/`Override` keywords; eBasic genuinely supports virtual
dispatch through a vtable, `docs/reference/type-oop.md`'s own `EXTENDS`
section).** The real, confirmed reason a polymorphic interface still
isn't viable here: a `TYPE` using a virtual method has a vtable, which
breaks the plain-data/standard-layout requirement for crossing an
`Extern`/`ebc --lib` package boundary - `ebc`'s own `Sema` explicitly
*rejects* a `UserDefined` TYPE with a constructor, destructor, or
virtual method used as a parameter/return type on such a boundary
(confirmed in the compiler's own M4-era implementation notes). Since
`eb-gui`, `eb-gui-gtk4`, `eb-gui-qt6`, and `eb-gui-haiku` are all
separately-compiled `--lib` archives, a virtual-dispatch-based shared
interface could never
span them regardless of the language supporting virtual dispatch
in general. Combined with each toolkit's native library being a
separate runtime dependency you'd never want to link all of into one
binary anyway, a truly universal API still can't do runtime
backend-swapping the way wxWidgets or SDL do - the backend has to be a
compile-time/package-time choice either way.

The chosen shape: this package defines the shared `GuiApplication`/
`GuiWindow` `TYPE`s (real, compiler-checked, identical across every
adapter); a separate adapter package per toolkit (`eb-gui-gtk4`,
`eb-gui-qt6`, ...) implements the function surface below, translating
each call into that backend's real calls. A consuming application
depends on `eb-gui` + exactly one adapter; switching backend means
changing one dependency line, not touching application code.

**What ISN'T compiler-enforced**: an ordinary (non-`Extern`) top-level
`FUNCTION`/`SUB` can't be forward-declared without a body in the same
compilation, so this package has no way to declare "every adapter must
implement a function named `GuiWindowShow` with this exact signature" as
checked code - only the two `TYPE`s above are real, shared declarations.
The function contract below is a documented **convention**, verified by
each adapter's own tests and by a cross-backend smoke test (literally
the same consumer `.bas` source compiled once per adapter dependency),
not by the type system. This is the honest tradeoff of a "universal" API
on a language with static, non-polymorphic `TYPE`s.

## The contract

```basic
TYPE GuiApplication
    handle AS ANY PTR
END TYPE

TYPE GuiWindow
    handle AS ANY PTR
END TYPE

FUNCTION NewGuiApplication(appId AS ZSTRING) AS GuiApplication
FUNCTION GuiApplicationRun(app AS GuiApplication) AS INTEGER
SUB GuiApplicationQuit(app AS GuiApplication)

' Always created via the app - mirrors GtkApplicationWindow, gives every
' backend a natural place to track its own open-window count.
FUNCTION NewGuiWindow(app AS GuiApplication, title AS ZSTRING, width AS INTEGER, height AS INTEGER) AS GuiWindow

SUB GuiWindowSetTitle(win AS GuiWindow, title AS ZSTRING)
SUB GuiWindowShow(win AS GuiWindow)
SUB GuiWindowHide(win AS GuiWindow)
SUB GuiWindowSetEnabled(win AS GuiWindow, enabled AS INTEGER)
FUNCTION GuiWindowIsEnabled(win AS GuiWindow) AS INTEGER

' Best-effort: GTK4 cannot move a window at all (upstream removed
' programmatic window positioning - Wayland/CSD make it largely
' meaningless). Check GuiWindowCanMove() before relying on GuiWindowMove
' actually doing anything.
FUNCTION GuiWindowCanMove() AS INTEGER
SUB GuiWindowMove(win AS GuiWindow, x AS INTEGER, y AS INTEGER)
SUB GuiWindowResize(win AS GuiWindow, width AS INTEGER, height AS INTEGER)

' Modal always takes its parent explicitly - matches the "needs a parent
' to be modal" precondition both GTK4 and Qt6 actually have.
SUB GuiWindowSetModal(win AS GuiWindow, parent AS GuiWindow)
SUB GuiWindowClearModal(win AS GuiWindow)

' Vetoable close - handler is `FUNCTION(userData AS ANY PTR) AS INTEGER`,
' nonzero = allow the close (matches eb-haiku's own BWindow::
' QuitRequested polarity).
'
' CONFIRMED real cross-backend asymmetry (found building eb-gui-qt6,
' not assumed): on Qt6, GuiApplicationQuit implicitly tries to close
' every currently-*shown* window first - a permanently-vetoing callback
' on a shown window silently blocks GuiApplicationQuit too, not just a
' real user close. On GTK4, GuiApplicationQuit always stops
' unconditionally regardless of any window's close callback. Avoid a
' shown window whose callback can veto forever if the application also
' needs GuiApplicationQuit to reliably work.
SUB GuiWindowSetCloseCallback(win AS GuiWindow, handler AS ANY PTR, userData AS ANY PTR)

' Only for a window never Run/shown - see "Ownership" below.
SUB GuiWindowDestroy(win AS GuiWindow)

TYPE GuiStatusBar
    handle AS ANY PTR
END TYPE

' Auto-created per window (matches both toolkits' own "window owns its
' status bar" convention - real GtkStatusbar/QStatusBar are each
' created once per window and reused) - there is no NewGuiStatusBar.
FUNCTION GuiWindowStatusBar(win AS GuiWindow) AS GuiStatusBar
SUB GuiStatusBarShowMessage(sb AS GuiStatusBar, text AS ZSTRING)
SUB GuiStatusBarClear(sb AS GuiStatusBar)

TYPE GuiTimer
    handle AS ANY PTR
END TYPE

' `parent` is required for Qt6's own object-lifetime management (a
' QTimer must be parented or it leaks) - the GTK4 adapter accepts and
' ignores it, since its own timer isn't a GObject at all and has no
' parent concept.
FUNCTION NewGuiTimer(parent AS GuiWindow) AS GuiTimer
SUB GuiTimerSetInterval(t AS GuiTimer, milliseconds AS INTEGER)
' If set, the timer fires once, then stops.
SUB GuiTimerSetSingleShot(t AS GuiTimer, singleShot AS INTEGER)
' handler is `SUB(userData AS ANY PTR)` - no return value (unlike a
' close callback, nothing to veto).
SUB GuiTimerConnectTimeout(t AS GuiTimer, handler AS ANY PTR, userData AS ANY PTR)
SUB GuiTimerStart(t AS GuiTimer)
SUB GuiTimerStop(t AS GuiTimer)
FUNCTION GuiTimerIsActive(t AS GuiTimer) AS INTEGER
' Meaningful on GTK4 (frees its own plain heap allocation); a documented
' no-op on Qt6 (Qt itself destroys a QTimer when its parent window is
' destroyed - eb-qt6's own timer.bas has no manual destroy at all).
SUB GuiTimerDestroy(t AS GuiTimer)

TYPE GuiMenuBar
    handle AS ANY PTR
END TYPE

TYPE GuiMenu
    handle AS ANY PTR
END TYPE

TYPE GuiToolBar
    handle AS ANY PTR
END TYPE

TYPE GuiAction
    handle AS ANY PTR
END TYPE

' Auto-created per window (matches both toolkits' own "window owns its
' menu bar" convention) - there is no NewGuiMenuBar.
FUNCTION GuiWindowMenuBar(win AS GuiWindow) AS GuiMenuBar
FUNCTION GuiMenuBarAddMenu(bar AS GuiMenuBar, title AS ZSTRING) AS GuiMenu
' Creates a new action labeled `text`, appended to `menu` - owned by the
' menu (no separate destroy function, matching GuiWindowDestroy's own
' "container now owns it" convention elsewhere in this contract). This
' is the lowest common shape both toolkits support without a hack: real
' GTK4 actions are shareable, window-scoped objects independent of any
' menu, but real Qt6's own binding (this contract's model) creates a
' fresh action per call - so an action can't be added to more than one
' menu/tool bar through this contract (a real capability difference,
' not an oversight - see eb-gui-gtk4's own README for how it fakes this
' shape on top of GTK4's richer, action-sharing native model).
FUNCTION GuiMenuAddAction(menu AS GuiMenu, text AS ZSTRING) AS GuiAction
' handler is `SUB(userData AS ANY PTR)` - no return value (unlike a
' close callback, nothing to veto).
SUB GuiActionConnectTriggered(a AS GuiAction, handler AS ANY PTR, userData AS ANY PTR)
SUB GuiActionSetEnabled(a AS GuiAction, enabled AS INTEGER)
FUNCTION GuiActionIsEnabled(a AS GuiAction) AS INTEGER
' Fires the action's own triggered/activate signal, the same path a
' real menu-item/toolbar-button click goes through - lets a connected
' GuiActionConnectTriggered handler be exercised/tested programmatically.
SUB GuiActionTrigger(a AS GuiAction)

' The window's own single tool bar, auto-created the first time this is
' called for a given window (there is no NewGuiToolBar, and no support
' for more than one tool bar per window through this contract - real
' GTK4 has no independent multi-tool-bar concept the way Qt6 does, so
' "exactly one, shared" is the lowest common shape).
FUNCTION GuiWindowToolBar(win AS GuiWindow) AS GuiToolBar
FUNCTION GuiToolBarAddAction(bar AS GuiToolBar, text AS ZSTRING) AS GuiAction

TYPE GuiButton
    handle AS ANY PTR
END TYPE

TYPE GuiLabel
    handle AS ANY PTR
END TYPE

TYPE GuiEntry
    handle AS ANY PTR
END TYPE

TYPE GuiBox
    handle AS ANY PTR
END TYPE

TYPE GuiGrid
    handle AS ANY PTR
END TYPE

FUNCTION NewGuiButton(text AS ZSTRING) AS GuiButton
SUB GuiButtonSetText(b AS GuiButton, text AS ZSTRING)
FUNCTION GuiButtonGetText(b AS GuiButton) AS ZSTRING
' handler is SUB(userData AS ANY PTR).
SUB GuiButtonConnectClicked(b AS GuiButton, handler AS ANY PTR, userData AS ANY PTR)

FUNCTION NewGuiLabel(text AS ZSTRING) AS GuiLabel
SUB GuiLabelSetText(l AS GuiLabel, text AS ZSTRING)

FUNCTION NewGuiEntry(text AS ZSTRING) AS GuiEntry
SUB GuiEntrySetText(e AS GuiEntry, text AS ZSTRING)
FUNCTION GuiEntryGetText(e AS GuiEntry) AS ZSTRING
' handler is SUB(userData AS ANY PTR) - no text param passed (real
' per-keystroke "changed" signals disagree too much across backends on
' whether one exists at all/what it carries - call GuiEntryGetText
' yourself from inside the handler instead).
SUB GuiEntryConnectChanged(e AS GuiEntry, handler AS ANY PTR, userData AS ANY PTR)

' orientation: 0 = horizontal, 1 = vertical.
FUNCTION NewGuiBox(orientation AS INTEGER, spacing AS INTEGER) AS GuiBox
' `child` is any other Gui* TYPE's own `.handle` (GuiButton/Label/Entry/
' Box/Grid all interoperate as children of a GuiBox/GuiGrid).
SUB GuiBoxAddChild(box AS GuiBox, child AS ANY PTR)

FUNCTION NewGuiGrid() AS GuiGrid
SUB GuiGridAttach(grid AS GuiGrid, child AS ANY PTR, column AS INTEGER, row AS INTEGER, columnSpan AS INTEGER, rowSpan AS INTEGER)

' The window's own main content area - composes with StatusBar/MenuBar/
' ToolBar, which already claim their own chrome regions (see each
' adapter's own README for the exact interop mechanism and any
' call-order convention it needs).
SUB GuiWindowSetContent(win AS GuiWindow, content AS ANY PTR)

' --- Round 2: per-child constraints ---
CONST GUI_ALIGN_FILL AS INTEGER = 0
CONST GUI_ALIGN_START AS INTEGER = 1
CONST GUI_ALIGN_CENTER AS INTEGER = 2
CONST GUI_ALIGN_END AS INTEGER = 3

' expand: relative growth weight along the box's own main axis
' (0 = fixed size; >0 = grow). Only the ZERO/NONZERO distinction is
' guaranteed everywhere - the MAGNITUDE is a real proportional ratio on
' eb-gui-qt6/eb-gui-haiku but is otherwise ignored by eb-gui-gtk4
' (GTK4 has no fractional-ratio expand, boolean only).
' halign/valign: GUI_ALIGN_* - alignment within the child's own
' allocated cell/slot on the axis(es) it isn't expanding to fill.
SUB GuiBoxAddChildEx(box AS GuiBox, child AS ANY PTR, expand AS SINGLE, halign AS INTEGER, valign AS INTEGER)
SUB GuiGridAttachEx(grid AS GuiGrid, child AS ANY PTR, column AS INTEGER, row AS INTEGER, columnSpan AS INTEGER, rowSpan AS INTEGER, halign AS INTEGER, valign AS INTEGER)

' Per-column/row relative growth weight, independent of which
' widget(s) occupy that column/row. Real on eb-gui-qt6/eb-gui-haiku; a
' documented, accepted no-op on eb-gui-gtk4 (GtkGrid has no such
' concept at all - a real absence in GTK4 itself, not a binding gap).
SUB GuiGridSetColumnWeight(grid AS GuiGrid, column AS INTEGER, weight AS SINGLE)
SUB GuiGridSetRowWeight(grid AS GuiGrid, row AS INTEGER, weight AS SINGLE)

' --- Round 3: explicit min/max size ---
' `handle` is any other Gui* TYPE's own `.handle` (same convention as
' GuiBoxAddChild's own `child` param). width/height: pass -1 (or
' whatever sentinel the underlying toolkit uses for "unset") to clear a
' previously-set constraint where that's meaningful - passed straight
' through, not reinterpreted by this contract.
SUB GuiWidgetSetMinSize(handle AS ANY PTR, width AS INTEGER, height AS INTEGER)

' A documented, accepted no-op on eb-gui-gtk4 - real GTK4 has no
' generic per-widget maximum-size concept at all (confirmed absent
' upstream, not a binding gap).
SUB GuiWidgetSetMaxSize(handle AS ANY PTR, width AS INTEGER, height AS INTEGER)
```

## Widgets and layout (Round 1) - Button/Label/Entry, Box/Grid

`GuiBox`/`GuiGrid` shipped first with only what was ALREADY real on all
three backends: create, append/attach-with-span, whole-layout spacing.
Real investigation (not assumed) found `eb-haiku` already had a rich
per-view constraint model at the time
(`HViewSetExplicitMinSize`/`MaxSize`/`PreferredSize`/`Alignment`, plus
per-item/per-column/per-row weight) - but GTK4's raw layer had no
`hexpand`/`vexpand`/`halign`/`valign` binding at all, and `eb-qt6` had
no stretch factor, alignment-in-layout, or per-column/row stretch
binding either. Round 2 (below) closed that gap.

**Hiding a real nesting asymmetry in each adapter, not the contract**:
GTK4's `Box`/`Grid` are real widgets and nest directly into each
other. Qt6's `BoxLayout`/`GridLayout` and Haiku's `HGroupLayout`/
`HGridLayout` are NOT widgets/views at all and need an intermediate
holder (a plain widget/view with the layout applied to it) before they
can be added as a child of another layout. `eb-gui-gtk4`'s
`GuiBox.handle`/`GuiGrid.handle` are the real widget handles directly;
`eb-gui-qt6`/`eb-gui-haiku` create the holder internally and return
its handle instead, tracking the real underlying layout object
separately - so from this contract's own perspective, a `GuiBox`/
`GuiGrid` is always "a thing you can hand to `GuiBoxAddChild`/
`GuiGridAttach`/`GuiWindowSetContent` uniformly," regardless of
backend.

CheckBox/RadioButton/ComboBox are a similar three-way asymmetry (rich
on Qt6, entirely absent - both raw and idiomatic layers - on GTK4 and
Haiku) and are deferred to their own later round for the same reason.

## Widgets and layout (Round 2) - per-child constraints

`GuiBoxAddChildEx`/`GuiGridAttachEx`/`GuiGridSetColumnWeight`/
`SetRowWeight` add expand/weight + alignment, after real prerequisite
native work landed in `eb-gtk4` (`WidgetSetHExpand`/`VExpand`/`HAlign`/
`VAlign`, plain raw FFI - GTK4 puts expand/alignment on the CHILD
widget, not the container) and `eb-qt6` (`BoxLayoutAddWidgetEx`/
`SetStretchFactor`, `GridLayoutAddWidgetEx`/`SetRowStretch`/
`SetColumnStretch` - new native shim functions calling straight through
to real, already-existing Qt overloads). `eb-haiku` needed none - its
model (`HGroupLayoutSetItemWeight`, `HGridLayoutSetColumnWeight`/
`SetRowWeight`, `HViewSetExplicitAlignment`) anchored the contract
shape from the start, exactly as anticipated in Round 1.

The existing non-`Ex` `GuiBoxAddChild`/`GuiGridAttach` are unchanged
(implicit no-constraint behavior) - this is a purely additive contract
change, no existing caller needs to change.

Grid weight is the one real, non-adapter-bug asymmetry: `GtkGrid` has
no per-column/row weight concept at all in real GTK4 (not a binding
gap - it simply doesn't exist upstream), so `eb-gui-gtk4`'s
`GuiGridSetColumnWeight`/`SetRowWeight` are a documented, accepted
no-op, matching the Round 1 Action model's own "document the loss,
don't block the feature" precedent.

## Widgets and layout (Round 3) - explicit min/max size

`GuiWidgetSetMinSize`/`SetMaxSize` needed **zero prerequisite native
work** - unlike Rounds 1-2, every backing function this round needs
already existed in `eb-gtk4`/`eb-qt6`/`eb-haiku` (`WidgetSetSizeRequest`/
`WidgetSetMinimumSize`/`HViewSetExplicitMinSize` for min size;
`WidgetSetMaximumSize`/`HViewSetExplicitMaxSize` for max size) - this
round is pure contract + adapter wiring.

`GuiWidgetSetMaxSize` is a documented, accepted no-op on `eb-gui-gtk4`:
real GTK4 has no generic per-widget maximum-size API at all (confirmed
via this project's own header inspection, not assumed) - only
individual widget classes like `GtkLabel` have unrelated, narrower
`max-width-chars`-style properties, nothing at the `GtkWidget` base
level any widget could rely on uniformly.

**Deliberately NOT included**: a settable "preferred size." Real
Haiku's `HViewSetExplicitPreferredSize` genuinely overrides what its
layout treats as preferred - but GTK4's `gtk_widget_measure`/`Qt6`'s
`sizeHint()` are both **read-only queries** computed per-widget-type,
not settable properties on the generic widget base. Approximating
"preferred size" on those two backends via `SetMinSize`+`SetMaxSize`
to the same value would silently change the semantics from "prefer
this, but still allow flex within other constraints" to "force exactly
this size" - a real, meaningful behavior difference, not a cosmetic
one, so it's left out rather than shipped as a misleading
approximation.

## Ownership and the quit model

The application owns every window it created; `GuiApplicationRun`
returns once `GuiApplicationQuit` is called **or** the last open window
closes (matches GTK4's native `GApplication` behavior exactly - and,
via `gtk_application_window_new`'s own window tracking, `eb-gui-gtk4`
gets this for free). Qt6's own `QApplication` doesn't auto-quit on
last-window-close the same way, so `eb-gui-qt6` maintains its own
live-window count internally and calls `ApplicationQuit` when it reaches
zero - an adapter implementation detail, invisible to application code
either way.

## Using as a dependency

An application depends on exactly one adapter - not this package
directly (the adapter's own `.iface.bas` already carries a full copy of
`GuiApplication`/`GuiWindow`, since it `#include`s this package's own
interface internally; `#include`ing both would redeclare each `TYPE`):

```toml
[dependencies]
gui-gtk4 = { git = "https://github.com/yann64/eb-gui-gtk4.git" }
```

```basic
#include "gui-gtk4.iface.bas"

DIM app AS GuiApplication
app = NewGuiApplication("io.github.you.yourapp")

DIM win AS GuiWindow
win = NewGuiWindow(app, "Hello", 320, 240)
CALL GuiWindowShow(win)

CALL GuiApplicationRun(app)
```

Switching to Qt6 means depending on `eb-gui-qt6` instead of
`eb-gui-gtk4` and changing the one `#include` line above - the rest of
the application is unchanged.

## See also

- [`eb-gui-gtk4`](https://github.com/yann64/eb-gui-gtk4) - the GTK4 adapter.
- [`eb-gui-qt6`](https://github.com/yann64/eb-gui-qt6) - the Qt6 adapter.
- [`eb-gui-haiku`](https://github.com/yann64/eb-gui-haiku) - the native Haiku BeAPI adapter.
- [`eb-gtk4`](https://github.com/yann64/eb-gtk4) / [`eb-qt6`](https://github.com/yann64/eb-qt6) /
  [`eb-haiku`](https://github.com/yann64/eb-haiku) - the underlying toolkit bindings each adapter is built on.
