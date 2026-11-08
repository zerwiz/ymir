/**
 * The measurement itself, run inside the page after the panel has painted.
 *
 * Two questions are asked of every element in the probe root, because the
 * reported symptom ("some of the text are going outside the view to the right")
 * has two distinct causes:
 *
 *   1. CROSSES — the element's right edge is past the right edge of the nearest
 *      ancestor that HIDES what overflows it (`overflow: hidden | clip`). Either
 *      the pane refused to shrink (`min-width: auto`) or something inside it is
 *      wider than the window. A scroll container is not an offence: content
 *      wider than a `overflow: auto` box is content that can be scrolled to, and
 *      that is the behaviour a code block is supposed to have.
 *   2. WIDER — the element's own content is wider than its box and it does not
 *      scroll horizontally. This is the prose that is cut off rather than
 *      scrolled, and it is invisible to a viewport-level scrollbar check.
 *
 * Only the OUTERMOST offender of a subtree is reported: every descendant of a
 * pane that refused to shrink is wide for that one reason, and a table of forty
 * symptoms that all say "the message column is 1024px" is harder to act on than
 * the one line that says it.
 *
 * A <pre>, a `.overflow-x-auto` and an <img> are allowed to be wider: a code
 * block scrolls inside itself on purpose. Everything else that overflows is
 * reported.
 *
 * The result is written into `<pre id="probe-result">` as JSON, which is what
 * `chromium --dump-dom` hands back to the runner.
 */
;(function measure(global) {
  var EPSILON = 0.5

  function isScroller(style) {
    var x = style.overflowX
    return x === 'auto' || x === 'scroll' || x === 'hidden' || x === 'clip'
  }

  /**
   * Is this box ALLOWED to hold content wider than itself?
   *
   * A code block and a table wrapper scroll sideways on purpose. A pane's
   * vertical scroller is not that: `overflow-y: auto` computes `overflow-x` to
   * `auto` as well, so the message list silently becomes a sideways scroller the
   * moment its content outgrows it — which is exactly the symptom this probe
   * exists to catch, and exactly why "it has a scroll container" is not the same
   * answer as "it may overflow".
   */
  function allowsOverflow(clip) {
    if (clip === document.documentElement) return true // the page is judged by pageOverflow
    var style = getComputedStyle(clip)
    if (style.overflowX !== 'auto' && style.overflowX !== 'scroll') return false
    if (clip.matches('pre, .overflow-x-auto, .overflow-auto, textarea, input')) return true
    // A deliberate horizontal-only scroller (a strip of buttons, a tab bar).
    return style.overflowY === 'hidden'
  }

  function clipsItself(el) {
    return el.matches('pre, .overflow-x-auto, .overflow-auto, img, canvas, textarea, input')
  }

  function path(el) {
    var parts = []
    var node = el
    while (node && node !== null && node.nodeType === 1 && parts.length < 4) {
      var name = node.tagName.toLowerCase()
      if (node.id) name += '#' + node.id
      var cls = (node.getAttribute('class') || '').trim().split(/\s+/).filter(Boolean).slice(0, 3)
      if (cls.length) name += '.' + cls.join('.')
      parts.unshift(name)
      node = node.parentElement
      if (node && node.id === 'probe-root') {
        parts.unshift('#probe-root')
        break
      }
    }
    return parts.join(' > ')
  }

  function clippingAncestor(el) {
    var node = el.parentElement
    while (node && node.nodeType === 1) {
      if (node.id === 'probe-root') return node
      if (isScroller(getComputedStyle(node))) return node
      node = node.parentElement
    }
    return document.documentElement
  }

  function round(n) {
    return Math.round(n * 100) / 100
  }

  function run() {
    var root = document.getElementById('probe-root')
    if (!root) {
      return { error: 'probe-root missing' }
    }

    var rootRect = root.getBoundingClientRect()
    var crosses = []
    var wider = []
    var reported = new Set()
    var reportedWider = new Set()
    var all = root.querySelectorAll('*')

    function alreadyReported(el, list) {
      var node = el.parentElement
      while (node && node.nodeType === 1) {
        if (list.has(node)) return true
        node = node.parentElement
      }
      return false
    }

    for (var i = 0; i < all.length; i += 1) {
      var el = all[i]
      if (el.closest('svg')) continue // icon geometry, not layout
      var style = getComputedStyle(el)
      if (style.display === 'none') continue
      var rect = el.getBoundingClientRect()
      if (rect.width === 0 && rect.height === 0) continue

      var clip = clippingAncestor(el)
      var clipRect = clip.getBoundingClientRect()
      if (
        !allowsOverflow(clip) &&
        rect.right > clipRect.right + EPSILON &&
        !alreadyReported(el, reported)
      ) {
        reported.add(el)
        crosses.push({
          el: path(el),
          clip: path(clip),
          over: round(rect.right - clipRect.right),
          width: round(rect.width),
          clipWidth: round(clipRect.width),
        })
      }

      // Content wider than a box that is allowed to scroll is content that can be
      // scrolled to; only content that is neither wrapped nor scrollable is cut.
      var scrolls =
        isScroller(style) || clipsItself(el) || style.display === 'inline' || allowsOverflow(clip)
      if (
        !scrolls &&
        el.scrollWidth > el.clientWidth + EPSILON &&
        el.clientWidth > 0 &&
        !alreadyReported(el, reportedWider) &&
        !alreadyReported(el, reported)
      ) {
        reportedWider.add(el)
        wider.push({
          el: path(el),
          over: round(el.scrollWidth - el.clientWidth),
          clientWidth: round(el.clientWidth),
        })
      }
    }

    var doc = document.scrollingElement || document.documentElement
    // The chain a reader actually sees, so a number in the table can be traced
    // to the box that produced it.
    var boxes = []
    ;['#probe-root', '.chat-center', '.markdown-body', 'pre', 'textarea'].forEach(function (selector) {
      var node = document.querySelector(selector)
      if (!node) return
      var box = node.getBoundingClientRect()
      boxes.push({
        el: selector,
        width: round(box.width),
        right: round(box.right),
        scrollWidth: node.scrollWidth,
      })
    })
    var composerText = document.querySelector('#probe-root textarea')
    var composer = composerText
      ? composerText.closest('.composer-shell') ||
        composerText.closest('.rounded-2xl') ||
        composerText.parentElement
      : null
    var composerFacts = null
    if (composer) {
      var composerRect = composer.getBoundingClientRect()
      var lineHeight = composerText
        ? parseFloat(getComputedStyle(composerText).lineHeight) || 0
        : 0
      composerFacts = {
        width: round(composerRect.width),
        height: round(composerRect.height),
        lines: composerText && lineHeight ? round(composerText.clientHeight / lineHeight) : null,
        textOverflow: composerText ? round(composerText.scrollWidth - composerText.clientWidth) : null,
      }
    }

    return {
      viewportWidth: global.innerWidth,
      rootWidth: round(rootRect.width),
      paneWidth: root.dataset.pane ? Number(root.dataset.pane) : null,
      pageOverflow: round(doc.scrollWidth - doc.clientWidth),
      boxes: boxes,
      crosses: crosses,
      wider: wider,
      composer: composerFacts,
    }
  }

  function publish() {
    var payload
    try {
      payload = run()
    } catch (error) {
      payload = { error: String(error && error.message ? error.message : error) }
    }
    var sink = document.getElementById('probe-result')
    if (!sink) return
    sink.textContent = JSON.stringify(payload)
  }

  // Fonts decide the wrap; measure the faces the app actually ships.
  var ready = document.fonts && document.fonts.ready ? document.fonts.ready : Promise.resolve()
  ready.then(function () {
    requestAnimationFrame(function () {
      requestAnimationFrame(publish)
    })
  })
})(window)
