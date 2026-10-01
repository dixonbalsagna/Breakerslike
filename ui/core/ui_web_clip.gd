class_name UiWebClip
extends RefCounted
## The web build's clipboard bridge for the feedback panel. On the web Godot cannot copy from its own canvas text (Ctrl+C never
## reaches it, a phone cannot long-press it), and Godot handles a tap a frame late, which Safari can treat as no user gesture. So on
## the web (and only there) two things live in the page itself:
##   1. A real DOM <textarea readonly> over the report box, so native select, Ctrl+C and long-press Copy all work. It is removed on
##      close, on Back and whenever the panel is laid out again (a resize).
##   2. A pointer listener on the canvas that, when the tap or click lands inside the COPY REPORT (or COPY AGAIN) button, calls
##      navigator.clipboard.writeText in that very event, with an execCommand fallback, where browsers accept it. Godot keeps the
##      report text current in `window.__fb.report` as the player types and picks tags.
## Off the web every function here does nothing. Nothing is sent anywhere: the text only goes to the clipboard.

const JS_INSTALL := """
(function () {
  if (window.__fb) { return; }
  var fb = window.__fb = { report: '', rect: null, openRect: null, url: '', openedAt: 0, ta: null, ok: false, last: 0 };
  fb.canvas = function () { return document.querySelector('canvas'); };
  fb.scale = function () {
    var c = fb.canvas(), r = c.getBoundingClientRect();
    return { left: r.left, top: r.top, sx: r.width / c.width, sy: r.height / c.height };
  };
  fb.legacy = function (text) {
    try {
      var t = document.createElement('textarea');
      t.value = text; t.setAttribute('readonly', '');
      t.style.position = 'fixed'; t.style.opacity = '0'; t.style.left = '-1000px';
      document.body.appendChild(t); t.focus(); t.select();
      fb.ok = document.execCommand('copy');
      document.body.removeChild(t);
    } catch (e) { fb.ok = false; }
    var c = fb.canvas(); if (c) { c.focus(); }
  };
  fb.copy = function (text) {
    var asked = false;
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        asked = true;
        navigator.clipboard.writeText(text).then(function () { fb.ok = true; }, function () { fb.legacy(text); });
      }
    } catch (e) { asked = false; }
    if (!asked) { fb.legacy(text); }
  };
  fb.open = function (url) {
    fb.openedAt = Date.now();
    try {
      if (/^mailto:/i.test(url)) { window.location.href = url; } else { window.open(url, '_blank', 'noopener'); }
    } catch (e) { }
  };
  fb.inside = function (r, ev) {
    if (!r) { return false; }
    var s = fb.scale(), x = (ev.clientX - s.left) / s.sx, y = (ev.clientY - s.top) / s.sy;
    return x >= r[0] && x <= r[0] + r[2] && y >= r[1] && y <= r[1] + r[3];
  };
  fb.onup = function (ev) {
    var now = Date.now(); if (now - fb.last < 250) { return; }
    if (fb.inside(fb.rect, ev)) { fb.last = now; fb.copy(fb.report); }
    else if (fb.inside(fb.openRect, ev)) { fb.last = now; fb.copy(fb.report); fb.open(fb.url); }
  };
  var c0 = fb.canvas();
  if (c0) { c0.addEventListener('pointerup', fb.onup, true); c0.addEventListener('click', fb.onup, true); }
  fb.show = function (x, y, w, h, px, text) {
    fb.hide();
    var s = fb.scale(), t = document.createElement('textarea');
    t.value = text; t.setAttribute('readonly', ''); t.setAttribute('aria-label', 'Feedback report');
    var st = t.style;
    st.position = 'fixed'; st.left = (s.left + x * s.sx) + 'px'; st.top = (s.top + y * s.sy) + 'px';
    st.width = (w * s.sx) + 'px'; st.height = (h * s.sy) + 'px'; st.boxSizing = 'border-box';
    st.font = (px * s.sy) + 'px sans-serif'; st.lineHeight = '1.25'; st.padding = (6 * s.sy) + 'px';
    st.background = '#14161d'; st.color = '#f4f1ea'; st.border = '1px solid #8a877c'; st.borderRadius = '6px';
    st.resize = 'none'; st.zIndex = '10'; st.whiteSpace = 'pre-wrap';
    t.addEventListener('keydown', function (e) { if (e.key === 'Escape' && window.__fbClose) { window.__fbClose(); } });
    document.body.appendChild(t); fb.ta = t;
  };
  fb.hide = function () { if (fb.ta) { fb.ta.remove(); fb.ta = null; } };
})();
"""

static var _close_cb = null   # keeps the JS callback alive


static func available() -> bool:
	return OS.has_feature("web")


## Define the page-side helpers (once) and let the textarea's Esc key close the panel through `on_close`.
static func install(on_close: Callable) -> void:
	if not available():
		return
	JavaScriptBridge.eval(JS_INSTALL, true)
	_close_cb = JavaScriptBridge.create_callback(func(_args): on_close.call())
	JavaScriptBridge.get_interface("window").__fbClose = _close_cb


## Keep the page's copy of the report current (the listener copies this in the gesture).
static func set_report(text: String) -> void:
	if available():
		JavaScriptBridge.eval("window.__fb && (window.__fb.report = %s);" % JSON.stringify(text), true)


## The button the listener watches, in canvas pixels; an empty rect stops it.
static func set_copy_rect(r: Rect2) -> void:
	if not available():
		return
	if r.size.x <= 0.0:
		JavaScriptBridge.eval("window.__fb && (window.__fb.rect = null);", true)
	else:
		JavaScriptBridge.eval("window.__fb && (window.__fb.rect = [%f, %f, %f, %f]);" % [r.position.x, r.position.y, r.size.x, r.size.y], true)


## The OPEN ISSUE button the listener watches, and the link it opens (with the report copied in the same gesture); an empty rect stops it.
static func set_open(r: Rect2, url: String) -> void:
	if not available():
		return
	if r.size.x <= 0.0:
		JavaScriptBridge.eval("window.__fb && (window.__fb.openRect = null, window.__fb.url = '');", true)
	else:
		JavaScriptBridge.eval("window.__fb && (window.__fb.openRect = [%f, %f, %f, %f], window.__fb.url = %s);" % [r.position.x, r.position.y, r.size.x, r.size.y, JSON.stringify(url)], true)


## Open a link from Godot's own click path, unless the page's listener just opened it in the real gesture (it sets openedAt).
static func open_url(url: String) -> void:
	if available():
		JavaScriptBridge.eval("(function () { var f = window.__fb; if (f && Date.now() - f.openedAt < 1500) { return; } if (f) { f.open(%s); } else { window.open(%s, '_blank', 'noopener'); } })();" % [JSON.stringify(url), JSON.stringify(url)], true)


## Copy from Godot's own click path too (it works where the page still counts the tap as a gesture).
static func copy(text: String) -> void:
	if available():
		JavaScriptBridge.eval("window.__fb && window.__fb.copy(%s);" % JSON.stringify(text), true)


## A real textarea over the preview box, in canvas pixels; `font_px` is the canvas font size.
static func show_textarea(r: Rect2, font_px: float, text: String) -> void:
	if available():
		JavaScriptBridge.eval("window.__fb && window.__fb.show(%f, %f, %f, %f, %f, %s);" % [r.position.x, r.position.y, r.size.x, r.size.y, font_px, JSON.stringify(text)], true)


static func hide_textarea() -> void:
	if available():
		JavaScriptBridge.eval("window.__fb && window.__fb.hide();", true)


## Remove everything: the textarea and the watched button.
static func clear() -> void:
	hide_textarea()
	set_copy_rect(Rect2())
	set_open(Rect2(), "")
