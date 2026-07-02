(function () {
  'use strict';

  var lastElement = null;
  var lastX = 0;
  var lastY = 0;
  var nativeWidth = 1;
  var nativeHeight = 1;
  var pointerId = 1;

  var ACTIONABLE_SELECTOR =
    'a[href], area[href], button, input, select, textarea, label, summary, ' +
    '[role="button"], [role="link"], [role="menuitem"], [role="tab"], ' +
    '[role="checkbox"], [role="radio"], [role="switch"], [role="option"], ' +
    '[aria-expanded], [tabindex]:not([tabindex="-1"]), [onclick]';

  var INTERACTIVE_ROLES = {
    button: 1,
    link: 1,
    menuitem: 1,
    tab: 1,
    checkbox: 1,
    radio: 1,
    switch: 1,
    option: 1,
    treeitem: 1,
    slider: 1,
  };

  function toViewportCoords(nativeX, nativeY) {
    var vv = window.visualViewport;
    if (vv) {
      return {
        x: (nativeX / nativeWidth) * vv.width + vv.offsetLeft,
        y: (nativeY / nativeHeight) * vv.height + vv.offsetTop,
      };
    }
    return {
      x: (nativeX / nativeWidth) * window.innerWidth,
      y: (nativeY / nativeHeight) * window.innerHeight,
    };
  }

  function createMouseEvent(type, x, y, options) {
    options = options || {};
    return new MouseEvent(type, {
      bubbles: true,
      cancelable: true,
      view: window,
      detail: options.detail || 1,
      screenX: x,
      screenY: y,
      clientX: x,
      clientY: y,
      button: options.button || 0,
      buttons:
        options.buttons != null
          ? options.buttons
          : options.button === 0
            ? 1
            : 0,
      ctrlKey: !!options.ctrlKey,
      shiftKey: !!options.shiftKey,
      altKey: !!options.altKey,
      metaKey: !!options.metaKey,
      relatedTarget: options.relatedTarget || null,
    });
  }

  function createPointerEvent(type, x, y, options) {
    options = options || {};
    var button = options.button != null ? options.button : 0;
    var buttons =
      options.buttons != null ? options.buttons : button === 0 ? 1 : 0;

    return new PointerEvent(type, {
      bubbles: true,
      cancelable: true,
      view: window,
      detail: options.detail || 1,
      screenX: x,
      screenY: y,
      clientX: x,
      clientY: y,
      button: button,
      buttons: buttons,
      pointerId: pointerId,
      pointerType: 'mouse',
      isPrimary: true,
      width: 1,
      height: 1,
      pressure: type === 'pointerup' ? 0 : 0.5,
      ctrlKey: !!options.ctrlKey,
      shiftKey: !!options.shiftKey,
      altKey: !!options.altKey,
      metaKey: !!options.metaKey,
    });
  }

  function isDisabled(el) {
    return !!el && (el.disabled || el.getAttribute('aria-disabled') === 'true');
  }

  function hasPointerCursor(el) {
    try {
      return window.getComputedStyle(el).cursor === 'pointer';
    } catch (e) {
      return false;
    }
  }

  function isNaturallyActivatable(el) {
    if (!el || isDisabled(el)) {
      return false;
    }

    var tag = el.tagName;
    if (
      tag === 'A' ||
      tag === 'BUTTON' ||
      tag === 'INPUT' ||
      tag === 'SELECT' ||
      tag === 'TEXTAREA' ||
      tag === 'SUMMARY' ||
      tag === 'LABEL' ||
      tag === 'AREA'
    ) {
      return true;
    }

    if (el.isContentEditable) {
      return true;
    }

    var role = el.getAttribute && el.getAttribute('role');
    if (role && INTERACTIVE_ROLES[role]) {
      return true;
    }

    if (el.onclick || el.getAttribute('onclick')) {
      return true;
    }

    var tabIndex = el.getAttribute('tabindex');
    return tabIndex !== null && tabIndex !== '-1';
  }

  function findActionableElement(el) {
    if (!el || !el.closest) {
      return el;
    }

    var bySelector = el.closest(ACTIONABLE_SELECTOR);
    if (bySelector && !isDisabled(bySelector)) {
      return bySelector;
    }

    var cur = el;
    var depth = 0;
    while (cur && cur !== document.documentElement && depth < 10) {
      if (isNaturallyActivatable(cur)) {
        return cur;
      }
      if (depth > 0 && hasPointerCursor(cur)) {
        return cur;
      }
      cur = cur.parentElement;
      depth++;
    }

    return el;
  }

  function isToggleLikeElement(el) {
    if (!el || isDisabled(el)) {
      return false;
    }

    if (el.tagName === 'SUMMARY') {
      return true;
    }

    if (el.hasAttribute('aria-expanded') || el.hasAttribute('aria-controls')) {
      return true;
    }

    var role = el.getAttribute && el.getAttribute('role');
    if (role === 'button' && el.hasAttribute('aria-expanded')) {
      return true;
    }

    return false;
  }

  function isFormControl(el) {
    if (!el) {
      return false;
    }
    var tag = el.tagName;
    return (
      tag === 'INPUT' ||
      tag === 'TEXTAREA' ||
      tag === 'SELECT' ||
      el.isContentEditable
    );
  }

  function shouldProgrammaticActivate(el, button) {
    if (button !== 0 || !el || isDisabled(el)) {
      return false;
    }
    if (isToggleLikeElement(el)) {
      return false;
    }
    if (findAnchor(el)) {
      return true;
    }
    if (isFormControl(el)) {
      return true;
    }
    if (el.tagName === 'LABEL') {
      return true;
    }
    return false;
  }

  function isPointerEventsNone(el) {
    if (!el || el === document.documentElement || el === document.body) {
      return false;
    }
    try {
      return window.getComputedStyle(el).pointerEvents === 'none';
    } catch (e) {
      return false;
    }
  }

  function hitTestInRoot(x, y, root) {
    if (!root) {
      return null;
    }

    var elements;
    try {
      if (root.elementsFromPoint) {
        elements = root.elementsFromPoint(x, y);
      } else if (root.elementFromPoint) {
        elements = [root.elementFromPoint(x, y)];
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }

    if (!elements || !elements.length) {
      return null;
    }

    for (var i = 0; i < elements.length; i++) {
      var el = elements[i];
      if (!el || el === document.documentElement) {
        continue;
      }

      if (isPointerEventsNone(el)) {
        continue;
      }

      if (el.tagName === 'IFRAME') {
        var inner = hitTestIframe(el, x, y);
        if (inner) {
          return inner;
        }
        continue;
      }

      if (el.shadowRoot) {
        var shadowHit = hitTestInRoot(x, y, el.shadowRoot);
        if (shadowHit) {
          return shadowHit;
        }
      }

      return el;
    }

    return null;
  }

  function hitTestIframe(iframe, x, y) {
    try {
      var rect = iframe.getBoundingClientRect();
      var doc = iframe.contentDocument;
      if (!doc) {
        return null;
      }
      return hitTestInRoot(x - rect.left, y - rect.top, doc);
    } catch (e) {
      return null;
    }
  }

  function elementAt(x, y) {
    var el = hitTestInRoot(x, y, document);
    if (!el) {
      return document.body || document.documentElement;
    }
    return el;
  }

  function getScrollAxes(el) {
    if (!el || el === document.documentElement) {
      return { x: false, y: false };
    }
    try {
      var style = window.getComputedStyle(el);
      var overflowY = style.overflowY;
      var overflowX = style.overflowX;
      return {
        y:
          (overflowY === 'auto' ||
            overflowY === 'scroll' ||
            overflowY === 'overlay') &&
          el.scrollHeight > el.clientHeight,
        x:
          (overflowX === 'auto' ||
            overflowX === 'scroll' ||
            overflowX === 'overlay') &&
          el.scrollWidth > el.clientWidth,
      };
    } catch (e) {
      return { x: false, y: false };
    }
  }

  function isHorizontalPrimaryScroller(el) {
    if (
      el.hasAttribute &&
      el.hasAttribute('data-cursorpad-table-scroll')
    ) {
      return true;
    }
    try {
      var style = window.getComputedStyle(el);
      var overflowX = style.overflowX;
      var canScrollX =
        (overflowX === 'auto' ||
          overflowX === 'scroll' ||
          overflowX === 'overlay') &&
        el.scrollWidth > el.clientWidth + 1;
      if (!canScrollX) {
        return false;
      }
      var overflowY = style.overflowY;
      var canScrollY =
        (overflowY === 'auto' ||
          overflowY === 'scroll' ||
          overflowY === 'overlay') &&
        el.scrollHeight > el.clientHeight + 1;
      if (!canScrollY) {
        return true;
      }
      return (
        el.scrollWidth - el.clientWidth >
        el.scrollHeight - el.clientHeight
      );
    } catch (e) {
      return false;
    }
  }

  function findScrollableAt(x, y, axis) {
    var el = elementAt(x, y);
    while (el && el !== document.documentElement) {
      var axes = getScrollAxes(el);
      if (axis === 'y' && axes.y && !isHorizontalPrimaryScroller(el)) {
        return el;
      }
      if (axis === 'x' && axes.x) {
        return el;
      }
      el = el.parentElement;
    }
    if (axis === 'y') {
      return document.scrollingElement || document.documentElement;
    }
    return null;
  }

  function findAnchor(el) {
    if (!el) {
      return null;
    }
    if (el.tagName === 'A' && el.getAttribute('href') != null) {
      return el;
    }
    return el.closest ? el.closest('a[href]') : null;
  }

  function followAnchor(anchor) {
    var href = anchor.getAttribute('href');
    if (!href || href === '#') {
      if (typeof anchor.click === 'function') {
        anchor.click();
      }
      return;
    }

    var resolved = anchor.href;
    var target = anchor.getAttribute('target');

    if (target === '_blank') {
      window.open(resolved, '_blank', 'noopener,noreferrer');
      return;
    }

    if (target && target !== '_self') {
      window.open(resolved, target);
      return;
    }

    window.location.href = resolved;
  }

  function activateElement(el) {
    if (!el || isDisabled(el)) {
      return;
    }

    var anchor = findAnchor(el);
    if (anchor) {
      followAnchor(anchor);
      return;
    }

    if (el.tagName === 'LABEL') {
      var forId = el.getAttribute('for');
      if (forId) {
        var linked = document.getElementById(forId);
        if (linked && !isDisabled(linked)) {
          linked.focus();
          if (typeof linked.click === 'function') {
            linked.click();
          }
          return;
        }
      }
    }

    if (
      el.tagName === 'INPUT' ||
      el.tagName === 'TEXTAREA' ||
      el.tagName === 'SELECT'
    ) {
      el.focus();
      if (typeof el.click === 'function') {
        el.click();
      }
      return;
    }

    if (typeof el.click === 'function') {
      el.click();
    }
  }

  function dispatchHoverTransition(nextElement, x, y) {
    if (lastElement && lastElement !== nextElement) {
      lastElement.dispatchEvent(
        createMouseEvent('mouseout', lastX, lastY, {
          relatedTarget: nextElement,
        }),
      );
      lastElement.dispatchEvent(
        createMouseEvent('mouseleave', lastX, lastY, {
          relatedTarget: nextElement,
        }),
      );
    }

    if (nextElement && nextElement !== lastElement) {
      nextElement.dispatchEvent(
        createMouseEvent('mouseover', x, y, { relatedTarget: lastElement }),
      );
      nextElement.dispatchEvent(
        createMouseEvent('mouseenter', x, y, { relatedTarget: lastElement }),
      );
    }
  }

  function dispatchClickSequence(target, x, y, options) {
    options = options || {};
    var button = options.button != null ? options.button : 0;
    var detail = options.detail || 1;
    var downButtons = button === 2 ? 2 : 1;
    var eventOptions = { button: button, detail: detail };

    target.dispatchEvent(
      createPointerEvent('pointerdown', x, y, {
        button: button,
        buttons: downButtons,
        detail: detail,
      }),
    );
    target.dispatchEvent(
      createMouseEvent('mousedown', x, y, {
        button: button,
        buttons: downButtons,
        detail: detail,
      }),
    );
    target.dispatchEvent(
      createPointerEvent('pointerup', x, y, {
        button: button,
        buttons: 0,
        detail: detail,
      }),
    );
    target.dispatchEvent(
      createMouseEvent('mouseup', x, y, {
        button: button,
        buttons: 0,
        detail: detail,
      }),
    );
    target.dispatchEvent(createMouseEvent('click', x, y, eventOptions));
  }

  window.__cursorPad = {
    setNativeSize: function (width, height) {
      nativeWidth = Math.max(width, 1);
      nativeHeight = Math.max(height, 1);
    },

    moveTo: function (nativeX, nativeY) {
      var coords = toViewportCoords(nativeX, nativeY);
      var x = coords.x;
      var y = coords.y;
      var target = elementAt(x, y);

      dispatchHoverTransition(target, x, y);

      if (target) {
        target.dispatchEvent(createMouseEvent('mousemove', x, y));
      }

      lastElement = target;
      lastX = x;
      lastY = y;

      return { x: x, y: y, tag: target ? target.tagName : null };
    },

    click: function (button, nativeX, nativeY) {
      button = button == null ? 0 : button;
      if (nativeX != null && nativeY != null) {
        this.moveTo(nativeX, nativeY);
      }
      var target = elementAt(lastX, lastY) || document.body;
      var actionable = findActionableElement(target) || target;

      dispatchClickSequence(actionable, lastX, lastY, { button: button });

      if (button === 0 && shouldProgrammaticActivate(actionable, button)) {
        activateElement(actionable);
      } else if (button === 2) {
        (actionable || target).dispatchEvent(
          createMouseEvent('contextmenu', lastX, lastY, {
            button: 2,
            buttons: 0,
          }),
        );
      }

      return {
        x: lastX,
        y: lastY,
        tag: target ? target.tagName : null,
        actionable: actionable ? actionable.tagName : null,
      };
    },

    activateAt: function (nativeX, nativeY) {
      if (nativeX != null && nativeY != null) {
        this.moveTo(nativeX, nativeY);
      }
      var target = elementAt(lastX, lastY) || document.body;
      var actionable = findActionableElement(target);
      if (!actionable) {
        return { needsIme: false };
      }
      var tag = actionable.tagName;
      var needsIme =
        tag === 'INPUT' ||
        tag === 'TEXTAREA' ||
        tag === 'SELECT' ||
        actionable.isContentEditable;
      return { needsIme: needsIme, tag: tag };
    },

    doubleClick: function (nativeX, nativeY) {
      if (nativeX != null && nativeY != null) {
        this.moveTo(nativeX, nativeY);
      }
      var target = elementAt(lastX, lastY) || document.body;
      var actionable = findActionableElement(target) || target;

      dispatchClickSequence(actionable, lastX, lastY, { button: 0, detail: 1 });
      dispatchClickSequence(actionable, lastX, lastY, { button: 0, detail: 2 });
      actionable.dispatchEvent(
        createMouseEvent('dblclick', lastX, lastY, { button: 0, detail: 2 }),
      );
      actionable.dispatchEvent(
        createPointerEvent('pointerdown', lastX, lastY, {
          button: 0,
          buttons: 1,
          detail: 2,
        }),
      );
      actionable.dispatchEvent(
        createPointerEvent('pointerup', lastX, lastY, {
          button: 0,
          buttons: 0,
          detail: 2,
        }),
      );

      return {
        x: lastX,
        y: lastY,
        tag: target ? target.tagName : null,
        actionable: actionable ? actionable.tagName : null,
      };
    },

    scroll: function (deltaX, deltaY) {
      var absX = Math.abs(deltaX);
      var absY = Math.abs(deltaY);
      if (absX === 0 && absY === 0) {
        return;
      }

      // Lock to the dominant axis so incidental cross-axis deltas from
      // touchpads do not scroll nested overflow-x regions.
      if (absY >= absX) {
        deltaX = 0;
      } else {
        deltaY = 0;
      }

      var verticalScrollable =
        deltaY !== 0 ? findScrollableAt(lastX, lastY, 'y') : null;
      var horizontalScrollable =
        deltaX !== 0 ? findScrollableAt(lastX, lastY, 'x') : null;

      if (verticalScrollable) {
        verticalScrollable.scrollTop += deltaY;
      }
      if (horizontalScrollable) {
        horizontalScrollable.scrollLeft += deltaX;
      }
    },
  };
})();
