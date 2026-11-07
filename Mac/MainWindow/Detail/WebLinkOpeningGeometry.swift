import AppKit

/// Converts a link's CSS fragments into native snapshot coordinates.
struct WebLinkOpeningGeometry {

	let fragments: [NSRect]
	let rect: NSRect
	let snapshotRect: NSRect
	private let isFlipped: Bool

	init?(value: Any, bounds: NSRect, isFlipped: Bool, contentInsets: NSEdgeInsets = NSEdgeInsets()) {
		guard let dictionary = value as? [String: Any],
			let viewportWidth = dictionary["viewportWidth"] as? NSNumber,
			viewportWidth.doubleValue.isFinite, viewportWidth.doubleValue > 0,
			let rectangles = dictionary["rectangles"] as? [[String: NSNumber]] else {
			return nil
		}
		// CSS viewport coordinates start inside WebKit's obscured content insets.
		let viewport = NSRect(x: bounds.minX + contentInsets.left,
							  y: bounds.minY + (isFlipped ? contentInsets.top : contentInsets.bottom),
							  width: bounds.width - contentInsets.left - contentInsets.right,
							  height: bounds.height - contentInsets.top - contentInsets.bottom)
		let scale = viewport.width / viewportWidth.doubleValue
		let fragments = rectangles.compactMap { rectangle -> NSRect? in
			guard let x = rectangle["x"]?.doubleValue, let y = rectangle["y"]?.doubleValue,
				let width = rectangle["width"]?.doubleValue, let height = rectangle["height"]?.doubleValue,
				[x, y, width, height].allSatisfy(\.isFinite), width > 0, height > 0 else {
				return nil
			}
			let nativeY = isFlipped ? viewport.minY + y * scale : viewport.maxY - (y + height) * scale
			let fragment = NSRect(x: viewport.minX + x * scale, y: nativeY, width: width * scale, height: height * scale).intersection(viewport)
			return fragment.isEmpty ? nil : fragment
		}
		guard let first = fragments.first else {
			return nil
		}
		self.fragments = fragments
		rect = fragments.dropFirst().reduce(first) { $0.union($1) }
		// WebKit's snapshot is relative to the content viewport; the overlay is relative to the view.
		snapshotRect = rect.offsetBy(dx: -contentInsets.left, dy: isFlipped ? -contentInsets.top : contentInsets.top)
		self.isFlipped = isFlipped
	}

	/// Leaves the space between wrapped lines transparent instead of copying neighboring text.
	@MainActor func mask(_ image: NSImage) -> NSImage {
		let maskedImage = NSImage(size: rect.size)
		maskedImage.lockFocus()
		defer { maskedImage.unlockFocus() }
		for fragment in fragments {
			let local = NSRect(x: fragment.minX - rect.minX,
							   y: isFlipped ? rect.maxY - fragment.maxY : fragment.minY - rect.minY,
							   width: fragment.width, height: fragment.height)
			let source = NSRect(x: local.minX * image.size.width / rect.width,
								y: local.minY * image.size.height / rect.height,
								width: local.width * image.size.width / rect.width,
								height: local.height * image.size.height / rect.height)
			image.draw(in: local, from: source, operation: .copy, fraction: 1)
		}
		return maskedImage
	}
}
