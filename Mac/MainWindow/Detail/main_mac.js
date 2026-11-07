function scrollDetection() {
	window.onscroll = function(event) {
		window.webkit.messageHandlers.windowDidScroll.postMessage(window.scrollY);
	}
}

function linkHover() {
	window.onmouseover = function(event) {
		var closestAnchor = event.target.closest('a')
		if (closestAnchor) {
			window.webkit.messageHandlers.mouseDidEnter.postMessage(closestAnchor.href);
		}
	}
	window.onmouseout = function(event) {
		var closestAnchor = event.target.closest('a')
		if (closestAnchor) {
			window.webkit.messageHandlers.mouseDidExit.postMessage(closestAnchor.href);
		}
	}
}

// Remember the actual activated element, rather than finding another link with the same URL.
let pendingLinkOpening = null;

function linkOpeningTracking() {
	function rememberLink(event) {
		const anchor = event.target instanceof Element ? event.target.closest('a[href]') : null;
		pendingLinkOpening = anchor ? { anchor, time: performance.now() } : null;
	}
	document.addEventListener('click', rememberLink, true);
	document.addEventListener('auxclick', rememberLink, true);
}

function linkOpeningGeometry(url) {
	const pending = pendingLinkOpening;
	pendingLinkOpening = null;
	if (!pending || performance.now() - pending.time > 1000 ||
		!pending.anchor.isConnected || pending.anchor.href !== url) {
		return null;
	}
	return {
		viewportWidth: window.innerWidth,
		rectangles: Array.from(pending.anchor.getClientRects(), rect => ({
			x: rect.x, y: rect.y, width: rect.width, height: rect.height
		}))
	};
}

// The selection as an HTML fragment — links, bold, and so on included.
function selectedHTML() {
	var selection = window.getSelection();
	var container = document.createElement("div");
	for (var i = 0; i < selection.rangeCount; i++) {
		container.appendChild(selection.getRangeAt(i).cloneContents());
	}
	// Relative URLs would break outside this page.
	container.querySelectorAll("a[href]").forEach(function(anchor) {
		anchor.setAttribute("href", anchor.href);
	});
	// Images served from the timeline’s copy would break outside this page.
	container.querySelectorAll("img[data-nnw-src]").forEach(function(image) {
		image.setAttribute("src", image.getAttribute("data-nnw-src"));
		image.removeAttribute("data-nnw-src");
	});
	// A single-paragraph selection doesn't need its <p> wrapper.
	if (container.childNodes.length === 1 && container.firstChild.nodeName === "P") {
		return container.firstChild.innerHTML;
	}
	return container.innerHTML;
}

function postRenderProcessing() {
	scrollDetection();
	linkHover();
	linkOpeningTracking();
}
