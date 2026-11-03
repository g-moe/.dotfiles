import CoreGraphics
import Foundation

/// Evaluate an assertion and terminate the test process on failure.
/// Writes the failure message to stderr and exits with status 1; does not throw.
///
/// @example
/// expect(isUsableRect(.zero) == false, "empty rectangles must be rejected")
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func testStackedDisplayWithMenuBar() {
    let display = DisplayGeometry(
        frame: CGRect(x: 1728, y: 294, width: 1920, height: 2160),
        visibleFrame: CGRect(x: 1728, y: 324, width: 1920, height: 2130),
        scale: 2
    )
    let top = halfBounds(half: .top, display: display)
    let bottom = halfBounds(half: .bottom, display: display)

    expect(
        top == CGRect(x: 1736, y: 332, width: 1904, height: 1038),
        "top window stays above the physical seam despite the 30-point menu bar"
    )
    expect(
        bottom == CGRect(x: 1736, y: 1378, width: 1904, height: 1068),
        "bottom window starts four points below the physical seam, not the usable midpoint"
    )
}

func testMenuBarAndDockDoNotMoveTheSeam() {
    let frame = CGRect(x: -1920, y: -2160, width: 1920, height: 2160)
    let display = DisplayGeometry(
        frame: frame,
        visibleFrame: CGRect(x: -1850, y: -2130, width: 1850, height: 2080),
        scale: 2
    )
    let top = halfBounds(half: .top, display: display)
    let bottom = halfBounds(half: .bottom, display: display)

    expect(
        top == CGRect(x: -1842, y: -2122, width: 1834, height: 1038),
        "negative display coordinates preserve top and side exclusions"
    )
    expect(
        bottom == CGRect(x: -1842, y: -1076, width: 1834, height: 1018),
        "bottom Dock exclusion changes height without shifting the seam"
    )
}

func testHiddenMenuBarAndOddPixelHeight() {
    let frame = CGRect(x: 0, y: 0, width: 1000, height: 1001)
    let display = DisplayGeometry(frame: frame, visibleFrame: frame, scale: 1)
    let top = halfBounds(half: .top, display: display)
    let bottom = halfBounds(half: .bottom, display: display)

    expect(
        top == CGRect(x: 8, y: 8, width: 984, height: 488),
        "an odd physical height rounds the seam to a physical pixel"
    )
    expect(
        bottom == CGRect(x: 8, y: 504, width: 984, height: 489),
        "bottom half receives the remaining physical pixel"
    )

    let retina = DisplayGeometry(frame: frame, visibleFrame: frame, scale: 2)
    expect(
        halfBounds(half: .top, display: retina)?.maxY == 496.5,
        "Retina seam retains half-point precision"
    )
    expect(halfBounds(half: .bottom, display: retina)?.minY == 504.5, "Retina gap stays centered")
}

func testAppKitCoordinateConversion() {
    let externalFrame = CGRect(x: 1728, y: -1337, width: 1920, height: 2160)
    let abovePrimaryFrame = CGRect(x: 0, y: 1117, width: 1000, height: 1000)
    let externalBounds = accessibilityRect(appKitRect: externalFrame, primaryTop: 1117)
    let abovePrimaryBounds = accessibilityRect(appKitRect: abovePrimaryFrame, primaryTop: 1117)

    expect(
        externalBounds == CGRect(x: 1728, y: 294, width: 1920, height: 2160),
        "external display coordinates match Accessibility"
    )
    expect(
        abovePrimaryBounds == CGRect(x: 0, y: -1000, width: 1000, height: 1000),
        "displays above the primary retain negative Accessibility coordinates"
    )
}

func testDisplaySelection() {
    let left = CGRect(x: -1000, y: 0, width: 1000, height: 1000)
    let right = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    let displays = [left, right].map { DisplayGeometry(frame: $0, visibleFrame: $0, scale: 1) }
    let spanningWindow = CGRect(x: -100, y: 100, width: 500, height: 400)
    let leftWindow = CGRect(x: -900, y: 100, width: 400, height: 400)
    let offscreenWindow = CGRect(x: 2000, y: 100, width: 400, height: 400)

    expect(
        displayIndex(window: spanningWindow, displays: displays) == 1,
        "a spanning window uses the display containing most of it"
    )
    expect(
        displayIndex(window: leftWindow, displays: displays) == 0,
        "a window on the left display stays there"
    )
    expect(
        displayIndex(window: offscreenWindow, displays: displays) == nil,
        "offscreen windows do not silently select an unrelated display"
    )
}

func testInvalidGeometryIsRejected() {
    let frame = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    let display = DisplayGeometry(frame: frame, visibleFrame: frame, scale: 2)
    expect(halfBounds(half: .top, display: display, gap: -1) == nil, "negative gaps fail")
    expect(halfBounds(half: .top, display: display, gap: .nan) == nil, "nonfinite gaps fail")
    expect(
        halfBounds(half: .top, display: display, gap: 600) == nil,
        "gaps cannot consume the display"
    )

    let invalidScale = DisplayGeometry(frame: frame, visibleFrame: frame, scale: 0)
    expect(halfBounds(half: .top, display: invalidScale) == nil, "invalid display scales fail")

    let noTopSpace = DisplayGeometry(
        frame: frame,
        visibleFrame: CGRect(x: 0, y: 600, width: 1000, height: 400),
        scale: 2
    )
    expect(halfBounds(half: .top, display: noTopSpace) == nil, "empty usable halves fail")
    expect(displayIndex(window: .null, displays: [display]) == nil, "invalid window bounds fail")
}

@main
struct WindowHalfTests {
    static func main() {
        testStackedDisplayWithMenuBar()
        testMenuBarAndDockDoNotMoveTheSeam()
        testHiddenMenuBarAndOddPixelHeight()
        testAppKitCoordinateConversion()
        testDisplaySelection()
        testInvalidGeometryIsRejected()
        print("Window half geometry tests passed.")
    }
}
