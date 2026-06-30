(function () {
  'use strict';

  var VIEWPORT_WIDTH = 1280;
  var SCREEN_WIDTH = 1280;

  function ensureViewportMeta() {
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      document.head.appendChild(meta);
    }
    var scale = SCREEN_WIDTH / VIEWPORT_WIDTH;
    var desired =
      'width=' +
      VIEWPORT_WIDTH +
      ', initial-scale=' +
      scale +
      ', user-scalable=no';
    if (meta.content === desired) {
      return;
    }
    meta.content = desired;
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

    var style = document.createElement('style');
    style.textContent =
      '*, *::before, *::after { touch-action: none !important; }';
    if (document.head) {
      document.head.appendChild(style);
    } else {
      document.addEventListener(
        'DOMContentLoaded',
        function () {
          document.head.appendChild(style);
        },
        { once: true },
      );
    }

    document.addEventListener(
      'touchstart',
      function (e) {
        e.preventDefault();
      },
      { passive: false, capture: true },
    );
  }

  function installViewportGuard() {
    var pending = false;
    var observer = new MutationObserver(function () {
      if (pending) {
        return;
      }
      pending = true;
      requestAnimationFrame(function () {
        pending = false;
        ensureViewportMeta();
      });
    });
    observer.observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['content', 'name'],
    });

    var originalPushState = history.pushState;
    var originalReplaceState = history.replaceState;

    history.pushState = function () {
      originalPushState.apply(this, arguments);
      ensureViewportMeta();
    };

    history.replaceState = function () {
      originalReplaceState.apply(this, arguments);
      ensureViewportMeta();
    };

    window.addEventListener('popstate', ensureViewportMeta);
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

  if (document.documentElement) {
    installViewportGuard();
  } else {
    document.addEventListener('DOMContentLoaded', installViewportGuard, {
      once: true,
    });
  }

  window.__cursorPadDesktop = {
    setViewportWidth: function (width, screenWidth) {
      VIEWPORT_WIDTH = Math.max(width, 1);
      if (screenWidth != null) {
        SCREEN_WIDTH = Math.max(screenWidth, 1);
      }
      ensureViewportMeta();
    },
  };
})();
