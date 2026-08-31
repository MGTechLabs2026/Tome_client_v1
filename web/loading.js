// Removes the pre-boot loading shell (#loading in index.html) once Flutter
// is up. External file (not inline) so a strict `script-src 'self'` CSP —
// e.g. inside a Reddit Devvit webview — still allows it. Three triggers,
// so one failing path can't leave the shell stuck:
//   1. Flutter's own 'flutter-first-frame' event
//   2. a MutationObserver watching for the flutter view element
//   3. a 20s failsafe
(function () {
  var removed = false;
  function hide() {
    if (removed) return;
    removed = true;
    var el = document.getElementById('loading');
    if (!el) return;
    el.classList.add('gone');
    setTimeout(function () { el.remove(); }, 400);
  }
  window.addEventListener('flutter-first-frame', hide);
  var obs = new MutationObserver(function () {
    if (document.querySelector('flutter-view, flt-glass-pane')) {
      obs.disconnect();
      hide();
    }
  });
  obs.observe(document.body, { childList: true, subtree: true });
  setTimeout(hide, 20000);
})();
