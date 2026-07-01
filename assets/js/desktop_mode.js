(function () {
  'use strict';

  var VIEWPORT_WIDTH = 1280;
  var VIEWPORT_HEIGHT = 720;
  var SCREEN_WIDTH = 1280;
  var _heightRatio = null;
  var BASE_SCALE = 1;
  var MIN_USER_SCALE = 0.5;
  var MAX_USER_SCALE = 3;
  var USER_SCALE = MIN_USER_SCALE;
  var LAYOUT_STYLE_ID = 'cursorpad-desktop-layout';
  var TOUCH_STYLE_ID = 'cursorpad-touch-patch';

  var MOBILE_MEDIA_PATTERN = /max-device-width|min-device-width/i;

  function isMobileOnlyMaxWidth(media) {
    var match = media.match(/max-width\s*:\s*(\d+(?:\.\d+)?)(px|em|rem)?/gi);
    if (!match) {
      return false;
    }
    for (var i = 0; i < match.length; i++) {
      var parts = /max-width\s*:\s*(\d+(?:\.\d+)?)(px|em|rem)?/i.exec(
        match[i],
      );
      if (!parts) {
        continue;
      }
      var value = parseFloat(parts[1]);
      var unit = (parts[2] || 'px').toLowerCase();
      if (unit === 'em' || unit === 'rem') {
        value = value * 16;
      }
      if (value <= 1024) {
        return true;
      }
    }
    return false;
  }

  function isMobileMedia(media) {
    if (!media || media === 'all' || media === 'screen') {
      return false;
    }
    if (MOBILE_MEDIA_PATTERN.test(media)) {
      return true;
    }
    return isMobileOnlyMaxWidth(media);
  }

  function updateViewportDimensions() {
    if (_heightRatio == null) {
      var iw = window.innerWidth || VIEWPORT_WIDTH;
      var ih = window.innerHeight || VIEWPORT_HEIGHT;
      _heightRatio = ih / Math.max(iw, 1);
    }
    VIEWPORT_HEIGHT = Math.round(VIEWPORT_WIDTH * _heightRatio);
  }

  function getEffectiveScale() {
    return BASE_SCALE * USER_SCALE;
  }

  function ensureViewportMeta() {
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      document.head.appendChild(meta);
    }
    BASE_SCALE = SCREEN_WIDTH / VIEWPORT_WIDTH;
    var scale = getEffectiveScale();
    var desired =
      'width=' +
      VIEWPORT_WIDTH +
      ', initial-scale=' +
      scale +
      ', minimum-scale=' +
      BASE_SCALE * MIN_USER_SCALE +
      ', maximum-scale=' +
      BASE_SCALE * MAX_USER_SCALE +
      ', user-scalable=yes';
    if (meta.content === desired) {
      return;
    }
    meta.content = desired;
  }

  function setUserScale(scale) {
    USER_SCALE = Math.max(MIN_USER_SCALE, Math.min(MAX_USER_SCALE, scale));
    ensureViewportMeta();
  }

  function zoomBy(factor) {
    if (!factor || factor <= 0) {
      return;
    }
    setUserScale(USER_SCALE * factor);
  }

  function resetUserScale() {
    USER_SCALE = MIN_USER_SCALE;
    ensureViewportMeta();
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

  function patchDocumentDimensions() {
    var root = document.documentElement;
    if (!root) {
      return;
    }

    try {
      Object.defineProperty(root, 'clientWidth', {
        get: function () {
          return VIEWPORT_WIDTH;
        },
        configurable: true,
      });
      Object.defineProperty(root, 'clientHeight', {
        get: function () {
          return VIEWPORT_HEIGHT;
        },
        configurable: true,
      });
      Object.defineProperty(root, 'scrollWidth', {
        get: function () {
          return Math.max(root.offsetWidth || 0, VIEWPORT_WIDTH);
        },
        configurable: true,
      });
    } catch (e) {
      /* ignore */
    }

    var body = document.body;
    if (!body) {
      return;
    }

    try {
      Object.defineProperty(body, 'clientWidth', {
        get: function () {
          return VIEWPORT_WIDTH;
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

  function neutralizeMobileStylesheetLinks(root) {
    var links = (root || document).querySelectorAll('link[rel~="stylesheet"]');
    for (var i = 0; i < links.length; i++) {
      var link = links[i];
      var media = (link.getAttribute('media') || '').trim();
      if (!isMobileMedia(media)) {
        continue;
      }
      if (!link.hasAttribute('data-cursorpad-original-media')) {
        link.setAttribute('data-cursorpad-original-media', media);
      }
      link.media = 'not all';
      link.disabled = true;
    }
  }

  function buildDesktopLayoutCss() {
    return (
      '@media (max-device-width: 99999px), (max-width: 99999px) {' +
      'table { display: table !important; table-layout: auto !important; width: auto !important; max-width: none !important; }' +
      'thead { display: table-header-group !important; }' +
      'tbody { display: table-row-group !important; }' +
      'tfoot { display: table-footer-group !important; }' +
      'colgroup { display: table-column-group !important; }' +
      'col { display: table-column !important; }' +
      'tr { display: table-row !important; }' +
      'td, th { display: table-cell !important; white-space: normal !important; ' +
      'word-wrap: break-word !important; overflow-wrap: break-word !important; ' +
      'word-break: normal !important; width: auto !important; max-width: none !important; }' +
      '.table-responsive, [class*="table-responsive"], [class*="TableScroll"], ' +
      '[class*="table-scroll"], [class*="table_wrap"], [class*="table-wrap"] { ' +
      'overflow-x: auto !important; width: 100% !important; -webkit-overflow-scrolling: touch; }' +
      '}'
    );
  }

  function injectDesktopLayoutCss() {
    var head = document.head || document.documentElement;
    if (!head) {
      return;
    }

    var style = document.getElementById(LAYOUT_STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = LAYOUT_STYLE_ID;
      style.setAttribute('data-cursorpad', 'desktop-layout');
    }
    style.textContent = buildDesktopLayoutCss();
    head.appendChild(style);
  }

  function injectTouchPatchCss() {
    var head = document.head || document.documentElement;
    if (!head) {
      return;
    }

    var style = document.getElementById(TOUCH_STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = TOUCH_STYLE_ID;
      style.setAttribute('data-cursorpad', 'touch-patch');
      style.textContent =
        '*, *::before, *::after { touch-action: none !important; }' +
        'html { -webkit-text-size-adjust: 100% !important; text-size-adjust: 100% !important; }';
      head.appendChild(style);
    }
  }

  function applyDesktopLayoutFixes() {
    neutralizeMobileStylesheetLinks(document);
    injectDesktopLayoutCss();
    patchDocumentDimensions();
  }

  function patchTouchDetection() {
    window.ontouchstart = undefined;
    document.ontouchstart = undefined;
    injectTouchPatchCss();
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

  function installStylesheetGuard() {
    var pending = false;
    var observer = new MutationObserver(function (mutations) {
      if (pending) {
        return;
      }
      var shouldFix = false;
      for (var i = 0; i < mutations.length; i++) {
        var mutation = mutations[i];
        if (mutation.type !== 'childList') {
          continue;
        }
        for (var j = 0; j < mutation.addedNodes.length; j++) {
          var node = mutation.addedNodes[j];
          if (node.nodeType !== 1) {
            continue;
          }
          var tag = node.tagName;
          if (tag === 'LINK' || tag === 'STYLE') {
            shouldFix = true;
            break;
          }
        }
        if (shouldFix) {
          break;
        }
      }
      if (!shouldFix) {
        return;
      }
      pending = true;
      requestAnimationFrame(function () {
        pending = false;
        applyDesktopLayoutFixes();
      });
    });

    var target = document.head || document.documentElement;
    if (target) {
      observer.observe(target, { childList: true, subtree: true });
    }
  }

  function scheduleDesktopLayoutFixes() {
    applyDesktopLayoutFixes();
    document.addEventListener('DOMContentLoaded', applyDesktopLayoutFixes, {
      once: true,
    });
    window.addEventListener('load', applyDesktopLayoutFixes, { once: true });
  }

  updateViewportDimensions();
  patchScreenDimensions();
  patchMatchMedia();
  patchNavigator();
  patchUserAgentData();
  patchTouchDetection();
  scheduleDesktopLayoutFixes();

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
    installStylesheetGuard();
  } else {
    document.addEventListener(
      'DOMContentLoaded',
      function () {
        installViewportGuard();
        installStylesheetGuard();
      },
      { once: true },
    );
  }

  window.__cursorPadDesktop = {
    setViewportWidth: function (width, screenWidth, screenHeight) {
      VIEWPORT_WIDTH = Math.max(width, 1);
      if (screenWidth != null) {
        SCREEN_WIDTH = Math.max(screenWidth, 1);
      }
      if (
        screenHeight != null &&
        screenWidth != null &&
        screenWidth > 0
      ) {
        _heightRatio = screenHeight / screenWidth;
      }
      updateViewportDimensions();
      ensureViewportMeta();
      applyDesktopLayoutFixes();
    },
    zoomBy: zoomBy,
    resetUserScale: resetUserScale,
    getUserScale: function () {
      return USER_SCALE;
    },
  };
})();
