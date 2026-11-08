/**
 * The page-side edge of the width probe: `window.piDesktop`, which the shipping
 * window gets from the preload bridge and a headless page does not have.
 *
 * It answers every path with an empty result instead of throwing, so a panel that
 * asks the engine for something renders its empty state rather than an error —
 * the probe is measuring layout, never behaviour.
 */
;(function piDesktopStub(global) {
  function empty() {
    var p = new Proxy(function () {}, handler)
    return p
  }
  var handler = {
    get: function (target, prop) {
      if (prop === 'then') return undefined // never a promise by accident
      if (prop === 'toJSON') return function () { return {} }
      if (prop === Symbol.toPrimitive) return function () { return '' }
      if (prop === 'length') return 0
      if (prop === Symbol.iterator) return function () { return [][Symbol.iterator]() }
      return empty()
    },
    apply: function () {
      return Promise.resolve(empty())
    },
  }

  var desktop = empty()
  global.piDesktop = desktop

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
        dispatchEvent: function () { return false },
      }
    }
})(window)
