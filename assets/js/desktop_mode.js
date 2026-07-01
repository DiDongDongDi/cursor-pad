(function () {
  'use strict';

  var VIEWPORT_WIDTH = 1280;
  var VIEWPORT_HEIGHT = 720;
  var SCREEN_WIDTH = 1280;
  var _heightRatio = null;

  function updateViewportDimensions() {
    if (_heightRatio == null) {
      var iw = window.innerWidth || VIEWPORT_WIDTH;
      var ih = window.innerHeight || VIEWPORT_HEIGHT;
      _heightRatio = ih / Math.max(iw, 1);
    }
    VIEWPORT_HEIGHT = Math.round(VIEWPORT_WIDTH * _heightRatio);
  }

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

  function patchScreenDimensions() {
    updateViewportDimensions();

    try {
      Object.defineProperty(window, 'innerWidth', {
        get: function () {
          return VIEWPORT_WIDTH;
        },
        configurable: true,
      });
      Object.defineProperty(window, 'outerWidth', {
        get: function () {
          return VIEWPORT_WIDTH;
        },
        configurable: true,
      });
      Object.defineProperty(window, 'innerHeight', {
        get: function () {
          return VIEWPORT_HEIGHT;
        },
        configurable: true,
      });
      Object.defineProperty(window, 'outerHeight', {
        get: function () {
          return VIEWPORT_HEIGHT;
        },
        configurable: true,
      });
    } catch (e) {
      /* ignore */
    }

    try {
      Object.defineProperty(window.screen, 'width', {
        get: function () {
          return VIEWPORT_WIDTH;
        },
        configurable: true,
      });
      Object.defineProperty(window.screen, 'height', {
        get: function () {
          return VIEWPORT_HEIGHT;
        },
        configurable: true,
      });
      Object.defineProperty(window.screen, 'availWidth', {
        get: function () {
          return VIEWPORT_WIDTH;
        },
        configurable: true,
      });
      Object.defineProperty(window.screen, 'availHeight', {
        get: function () {
          return VIEWPORT_HEIGHT;
        },
        configurable: true,
      });
    } catch (e) {
      /* ignore */
    }
  }

  function rewriteMediaQuery(query) {
    return query
      .replace(/max-device-width/gi, 'max-width')
      .replace(/min-device-width/gi, 'min-width')
      .replace(/\(hover:\s*none\)/gi, '(hover: hover)')
      .replace(/\(pointer:\s*coarse\)/gi, '(pointer: fine)');
  }

  function patchMatchMedia() {
    var original = window.matchMedia.bind(window);
    window.matchMedia = function (query) {
      return original(rewriteMediaQuery(query));
    };
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

  function patchUserAgentData() {
    var uaData = navigator.userAgentData;
    if (!uaData) {
      return;
    }

    try {
      var brands = uaData.brands ? uaData.brands.slice() : [];
      var originalGetHighEntropyValues =
        uaData.getHighEntropyValues.bind(uaData);

      var fakeUaData = {
        brands: brands,
        mobile: false,
        platform: 'Windows',
        getHighEntropyValues: function (hints) {
          return originalGetHighEntropyValues(hints).then(function (values) {
            values.mobile = false;
            values.platform = 'Windows';
            if (hints.indexOf('platformVersion') !== -1) {
              values.platformVersion = '10.0.0';
            }
            return values;
          });
        },
      };

      Object.defineProperty(navigator, 'userAgentData', {
        get: function () {
          return fakeUaData;
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
      '*, *::before, *::after { touch-action: none !important; }' +
      'html { -webkit-text-size-adjust: 100% !important; text-size-adjust: 100% !important; }';
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

  updateViewportDimensions();
  patchScreenDimensions();
  patchMatchMedia();
  patchNavigator();
  patchUserAgentData();
  patchTouchDetection();

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
      updateViewportDimensions();
      ensureViewportMeta();
    },
  };
})();
