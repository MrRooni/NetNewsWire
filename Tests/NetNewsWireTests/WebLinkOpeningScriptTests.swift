import WebKit
import XCTest

@testable import NetNewsWire

@MainActor final class WebLinkOpeningScriptTests: XCTestCase, WKNavigationDelegate {

	private var navigationFinished: XCTestExpectation?

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		navigationFinished?.fulfill()
	}

	func testNestedWrappedLinkReportsFragmentsAndOnlyConsumesActivationOnce() async throws {
		let webView = try await makeWebView()
		let result = try await webView.evaluateJavaScript("""
		linkOpeningTracking();
		document.addEventListener('click', event => event.preventDefault());
		document.querySelector('#nested').click();
		const geometry = linkOpeningGeometry('https://example.com/');
		[geometry, linkOpeningGeometry('https://example.com/') === null];
		""")
		let values = try XCTUnwrap(result as? [Any])
		let geometry = try XCTUnwrap(WebLinkOpeningGeometry(value: values[0], bounds: webView.bounds, isFlipped: webView.isFlipped))
		XCTAssertGreaterThan(geometry.fragments.count, 1)
		XCTAssertFalse(geometry.rect.isEmpty)
		XCTAssertEqual(values[1] as? Bool, true)
	}

	func testDifferentDestinationAndNonLinkClickDoNotReuseLinkGeometry() async throws {
		let webView = try await makeWebView()
		let result = try await webView.evaluateJavaScript("""
		linkOpeningTracking();
		document.addEventListener('click', event => event.preventDefault());
		document.querySelector('#nested').click();
		const differentURL = linkOpeningGeometry('https://example.org/') === null;
		document.querySelector('#nested').click();
		document.body.click();
		[differentURL, linkOpeningGeometry('https://example.com/') === null];
		""")
		let values = try XCTUnwrap(result as? [Bool])
		XCTAssertEqual(values, [true, true])
	}

	private func makeWebView() async throws -> WKWebView {
		let scriptURL = try XCTUnwrap(Bundle.main.url(forResource: "main_mac", withExtension: "js"))
		let script = try String(contentsOf: scriptURL, encoding: .utf8)
		let configuration = WKWebViewConfiguration()
		configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
		let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 200, height: 200), configuration: configuration)
		webView.navigationDelegate = self
		let finished = expectation(description: "Load link fixture")
		navigationFinished = finished
		webView.loadHTMLString("<div style='width:60px'><a href='https://example.com/'><span id='nested'>A link that wraps across several lines</span></a></div>", baseURL: nil)
		await fulfillment(of: [finished], timeout: 5)
		return webView
	}
}
