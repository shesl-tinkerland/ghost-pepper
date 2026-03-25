import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct FrontmostWindowReference: Equatable, Sendable {
    let windowID: UInt32
    let frame: CGRect
}

final class FocusedElementLocator {
    func capturePasteSession(for text: String, at date: Date = Date()) -> PasteSession? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let windowReference = frontmostWindowReference(for: application.processIdentifier)
        return PasteSession(
            pastedText: text,
            pastedAt: date,
            frontmostAppBundleIdentifier: application.bundleIdentifier,
            frontmostWindowID: windowReference?.windowID,
            frontmostWindowFrame: windowReference?.frame,
            focusedElementFrame: focusedElementFrame(for: application.processIdentifier)
        )
    }

    func frontmostApplicationBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func frontmostWindowReference() -> FrontmostWindowReference? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return frontmostWindowReference(for: application.processIdentifier)
    }

    func focusedElementFrame() -> CGRect? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return focusedElementFrame(for: application.processIdentifier)
    }

    private func focusedElementFrame(for processID: pid_t) -> CGRect? {
        let applicationElement = AXUIElementCreateApplication(processID)
        var focusedElementValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementValue
        ) == .success,
        let focusedElementValue,
        CFGetTypeID(focusedElementValue) == AXUIElementGetTypeID() else {
            return nil
        }

        let focusedElement = unsafeBitCast(focusedElementValue, to: AXUIElement.self)
        return frame(for: focusedElement)
    }

    private func frame(for element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &positionValue
        ) == .success,
        AXUIElementCopyAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            &sizeValue
        ) == .success,
        let positionValue,
        let sizeValue,
        CFGetTypeID(positionValue) == AXValueGetTypeID(),
        CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }

        let positionAXValue = unsafeBitCast(positionValue, to: AXValue.self)
        let sizeAXValue = unsafeBitCast(sizeValue, to: AXValue.self)

        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetType(positionAXValue) == .cgPoint,
              AXValueGetValue(positionAXValue, .cgPoint, &origin),
              AXValueGetType(sizeAXValue) == .cgSize,
              AXValueGetValue(sizeAXValue, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: origin, size: size)
    }

    private func frontmostWindowReference(for processID: pid_t) -> FrontmostWindowReference? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        return windowReference(in: windowList, for: processID)
    }

    func windowReference(in windowList: [[String: Any]], for processID: pid_t) -> FrontmostWindowReference? {
        for windowInfo in windowList {
            let ownerProcessID = (windowInfo[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
            guard ownerProcessID == processID else {
                continue
            }

            let layer = (windowInfo[kCGWindowLayer as String] as? NSNumber)?.intValue
                ?? (windowInfo[kCGWindowLayer as String] as? Int)
                ?? 0
            let alpha = (windowInfo[kCGWindowAlpha as String] as? NSNumber)?.doubleValue
                ?? (windowInfo[kCGWindowAlpha as String] as? Double)
                ?? 1
            guard layer == 0, alpha > 0,
                  let windowNumber = windowInfo[kCGWindowNumber as String] as? NSNumber,
                  let boundsDictionary = windowInfo[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: boundsDictionary) else {
                continue
            }

            return FrontmostWindowReference(
                windowID: windowNumber.uint32Value,
                frame: frame
            )
        }

        return nil
    }
}
