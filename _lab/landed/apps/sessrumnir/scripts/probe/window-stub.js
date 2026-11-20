/**
 * The page-side edge of the width probe: `window.piDesktop`, which the shipping
 * window gets from the preload bridge and a headless page does not have.
 *
 * It answers every path instead of throwing, because the probe is measuring
 * layout, never behaviour — a panel that asks the engine for a file list should
 * render its empty state, not an error. Two shapes are needed, and both matter:
 *
 *   · a value that can be CALLED (an unsubscribe handle, a listener) and has
 *     properties (`.length`, iteration) — the leaf;
 *   · a value that can be AWAITED — every bridge call — which resolves to a leaf.
 *
 * A page that throws while mounting would otherwise measure an empty root and
 * report a clean layout, so any failure is collected and reported with the
 * measurement rather than swallowed.
 */
;(function piDesktopStub(global) {
  function makeLeaf() {
    var leaf = new Proxy(function () {}, {
      get: function (target, prop) {
        if (prop === 'then') return undefined // a leaf is not thenable
        if (prop === Symbol.toPrimitive) return function () { return '' }
        if (prop === 'toJSON') return function () { return {} }
        if (prop === 'length') return 0
        if (prop === Symbol.iterator) return function () { return [][Symbol.iterator]() }
        return leaf
      },
      apply: function () {
        return leaf
      },
    })
    return leaf
  }

  var leaf = makeLeaf()

  var HANDLE = /^(watch|unwatch|subscribe|unsubscribe|on[A-Z]|add[A-Z])/

  /**
   * A node of the bridge tree: callable (so `files.search()` works), navigable (so
   * `system.getPath` is a node too), and awaited like a call. A node whose own name
   * reads like a subscription hands back a callable handle instead of a promise,
   * because the renderer keeps that result and calls it on unmount.
   */
  function makeNode(name) {
    var node = new Proxy(function () {}, {
      get: function (target, prop) {
        if (prop === 'then') return undefined
        if (typeof prop === 'symbol') return undefined
        if (prop === 'toJSON') return function () { return {} }
        return makeNode(String(prop))
      },
      apply: function () {
        return HANDLE.test(name) ? leaf : Promise.resolve(leaf)
      },
    })
    return node
  }

  var bridge = makeNode('piDesktop')

  global.piDesktop = bridge

  global.__probeErrors = []
  function record(message) {
    global.__probeErrors.push(String(message))
  }
  global.addEventListener('error', function (event) {
    record(event.message || (event.error && event.error.stack) || 'script error')
  })
  global.addEventListener('unhandledrejection', function (event) {
    record('unhandled rejection: ' + String((event.reason && event.reason.message) || event.reason))
  })

  // The renderer's theme and layout hooks ask these directly.
  global.matchMedia =
    global.matchMedia ||
    function (query) {
      return {
        matches: false,
        media: query,
        onchange: null,
        addEventListener: function () {},
        removeEventListener: function () {},
        addListener: function () {},
        removeListener: function () {},
        dispatchEvent: function () {
          return false
        },
      }
    }
})(window)
