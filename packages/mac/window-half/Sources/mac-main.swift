import AppKit
import ApplicationServices
import Foundation

struct WindowHalfError: LocalizedError {
    let errorDescription: String?

    /// Preserve a command failure message for stderr output.
    ///
    /// @example
    /// let error = WindowHalfError("No displays are available.")
    /// error.localizedDescription // "No displays are available."
    init(_ message: String) {
        errorDescription = message
    }
}

struct ScreenSnapshot {
    let name: String
    let geometry: DisplayGeometry
}

/// Read current display names, full bounds, usable bounds, and backing scales.
/// Converts AppKit frames to Accessibility coordinates in logical points.
/// Initializes AppKit so secondary menu bars are included; throws if no screens exist.
/// Does not require Accessibility access or move windows.
///
/// @see [NSScreen.visibleFrame](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe)
///
/// @example
/// let screens = try screenSnapshots()
/// screens.map(\.name) // Current display names, with the primary display first.
func screenSnapshots() throws -> [ScreenSnapshot] {
    _ = NSApplication.shared
    let screens = NSScreen.screens
    guard let primary = screens.first else {
        throw WindowHalfError("No displays are available.")
    }

    return screens.map { screen in
        ScreenSnapshot(
            name: screen.localizedName,
            geometry: DisplayGeometry(
                frame: accessibilityRect(appKitRect: screen.frame, primaryTop: primary.frame.maxY),
                visibleFrame: accessibilityRect(
                    appKitRect: screen.visibleFrame,
                    primaryTop: primary.frame.maxY
                ),
                scale: screen.backingScaleFactor
            )
        )
    }
}

/// Read a required Accessibility attribute from an application or window.
/// Throws if the attribute is unavailable or the Accessibility request fails.
/// Does not validate the returned type; the caller must check it before casting.
///
/// @see [AXUIElementCopyAttributeValue](https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue)
///
/// @example
/// let window = try focusedWindow()
/// let subrole = try attribute(element: window, name: kAXSubroleAttribute)
/// subrole as? String // "AXStandardWindow"
func attribute(element: AXUIElement, name: String) throws -> CFTypeRef {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
    guard result == .success, let value else {
        throw WindowHalfError(
            "Cannot read \(name) from the focused window (Accessibility error \(result.rawValue))."
        )
    }
    return value
}

/// Read the frontmost application's focused standard window without changing focus.
/// Requires existing Accessibility access; does not request permission.
/// Throws for missing access, missing windows, nonstandard windows, or full screen.
/// An unreadable AXFullScreen attribute is treated as no reported full-screen state.
///
/// @example
/// let window = try focusedWindow()
/// let bounds = try windowBounds(window: window)
/// // The focused window's current bounds; no window has moved.
func focusedWindow() throws -> AXUIElement {
    guard AXIsProcessTrusted() else {
        throw WindowHalfError(
            "Grant the app running this command access in System Settings > Privacy & Security > Accessibility."
        )
    }

    guard
        let app = NSWorkspace.shared.frontmostApplication,
        app.activationPolicy == .regular
    else {
        throw WindowHalfError("Focus a normal application window before running this command.")
    }

    let application = AXUIElementCreateApplication(app.processIdentifier)
    let value = try attribute(element: application, name: kAXFocusedWindowAttribute)
    guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
        throw WindowHalfError("The focused application has no accessible window.")
    }

    let window = value as! AXUIElement
    let subrole = try attribute(element: window, name: kAXSubroleAttribute)
    guard subrole as? String == kAXStandardWindowSubrole else {
        throw WindowHalfError("The focused window is not a standard application window.")
    }

    var fullScreenValue: CFTypeRef?
    let fullScreenResult = AXUIElementCopyAttributeValue(
        window,
        "AXFullScreen" as CFString,
        &fullScreenValue
    )
    let isFullScreen = (fullScreenValue as? NSNumber)?.boolValue == true
    if fullScreenResult == .success, isFullScreen {
        throw WindowHalfError("Leave full screen before running this command.")
    }

    return window
}

/// Read a window's position and size in Accessibility coordinates and logical points.
/// Throws for unreadable attributes, incorrect value types, or unusable rectangles.
/// Does not require the rectangle to overlap a display.
///
/// @example
/// let window = try focusedWindow()
/// let bounds = try windowBounds(window: window)
/// isUsableRect(bounds) // true
func windowBounds(window: AXUIElement) throws -> CGRect {
    let position = try attribute(element: window, name: kAXPositionAttribute)
    let size = try attribute(element: window, name: kAXSizeAttribute)
    guard
        CFGetTypeID(position) == AXValueGetTypeID(),
        CFGetTypeID(size) == AXValueGetTypeID()
    else {
        throw WindowHalfError("The focused window returned invalid bounds.")
    }

    var point = CGPoint.zero
    var dimensions = CGSize.zero
    guard
        AXValueGetValue(position as! AXValue, .cgPoint, &point),
        AXValueGetValue(size as! AXValue, .cgSize, &dimensions)
    else {
        throw WindowHalfError("The focused window returned invalid position or size.")
    }

    let bounds = CGRect(origin: point, size: dimensions)
    guard isUsableRect(bounds) else {
        throw WindowHalfError("The focused window has invalid bounds.")
    }

    return bounds
}

/// Check that a window permits both position and size changes before any writes.
/// Throws if either check fails; does not guarantee that an app will accept every size.
///
/// @example
/// let window = try focusedWindow()
/// try requireWritableBounds(window: window)
/// // Both attributes are writable; the window has not moved or resized.
func requireWritableBounds(window: AXUIElement) throws {
    for name in [kAXPositionAttribute, kAXSizeAttribute] {
        var writable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(window, name as CFString, &writable)
        guard result == .success, writable.boolValue else {
            throw WindowHalfError("The focused window does not allow changing \(name).")
        }
    }
}

/// Write one encoded position or size value to a window's Accessibility attribute.
/// The caller must match the AXValue type to the attribute and check writability.
/// Throws for missing encoded values or failed writes; does not retry or verify placement.
///
/// @example
/// let window = try focusedWindow()
/// try requireWritableBounds(window: window)
/// var position = CGPoint(x: 8, y: 38)
/// try setBoundsAttribute(
///     window: window,
///     name: kAXPositionAttribute,
///     value: AXValueCreate(.cgPoint, &position)
/// )
func setBoundsAttribute(window: AXUIElement, name: String, value: AXValue?) throws {
    guard let value else {
        throw WindowHalfError("Cannot encode the requested window bounds.")
    }

    let result = AXUIElementSetAttributeValue(window, name as CFString, value)
    guard result == .success else {
        throw WindowHalfError("Cannot change \(name) (Accessibility error \(result.rawValue)).")
    }
}

/// Resize and move one window, then verify its bounds within one logical point.
/// The caller supplies usable bounds, normally from halfBounds.
/// Throws for unwritable attributes, failed writes, or app-imposed size constraints.
/// Does not restore the old bounds if a later write or verification fails.
///
/// @example
/// let window = try focusedWindow()
/// let target = CGRect(x: 8, y: 38, width: 1904, height: 1038)
/// try applyBounds(window: window, bounds: target)
func applyBounds(window: AXUIElement, bounds: CGRect) throws {
    try requireWritableBounds(window: window)
    var size = bounds.size
    var point = bounds.origin

    // Resize at the current position.
    try setBoundsAttribute(
        window: window,
        name: kAXSizeAttribute,
        value: AXValueCreate(.cgSize, &size)
    )

    // Move to the target position.
    try setBoundsAttribute(
        window: window,
        name: kAXPositionAttribute,
        value: AXValueCreate(.cgPoint, &point)
    )

    // Reapply the size in case the old position constrained it.
    try setBoundsAttribute(
        window: window,
        name: kAXSizeAttribute,
        value: AXValueCreate(.cgSize, &size)
    )

    let actual = try windowBounds(window: window)
    let tolerance: CGFloat = 1
    guard
        abs(actual.minX - bounds.minX) <= tolerance,
        abs(actual.minY - bounds.minY) <= tolerance,
        abs(actual.width - bounds.width) <= tolerance,
        abs(actual.height - bounds.height) <= tolerance
    else {
        throw WindowHalfError(
            "The app constrained the requested window bounds; its minimum size may exceed this half."
        )
    }
}

/// Print the requested half's target bounds for each supplied display.
/// Does not access Accessibility or change windows; throws for unusable halves.
/// Lines printed before an unusable display remain on stdout when a later display fails.
///
/// @example
/// let screens = try screenSnapshots()
/// try printDryRun(half: .top, screens: screens)
/// // One line per display: "<name>: top x=... y=... width=... height=..."
func printDryRun(half: WindowHalf, screens: [ScreenSnapshot]) throws {
    for screen in screens {
        guard let bounds = halfBounds(half: half, display: screen.geometry) else {
            throw WindowHalfError("No usable \(half.rawValue) half on \(screen.name).")
        }

        print(
            "\(screen.name):",
            half.rawValue,
            "x=\(bounds.minX)",
            "y=\(bounds.minY)",
            "width=\(bounds.width)",
            "height=\(bounds.height)"
        )
    }
}

/// Place the focused window in one half of the display containing most of it.
/// Accepts only top|bottom followed by an optional --dry-run flag.
/// Dry runs print all displays without Accessibility access; placement requires it.
/// Throws invalid arguments and any display or window-operation errors to the caller.
///
/// @example
/// try runWindowHalf(arguments: ["top", "--dry-run"]) // Print targets without moving windows.
/// try runWindowHalf(arguments: ["bottom"]) // Place the focused window in its bottom half.
func runWindowHalf(arguments: [String]) throws {
    let dryRunFlag = "--dry-run"
    let hasValidOptions =
        arguments.count == 1 || (arguments.count == 2 && arguments.last == dryRunFlag)

    guard
        hasValidOptions,
        let halfArgument = arguments.first,
        let half = WindowHalf(rawValue: halfArgument)
    else {
        throw WindowHalfError("Usage: mac-window-half top|bottom [--dry-run]")
    }

    let screens = try screenSnapshots()
    if arguments.last == dryRunFlag {
        try printDryRun(half: half, screens: screens)
        return
    }

    let window = try focusedWindow()
    let current = try windowBounds(window: window)
    guard let index = displayIndex(window: current, displays: screens.map(\.geometry)) else {
        throw WindowHalfError("The focused window is not on an available display.")
    }

    guard let target = halfBounds(half: half, display: screens[index].geometry) else {
        throw WindowHalfError("The display has no usable \(half.rawValue) half.")
    }

    try applyBounds(window: window, bounds: target)
}

@main
struct MacWindowHalf {
    /// Run the command using process arguments and report failures to stderr.
    /// Exits with status 1 on failure; successful commands return normally.
    ///
    /// @example
    /// // From the repository root:
    /// // bash packages/mac/mac-window-top-half.sh --dry-run
    static func main() {
        do {
            try runWindowHalf(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
