(function () {
  'use strict';

  var lastElement = null;
  var lastX = 0;
  var lastY = 0;
  var nativeWidth = 1;
  var nativeHeight = 1;
  var pointerId = 1;

  var ACTIONABLE_SELECTOR =
    'a[href], button, input, select, textarea, label, [role="button"], [role="link"], [onclick]';

  function toViewportCoords(nativeX, nativeY) {
    var x = (nativeX / nativeWidth) * window.innerWidth;
    var y = (nativeY / nativeHeight) * window.innerHeight;
    return { x: x, y: y };
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
      buttons: options.buttons != null ? options.buttons : (options.button === 0 ? 1 : 0),
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
    var buttons = options.buttons != null ? options.buttons : (button === 0 ? 1 : 0);

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

  function findActionableElement(el) {
    if (!el || !el.closest) {
      return el;
    }
    return el.closest(ACTIONABLE_SELECTOR) || el;
  }

  function activateElement(el) {
    if (!el) {
      return;
    }

    if (typeof el.click === 'function') {
      el.click();
      return;
    }

    var anchor = el.closest ? el.closest('a[href]') : null;
    if (anchor && anchor.href) {
      window.location.href = anchor.href;
    }
  }

  function dispatchHoverTransition(nextElement, x, y) {
    if (lastElement && lastElement !== nextElement) {
      lastElement.dispatchEvent(
        createMouseEvent('mouseout', lastX, lastY, { relatedTarget: nextElement }),
      );
      lastElement.dispatchEvent(
        createMouseEvent('mouseleave', lastX, lastY, { relatedTarget: nextElement }),
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

  function elementAt(x, y) {
    var el = document.elementFromPoint(x, y);
    if (!el) {
      return document.body || document.documentElement;
    }
    return el;
  }

  function dispatchClickSequence(actionable, x, y, options) {
    options = options || {};
    var button = options.button != null ? options.button : 0;
    var detail = options.detail || 1;
    var downButtons = button === 2 ? 2 : 1;
    var eventOptions = { button: button, detail: detail };

    actionable.dispatchEvent(
      createPointerEvent('pointerdown', x, y, {
        button: button,
        buttons: downButtons,
        detail: detail,
      }),
    );
    actionable.dispatchEvent(
      createMouseEvent('mousedown', x, y, {
        button: button,
        buttons: downButtons,
        detail: detail,
      }),
    );
    actionable.dispatchEvent(
      createPointerEvent('pointerup', x, y, {
        button: button,
        buttons: 0,
        detail: detail,
      }),
    );
    actionable.dispatchEvent(
      createMouseEvent('mouseup', x, y, { button: button, buttons: 0, detail: detail }),
    );
    actionable.dispatchEvent(createMouseEvent('click', x, y, eventOptions));
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

    click: function (button) {
      button = button == null ? 0 : button;
      var target = elementAt(lastX, lastY) || document.body;
      var actionable = findActionableElement(target) || target;

      dispatchClickSequence(actionable, lastX, lastY, { button: button });

      if (button === 0) {
        activateElement(actionable);
      } else if (button === 2) {
        actionable.dispatchEvent(
          createMouseEvent('contextmenu', lastX, lastY, { button: 2, buttons: 0 }),
        );
      }

      return {
        x: lastX,
        y: lastY,
        tag: target ? target.tagName : null,
        actionable: actionable ? actionable.tagName : null,
      };
    },

    doubleClick: function () {
      var target = elementAt(lastX, lastY) || document.body;
      var actionable = findActionableElement(target) || target;

      dispatchClickSequence(actionable, lastX, lastY, { button: 0, detail: 1 });
      dispatchClickSequence(actionable, lastX, lastY, { button: 0, detail: 2 });
      actionable.dispatchEvent(
        createMouseEvent('dblclick', lastX, lastY, { button: 0, detail: 2 }),
      );
      actionable.dispatchEvent(
        createPointerEvent('pointerdown', lastX, lastY, { button: 0, buttons: 1, detail: 2 }),
      );
      actionable.dispatchEvent(
        createPointerEvent('pointerup', lastX, lastY, { button: 0, buttons: 0, detail: 2 }),
      );

      return {
        x: lastX,
        y: lastY,
        tag: target ? target.tagName : null,
        actionable: actionable ? actionable.tagName : null,
      };
    },

    scroll: function (deltaX, deltaY) {
      var target = elementAt(lastX, lastY) || document.documentElement;
      var wheelEvent;

      try {
        wheelEvent = new WheelEvent('wheel', {
          bubbles: true,
          cancelable: true,
          view: window,
          clientX: lastX,
          clientY: lastY,
          deltaX: deltaX,
          deltaY: deltaY,
          deltaMode: 0,
        });
      } catch (e) {
        wheelEvent = document.createEvent('WheelEvent');
        wheelEvent.initWheelEvent(
          'wheel',
          true,
          true,
          window,
          0,
          lastX,
          lastY,
          lastX,
          lastY,
          false,
          false,
          false,
          false,
          deltaY,
          deltaX,
          deltaY,
          0,
        );
      }

      var consumed = target.dispatchEvent(wheelEvent);
      if (!consumed) {
        window.scrollBy(deltaX, deltaY);
      }
    },
  };
})();
