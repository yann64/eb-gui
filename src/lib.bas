' eb-gui: the shared contract for eBasic's universal, cross-toolkit GUI
' API. This package defines ONLY the two TYPE shapes every backend
' adapter (eb-gui-gtk4, eb-gui-qt6, and eventually eb-gui-haiku/
' eb-gui-win32) must use identically - it has no native dependency of
' its own and implements nothing.
'
' WHY THIS IS SO SMALL, AND WHAT ISN'T ENFORCED BY THE COMPILER:
' eBasic has no virtual methods/interfaces (a TYPE is a plain value
' struct - see docs/reference/type-oop.md in the eBasic compiler repo),
' and an ordinary (non-Extern) top-level FUNCTION/SUB can't be forward-
' declared without a body in the same compilation the way an Extern
' declaration can. So there is no compiler-checked way for this package
' to declare "every adapter must implement a function named
' GuiWindowShow with this exact signature" - only the TYPE shapes below
' are real, shared, compiler-checked data. The function surface each
' adapter must implement (listed in full in this package's README) is a
' documented CONVENTION, not an enforced interface - verified in
' practice by a cross-backend smoke test (the same consumer .bas source
' compiled once per adapter dependency) rather than by the type system.
' This is the honest tradeoff of building a "universal" API on a
' language with static, non-polymorphic TYPEs and no runtime backend-
' swapping (each toolkit is a separate native library anyway, so this
' isn't a loss compared to some achievable alternative).
'
' `handle` is deliberately a bare ANY PTR, not any specific backend's
' own handle TYPE - each adapter's implementation casts it to/from
' whatever its own underlying toolkit wrapper TYPE needs (e.g.
' eb-gui-gtk4 stores a GObj PTR here exactly as eb-gtk4's own Window
' TYPE does internally; eb-gui-qt6 stores a QWidget*/QMainWindow* here
' exactly as eb-qt6's own QtWidget TYPE does). A consuming application
' never reads `handle` directly - it's opaque, passed only to this
' contract's own functions (as implemented by whichever adapter the
' application depends on).

TYPE GuiApplication
    handle AS ANY PTR
END TYPE

TYPE GuiWindow
    handle AS ANY PTR
END TYPE
