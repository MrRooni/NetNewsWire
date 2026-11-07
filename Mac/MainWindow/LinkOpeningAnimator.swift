import AppKit
import QuartzCore

/// Displays temporary feedback without changing the source's layout or focus.
@MainActor struct LinkOpeningAnimator {

	private static let Duration: TimeInterval = 0.4
	private static let Scale: CGFloat = 1.15

	/// `rect` is expressed in `hostView`'s coordinates. Use a host above any clipping scroll view.
	/// Web content can supply a snapshot and convert its bounds into this coordinate system.
	static func animate(image: NSImage, from rect: NSRect, in hostView: NSView, reduceMotion: Bool? = nil) {
		guard rect.isEmpty == false, rect.origin.x.isFinite, rect.origin.y.isFinite,
			rect.width.isFinite, rect.height.isFinite else {
			return
		}

		// We create a temporary view to hold the image layer we want to manipulate
		let snapshotView = NSView(frame: rect)
		snapshotView.setAccessibilityElement(false)
		snapshotView.wantsLayer = true
		hostView.addSubview(snapshotView, positioned: .above, relativeTo: nil)

		let imageLayer = CALayer()
		imageLayer.frame = snapshotView.bounds
		imageLayer.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
		snapshotView.layer?.addSublayer(imageLayer)

		let shouldReduceMotion = reduceMotion ?? NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
		let scale = shouldReduceMotion ? 1 : Self.Scale
		let growth = CABasicAnimation(keyPath: "transform.scale")
		growth.fromValue = 1
		growth.toValue = scale
		growth.duration = Self.Duration

		let fade = CABasicAnimation(keyPath: "opacity")
		fade.fromValue = 1
		fade.toValue = 0
		fade.duration = Self.Duration

		let animation = CAAnimationGroup()
		animation.animations = [growth, fade]
		animation.duration = Self.Duration
		animation.timingFunction = CAMediaTimingFunction(name: .easeOut)

		// Animate a child layer so AppKit's view resizing cannot counteract the scale.
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		CATransaction.setCompletionBlock {
			Task { @MainActor in
				snapshotView.removeFromSuperview()
			}
		}
		imageLayer.transform = CATransform3DMakeScale(scale, scale, 1)
		imageLayer.opacity = 0
		imageLayer.add(animation, forKey: "opening")
		CATransaction.commit()
	}

	/// Captures only the visible part of a native view. Both views must belong to the same hierarchy.
	static func animate(view: NSView, in hostView: NSView) {
		guard view === hostView || view.isDescendant(of: hostView) else {
			return
		}

		let bounds = view.visibleRect
		guard bounds.isEmpty == false, let representation = view.bitmapImageRepForCachingDisplay(in: bounds) else {
			return
		}

		view.cacheDisplay(in: bounds, to: representation)
		let image = NSImage(size: bounds.size)
		image.addRepresentation(representation)
		LinkOpeningAnimator.animate(image: image, from: view.convert(bounds, to: hostView), in: hostView)
	}
}
