import AppKit
import XCTest

@testable import NetNewsWire

final class WebLinkOpeningGeometryTests: XCTestCase {

	func testViewportInsetOffsetsSnapshotToMatchRenderedContent() throws {
		let value: [String: Any] = ["viewportWidth": 200, "rectangles": [["x": 30, "y": 40, "width": 60, "height": 10]]]
		let bounds = NSRect(x: 0, y: 0, width: 200, height: 200)
		let insets = NSEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
		let flipped = try XCTUnwrap(WebLinkOpeningGeometry(value: value, bounds: bounds, isFlipped: true, contentInsets: insets))
		XCTAssertEqual(flipped.rect, NSRect(x: 30, y: 60, width: 60, height: 10))
		XCTAssertEqual(flipped.snapshotRect, NSRect(x: 30, y: 40, width: 60, height: 10))
		let unflipped = try XCTUnwrap(WebLinkOpeningGeometry(value: value, bounds: bounds, isFlipped: false, contentInsets: insets))
		XCTAssertEqual(unflipped.rect, NSRect(x: 30, y: 130, width: 60, height: 10))
		XCTAssertEqual(unflipped.snapshotRect, NSRect(x: 30, y: 150, width: 60, height: 10))
	}

	func testWrappedLinkKeepsSeparateFragmentsAndAccountsForZoom() throws {
		let value: [String: Any] = ["viewportWidth": 200, "rectangles": [
			["x": 20, "y": 10, "width": 80, "height": 10],
			["x": 0, "y": 20, "width": 30, "height": 10]
		]]
		let geometry = try XCTUnwrap(WebLinkOpeningGeometry(value: value, bounds: NSRect(x: 0, y: 0, width: 400, height: 200), isFlipped: true))
		XCTAssertEqual(geometry.fragments, [NSRect(x: 40, y: 20, width: 160, height: 20), NSRect(x: 0, y: 40, width: 60, height: 20)])
		XCTAssertEqual(geometry.rect, NSRect(x: 0, y: 20, width: 200, height: 40))
	}

	func testLinkIsClippedToViewportAndConvertedToUnflippedCoordinates() throws {
		let value: [String: Any] = ["viewportWidth": 200, "rectangles": [["x": -10, "y": 90, "width": 40, "height": 20]]]
		let geometry = try XCTUnwrap(WebLinkOpeningGeometry(value: value, bounds: NSRect(x: 0, y: 0, width: 200, height: 100), isFlipped: false))
		XCTAssertEqual(geometry.rect, NSRect(x: 0, y: 0, width: 30, height: 10))
	}

	func testInvalidOrInvisibleGeometryIsIgnored() {
		let bounds = NSRect(x: 0, y: 0, width: 200, height: 100)
		XCTAssertNil(WebLinkOpeningGeometry(value: ["viewportWidth": 0, "rectangles": []], bounds: bounds, isFlipped: true))
		let value: [String: Any] = ["viewportWidth": 200, "rectangles": [["x": 0, "y": 200, "width": 30, "height": 20]]]
		XCTAssertNil(WebLinkOpeningGeometry(value: value, bounds: bounds, isFlipped: true))
	}

	@MainActor func testMaskLeavesSpaceBetweenWrappedFragmentsTransparent() throws {
		let value: [String: Any] = ["viewportWidth": 100, "rectangles": [
			["x": 50, "y": 0, "width": 50, "height": 20],
			["x": 0, "y": 20, "width": 50, "height": 20]
		]]
		let geometry = try XCTUnwrap(WebLinkOpeningGeometry(value: value, bounds: NSRect(x: 0, y: 0, width: 100, height: 40), isFlipped: true))
		let source = NSImage(size: geometry.rect.size)
		source.lockFocus()
		NSColor.red.setFill()
		NSRect(origin: .zero, size: source.size).fill()
		source.unlockFocus()
		let image = geometry.mask(source)
		let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil)))
		XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 4, y: bitmap.pixelsHigh / 4)).alphaComponent, 0)
		XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide * 3 / 4, y: bitmap.pixelsHigh / 4)).alphaComponent, 1)
		XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide * 3 / 4, y: bitmap.pixelsHigh * 3 / 4)).alphaComponent, 0)
	}
}
