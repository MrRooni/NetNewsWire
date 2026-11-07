import AppKit
import XCTest

@testable import NetNewsWire

@MainActor final class TimelineOpeningAnimationTests: XCTestCase, NSTableViewDataSource, NSTableViewDelegate {

	func numberOfRows(in tableView: NSTableView) -> Int {
		return 2
	}

	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
		return NSTableRowView()
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		return NSTextField(labelWithString: "Article")
	}

	func testOpeningSelectedRowAddsSnapshotWithoutChangingSelection() throws {
		let controller = TimelineViewController(nibName: "TimelineTableView", bundle: nil)
		let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
		window.contentView = controller.view
		let table = controller.tableView!
		table.dataSource = self
		table.delegate = self
		table.reloadData()
		table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
		controller.view.layoutSubtreeIfNeeded()
		XCTAssertEqual(table.numberOfRows, 2)
		// The test window isn't displayed, so explicitly create the row AppKit would draw.
		let row = try XCTUnwrap(table.rowView(atRow: 0, makeIfNecessary: true))
		XCTAssertFalse(row.visibleRect.isEmpty)

		controller.animateSelectedArticleOpening()

		XCTAssertEqual(window.contentView?.subviews.filter { $0 is LinkOpeningSnapshotView }.count, 1)
		XCTAssertEqual(table.selectedRowIndexes, IndexSet(integer: 0))
	}

	func testOpeningWithoutSelectionDoesNotAddSnapshot() {
		let controller = TimelineViewController(nibName: "TimelineTableView", bundle: nil)
		let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
		window.contentView = controller.view

		controller.animateSelectedArticleOpening()

		XCTAssertFalse(window.contentView!.subviews.contains { $0 is LinkOpeningSnapshotView })
	}
}
