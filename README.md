# eb-gui

The shared contract for [eBasic](https://github.com/yann64/ebasic)'s
universal, cross-toolkit `Application`/`Window` API, managed with `ebpm`.

## Status

Phase 1: `Application`/`Window` only. Two real backend adapters exist:
[`eb-gui-gtk4`](https://github.com/yann64/eb-gui-gtk4) and
[`eb-gui-qt6`](https://github.com/yann64/eb-gui-qt6). Haiku and Win32
adapters are a planned follow-on (Haiku needs real prerequisite work in
`eb-haiku` first - window move/resize/title aren't bound there yet
despite `BWindow` supporting all three natively; Win32 has no eBasic
binding at all yet). Menu, toolbar, statusbar, timer, and the
widget/layout-with-constraints system are a separate, later phase.

## Why this package is just two `TYPE`s

eBasic has no virtual methods or interfaces - a `TYPE` is a plain value
struct (see the compiler's own `docs/reference/type-oop.md`), and each
toolkit's native library is a separate runtime dependency you'd never
want to link all of into one binary anyway. So a truly universal API
can't do runtime backend-swapping the way wxWidgets or SDL do - the
backend has to be a compile-time/package-time choice.

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
SUB GuiWindowSetCloseCallback(win AS GuiWindow, handler AS ANY PTR, userData AS ANY PTR)

' Only for a window never Run/shown - see "Ownership" below.
SUB GuiWindowDestroy(win AS GuiWindow)
```

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
- [`eb-gtk4`](https://github.com/yann64/eb-gtk4) / [`eb-qt6`](https://github.com/yann64/eb-qt6) -
  the underlying toolkit bindings each adapter is built on.
