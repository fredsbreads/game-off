// Red Flash crash log (added by tools/export_web.sh). Keeps the last console
// errors/warnings and the game's beats in localStorage as it runs, so they
// survive the tab being killed (iOS does that when it runs out of memory).
// Open the game with ?crashlog=1 to see the last session's log.
(function () {
  var KEY = "rf_crashlog", MAX = 120, store = null;
  try { store = window.localStorage; } catch (e) {}
  function load(k) { try { return JSON.parse(store.getItem(k) || "null"); } catch (e) { return null; } }
  function save(k, v) { try { store.setItem(k, JSON.stringify(v)); } catch (e) {} }
  // This session's log becomes "the last session" (unless the page left cleanly
  // and nothing went wrong, keep it all the same: the newest is what's shown).
  var prev = load(KEY);
  if (prev) save(KEY + "_prev", prev);
  var cur = { started: new Date().toISOString(), ua: navigator.userAgent, ended: "", lines: [] };
  var t0 = Date.now();
  function add(kind, text) {
    cur.lines.push(((Date.now() - t0) / 1000).toFixed(1) + "s " + kind + " " + String(text).slice(0, 400));
    if (cur.lines.length > MAX) cur.lines.splice(0, cur.lines.length - MAX);
    save(KEY, cur);
  }
  ["error", "warn"].forEach(function (k) {
    var orig = console[k];
    console[k] = function () {
      try { add(k.toUpperCase(), Array.prototype.join.call(arguments, " ")); } catch (e) {}
      return orig.apply(console, arguments);
    };
  });
  window.addEventListener("error", function (e) { add("JSERROR", (e.message || e) + " @" + (e.filename || "") + ":" + (e.lineno || "")); });
  window.addEventListener("unhandledrejection", function (e) { add("REJECT", e.reason && (e.reason.stack || e.reason.message) || e.reason); });
  window.addEventListener("pagehide", function () { cur.ended = "page closed normally"; save(KEY, cur); });
  document.addEventListener("visibilitychange", function () { add("PAGE", document.visibilityState); });
  window.rfBeat = function (what) {
    var m = performance && performance.memory;   // (Chrome only; Safari has none)
    add("beat", what + (m ? " jsheap=" + Math.round(m.usedJSHeapSize / 1048576) + "MB" : ""));
  };
  add("PAGE", "loaded");

  if (!/[?&]crashlog=1/.test(location.search)) return;
  var show = load(KEY + "_prev");
  window.addEventListener("DOMContentLoaded", function () {
    var box = document.createElement("div");
    box.style.cssText = "position:fixed;inset:0;z-index:99999;background:rgba(10,10,14,0.96);color:#eee;font:12px/1.4 ui-monospace,Menlo,monospace;padding:12px;overflow:auto;-webkit-overflow-scrolling:touch";
    var text = !show ? "No earlier session saved yet." :
      "LAST SESSION (started " + show.started + ")\n" + (show.ended || "did NOT close normally: crashed or was killed") +
      "\n" + show.ua + "\n\n" + show.lines.join("\n");
    var bar = document.createElement("div");
    bar.style.cssText = "position:sticky;top:0;display:flex;gap:8px;margin-bottom:8px";
    function btn(label, fn) {
      var b = document.createElement("button");
      b.textContent = label;
      b.style.cssText = "font:600 14px system-ui;padding:8px 14px;border-radius:6px;border:1px solid #555;background:#222;color:#fff";
      b.onclick = fn; bar.appendChild(b); return b;
    }
    var copy = btn("Copy log", function () {
      var done = function () { copy.textContent = "Copied"; };
      if (navigator.clipboard) navigator.clipboard.writeText(text).then(done, function () { pre.focus(); });
    });
    btn("Close", function () { box.remove(); });
    var pre = document.createElement("pre");
    pre.style.cssText = "white-space:pre-wrap;word-break:break-word;margin:0;user-select:text;-webkit-user-select:text";
    pre.textContent = text;
    box.appendChild(bar); box.appendChild(pre);
    document.body.appendChild(box);
  });
})();
