(function () {
  'use strict';

  var VIEWPORT_WIDTH = 1280;

  function ensureViewportMeta() {
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      document.head.appendChild(meta);
    }
    meta.content = 'width=' + VIEWPORT_WIDTH + ', initial-scale=1.0, user-scalable=yes';
  }

  function patchNavigator() {
    try {
      Object.defineProperty(navigator, 'maxTouchPoints', {
        get: function () {
          return 0;
        },
        configurable: true,
      });
    } catch (e) {
      /* ignore */
    }

    try {
      Object.defineProperty(navigator, 'platform', {
        get: function () {
          return 'Win32';
        },
        configurable: true,
      });
    } catch (e) {
      /* ignore */
    }
  }

  function patchTouchDetection() {
    window.ontouchstart = undefined;
    document.ontouchstart = undefined;
  }

  if (document.head) {
    ensureViewportMeta();
  } else {
    document.addEventListener(
      'DOMContentLoaded',
      function () {
        ensureViewportMeta();
      },
      { once: true },
    );
  }

  patchNavigator();
  patchTouchDetection();

  window.__cursorPadDesktop = {
    setViewportWidth: function (width) {
      VIEWPORT_WIDTH = width;
      ensureViewportMeta();
    },
  };
})();
