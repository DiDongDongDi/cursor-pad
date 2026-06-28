(function () {
  'use strict';

  var VIEWPORT_WIDTH = 1280;
  var SCREEN_WIDTH = 1280;
  var lastViewportContent = '';
  var ensureScheduled = false;

  function buildViewportContent() {
    var scale = SCREEN_WIDTH / VIEWPORT_WIDTH;
    return (
      'width=' +
      VIEWPORT_WIDTH +
      ', initial-scale=' +
      scale +
      ', user-scalable=no'
    );
  }

  function ensureViewportMeta() {
    var content = buildViewportContent();
    if (content === lastViewportContent) {
      return;
    }

    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = content;
      if (document.head) {
        document.head.appendChild(meta);
      }
      lastViewportContent = content;
      return;
    }

    if (meta.content !== content) {
      meta.content = content;
    }
    lastViewportContent = content;
  }

  function scheduleEnsureViewportMeta() {
    if (ensureScheduled) {
      return;
    }
    ensureScheduled = true;
    requestAnimationFrame(function () {
      ensureScheduled = false;
      ensureViewportMeta();
    });
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
    var observer = new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var mutation = mutations[i];
        if (mutation.type === 'childList') {
          scheduleEnsureViewportMeta();
          return;
        }
        if (
          mutation.type === 'attributes' &&
          mutation.target &&
          mutation.target.getAttribute &&
          mutation.target.getAttribute('name') === 'viewport'
        ) {
          scheduleEnsureViewportMeta();
          return;
        }
      }
    });

    var head = document.head;
    if (head) {
      observer.observe(head, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['content', 'name'],
      });
    }

    var originalPushState = history.pushState;
    var originalReplaceState = history.replaceState;

    history.pushState = function () {
      originalPushState.apply(this, arguments);
      scheduleEnsureViewportMeta();
    };

    history.replaceState = function () {
      originalReplaceState.apply(this, arguments);
      scheduleEnsureViewportMeta();
    };

    window.addEventListener('popstate', scheduleEnsureViewportMeta);
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

  if (document.head) {
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
      lastViewportContent = '';
      ensureViewportMeta();
    },
  };
})();
