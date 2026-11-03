import CoreGraphics
import Foundation

enum WindowHalf: String {
    case top
    case bottom
}

/// Display bounds in logical points, using Accessibility's downward Y axis.
struct DisplayGeometry {
    let frame: CGRect
    let visibleFrame: CGRect
    let scale: CGFloat
}

/// Convert an AppKit screen rectangle to Accessibility coordinates in logical points.
/// Does not validate bounds; primaryTop must be the primary screen's frame.maxY.
/// Displays above the primary screen retain negative Y coordinates.
///
/// @example
/// let frame = CGRect(x: 1728, y: -1337, width: 1920, height: 2160)
/// accessibilityRect(appKitRect: frame, primaryTop: 1117)
/// // CGRect(x: 1728, y: 294, width: 1920, height: 2160)
func accessibilityRect(appKitRect: CGRect, primaryTop: CGFloat) -> CGRect {
    CGRect(
        x: appKitRect.minX,
        y: primaryTop - appKitRect.maxY,
        width: appKitRect.width,
        height: appKitRect.height
    )
}

/// Check that a rectangle has finite coordinates and positive dimensions.
/// Returns false for null, infinite, and zero-area rectangles.
/// Does not check whether the rectangle overlaps a display.
///
/// @example
/// isUsableRect(CGRect(x: -100, y: 0, width: 500, height: 400)) // true
/// isUsableRect(.zero) // false
/// isUsableRect(.null) // false
func isUsableRect(_ rect: CGRect) -> Bool {
    guard
        !rect.isNull,
        !rect.isInfinite,
        rect.origin.x.isFinite,
        rect.origin.y.isFinite,
        rect.width.isFinite,
        rect.height.isFinite,
        rect.width > 0,
        rect.height > 0
    else {
        return false
    }

    return true
}

/// Find the display containing the largest area of a window.
/// Both inputs must use Accessibility coordinates in logical points.
/// Returns nil for invalid or offscreen windows; ties select the first display.
///
/// @example
/// let frame = CGRect(x: 0, y: 0, width: 1000, height: 1000)
/// let display = DisplayGeometry(frame: frame, visibleFrame: frame, scale: 1)
/// let window = CGRect(x: 800, y: 100, width: 400, height: 400)
/// displayIndex(window: window, displays: [display]) // 0
func displayIndex(window: CGRect, displays: [DisplayGeometry]) -> Int? {
    guard isUsableRect(window) else {
        return nil
    }

    var selectedIndex: Int?
    var largestArea: CGFloat = 0

    for (index, display) in displays.enumerated() {
        let overlap = window.intersection(display.frame)
        guard isUsableRect(overlap) else {
            continue
        }

        let area = overlap.width * overlap.height
        if area > largestArea {
            selectedIndex = index
            largestArea = area
        }
    }

    return selectedIndex
}

/// Fit a window into one physical display half while respecting menu bar and Dock space.
/// Uses logical points, with outer gaps and one shared gap centered on the full frame.
/// Rounds the midpoint down to a physical pixel; an odd pixel goes to the bottom half.
/// Returns nil for invalid geometry, invalid gaps, or a half with no remaining space.
///
/// @example
/// let display = DisplayGeometry(
///     frame: CGRect(x: 0, y: 0, width: 1920, height: 2160),
///     visibleFrame: CGRect(x: 0, y: 30, width: 1920, height: 2130),
///     scale: 2
/// )
/// halfBounds(half: .top, display: display)
/// // CGRect(x: 8, y: 38, width: 1904, height: 1038)
/// halfBounds(half: .bottom, display: display)
/// // CGRect(x: 8, y: 1084, width: 1904, height: 1068)
func halfBounds(half: WindowHalf, display: DisplayGeometry, gap: CGFloat = 8) -> CGRect? {
    guard
        isUsableRect(display.frame),
        isUsableRect(display.visibleFrame),
        display.scale.isFinite,
        display.scale > 0,
        gap.isFinite,
        gap >= 0
    else {
        return nil
    }

    let halfCount: CGFloat = 2
    let halfHeightInPixels = floor(display.frame.height * display.scale / halfCount)
    let midpoint = display.frame.minY + halfHeightInPixels / display.scale
    let halfGap = gap / halfCount
    let usable = display.frame.intersection(display.visibleFrame)
    let totalOuterGap = gap * halfCount

    guard usable.width > totalOuterGap, usable.height > totalOuterGap else {
        return nil
    }

    let inset = usable.insetBy(dx: gap, dy: gap)
    let top: CGFloat
    let bottom: CGFloat

    switch half {
        case .top:
            top = inset.minY
            bottom = min(inset.maxY, midpoint - halfGap)
        case .bottom:
            top = max(inset.minY, midpoint + halfGap)
            bottom = inset.maxY
    }

    guard bottom > top else {
        return nil
    }

    return CGRect(x: inset.minX, y: top, width: inset.width, height: bottom - top)
}
