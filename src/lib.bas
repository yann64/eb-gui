' eb-gui: the shared contract for eBasic's universal, cross-toolkit GUI
' API. This package defines ONLY the two TYPE shapes every backend
' adapter (eb-gui-gtk4, eb-gui-qt6, and eventually eb-gui-haiku/
' eb-gui-win32) must use identically - it has no native dependency of
' its own and implements nothing.
'
' WHY THIS IS SO SMALL, AND WHAT ISN'T ENFORCED BY THE COMPILER:
' eBasic DOES support real virtual dispatch (Declare Virtual Function/
' Override, a real vtable - see docs/reference/type-oop.md's EXTENDS
' section), but a TYPE using one can't cross an Extern/ebc --lib package
' boundary at all (Sema rejects it - a vtable breaks the plain-data/
' standard-layout requirement that boundary needs), and this package,
' eb-gui-gtk4, and eb-gui-qt6 are three separately-compiled --lib
' archives. Separately, an ordinary (non-Extern) top-level FUNCTION/SUB
' can't be forward-declared without a body in the same compilation the
' way an Extern declaration can. So there is no compiler-checked way
' for this package to declare "every adapter must implement a function
' named GuiWindowShow with this exact signature" - only the TYPE shapes
' below are real, shared, compiler-checked data. The function surface
' each adapter must implement (listed in full in this package's README)
' is a documented CONVENTION, not an enforced interface - verified in
' practice by a cross-backend smoke test (the same consumer .bas source
' compiled once per adapter dependency) rather than by the type system.
' This is the honest tradeoff of building a "universal" API that spans
' multiple separately-compiled packages, with no runtime backend-
' swapping either (each toolkit is a separate native library you'd
' never want to link all of into one binary anyway).
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

TYPE GuiStatusBar
    handle AS ANY PTR
END TYPE

TYPE GuiTimer
    handle AS ANY PTR
END TYPE

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

''' Alignment of a child within its allocated cell/slot on an axis it
''' isn't expanding to fill. Each adapter maps these to its own
''' toolkit's real enum internally (GTK_ALIGN_*/Qt::AlignmentFlag/
''' H_ALIGN_*) - kept toolkit-neutral here, same convention as GuiBox's
''' own 0=horizontal/1=vertical orientation parameter.
CONST GUI_ALIGN_FILL AS INTEGER = 0
CONST GUI_ALIGN_START AS INTEGER = 1
CONST GUI_ALIGN_CENTER AS INTEGER = 2
CONST GUI_ALIGN_END AS INTEGER = 3

TYPE GuiCheckBox
    handle AS ANY PTR
END TYPE

TYPE GuiRadioButton
    handle AS ANY PTR
END TYPE

TYPE GuiComboBox
    handle AS ANY PTR
END TYPE

TYPE GuiProgressBar
    handle AS ANY PTR
END TYPE

TYPE GuiSlider
    handle AS ANY PTR
END TYPE

TYPE GuiListBox
    handle AS ANY PTR
END TYPE

TYPE GuiTextView
    handle AS ANY PTR
END TYPE
