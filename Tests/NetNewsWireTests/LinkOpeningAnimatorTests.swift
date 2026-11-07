import AppKit
import QuartzCore
import XCTest

@testable import NetNewsWire

@MainActor final class LinkOpeningAnimatorTests: XCTestCase {

	func testSnapshotGrowsFromOriginalSizeWhileFadingOut() throws {
		let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
		let rect = NSRect(x: 20, y: 40, width: 100, height: 30)
		LinkOpeningAnimator.animate(image: NSImage(size: rect.size), from: rect, in: host, reduceMotion: false)

		let snapshot = try XCTUnwrap(host.subviews.first)
		XCTAssertEqual(snapshot.frame, rect)
		let imageLayer = try XCTUnwrap(snapshot.layer?.sublayers?.first)
		let animation = try XCTUnwrap(imageLayer.animation(forKey: "opening") as? CAAnimationGroup)
		let scale = try XCTUnwrap(animation.animations?.compactMap { $0 as? CABasicAnimation }.first { $0.keyPath == "transform.scale" })
		XCTAssertEqual(scale.fromValue as? CGFloat, 1)
		XCTAssertEqual(scale.toValue as? CGFloat, 1.25)
		let fade = try XCTUnwrap(animation.animations?.compactMap { $0 as? CABasicAnimation }.first { $0.keyPath == "opacity" })
		XCTAssertEqual(fade.fromValue as? Float, 1)
		XCTAssertEqual(fade.toValue as? Float, 0)
		XCTAssertEqual(animation.duration, 0.2)
	}

	func testSnapshotDoesNotInterceptClicksAndIsRemovedAfterAnimation() throws {
		let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
		let image = NSImage(size: NSSize(width: 100, height: 30))
		LinkOpeningAnimator.animate(image: image, from: NSRect(x: 20, y: 40, width: 100, height: 30), in: host)

		let snapshot = try XCTUnwrap(host.subviews.first)
		XCTAssertNil(snapshot.hitTest(NSPoint(x: 25, y: 45)))
		XCTAssertFalse(snapshot.isAccessibilityElement())

		let removed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
			MainActor.assumeIsolated { host.subviews.isEmpty }
		}, object: nil)
		wait(for: [removed], timeout: 2)
	}

	func testEmptySourceDoesNotCreateSnapshot() {
		let host = NSView()
		LinkOpeningAnimator.animate(image: NSImage(), from: .zero, in: host)
		XCTAssertTrue(host.subviews.isEmpty)
	}

	func testReducedMotionDoesNotScaleSnapshot() throws {
		let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
		let rect = NSRect(x: 20, y: 40, width: 100, height: 30)
		LinkOpeningAnimator.animate(image: NSImage(size: rect.size), from: rect, in: host, reduceMotion: true)
		XCTAssertEqual(try XCTUnwrap(host.subviews.first).frame, rect)
	}

	func testNativeCapturePreservesSource() {
		let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
		let source = NSView(frame: NSRect(x: 20, y: 40, width: 100, height: 30))
		host.addSubview(source)
		let originalFrame = source.frame

		LinkOpeningAnimator.animate(view: source, in: host)

		XCTAssertEqual(source.frame, originalFrame)
		XCTAssertEqual(source.alphaValue, 1)
		XCTAssertFalse(source.isHidden)
		XCTAssertTrue(source.superview === host)
	}
}
