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
    var pageErrors = (global.__probeErrors || []).slice()

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

    // The two behaviours the fix is supposed to produce, stated as numbers: the
    // prose wraps (its box is as wide as its pane, its height is more than one
    // line, its content is not wider than the box) and the code block scrolls
    // inside itself instead of widening the column.
    var proseNode = document.querySelector('#probe-root .markdown-body p')
    var prose = null
    if (proseNode) {
      var proseStyle = getComputedStyle(proseNode)
      var proseLineHeight = parseFloat(proseStyle.lineHeight) || 0
      prose = {
        width: round(proseNode.getBoundingClientRect().width),
        lines: proseLineHeight ? round(proseNode.getBoundingClientRect().height / proseLineHeight) : null,
        contentOverflow: round(proseNode.scrollWidth - proseNode.clientWidth),
      }
    }
    var preNode = document.querySelector('#probe-root pre')
    var code = null
    if (preNode) {
      code = {
        width: round(preNode.clientWidth),
        contentWidth: round(preNode.scrollWidth),
        scrolls: preNode.scrollWidth > preNode.clientWidth + EPSILON,
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
        // Its own rows, so "one line" can be read off the parts rather than
        // inferred from a total height.
        parts: Array.prototype.filter
          .call(composer.children, function (child) {
            return getComputedStyle(child).display !== 'none'
          })
          .map(function (child) {
            var r = child.getBoundingClientRect()
            return {
              el: child.tagName.toLowerCase() + '.' + (child.getAttribute('class') || '').split(' ')[0],
              width: round(r.width),
              height: round(r.height),
              contentOverflow: round(child.scrollWidth - child.clientWidth),
            }
          }),
      }
    }

    // What the side panel did with the room it had, and what it says about it.
    var panelNode = document.querySelector('#probe-root [data-side-panel]')
    var fitNode = document.querySelector('#probe-root [data-panel-fit]')
    var panel = {
      drawn: Boolean(panelNode),
      fit: panelNode ? panelNode.getAttribute('data-side-panel') : null,
      width: panelNode ? round(panelNode.getBoundingClientRect().width) : 0,
      // The sentence the toolbar shows, so "says whether it shrank or closed" is
      // checked as text and not as intent.
      says: fitNode ? fitNode.textContent.trim() : null,
    }

    return {
      pageErrors: pageErrors,
      viewportWidth: global.innerWidth,
      rootWidth: round(rootRect.width),
      paneWidth: root.dataset.pane ? Number(root.dataset.pane) : null,
      pageOverflow: round(doc.scrollWidth - doc.clientWidth),
      boxes: boxes,
      crosses: crosses,
      wider: wider,
      prose: prose,
      code: code,
      panel: panel,
      composer: composerFacts,
    }
  }

  /**
   * Publish what is on screen right now.
   *
   * Called once as soon as the panel exists and again after the faces have
   * loaded, because a headless dump can beat a later measurement to the DOM: a
   * report that arrives is worth more than a perfect one that never does. The
   * `settled` flag says which publish this was, so a caller can insist on the
   * final one instead of trusting an early reading.
   */
  function publish(settled) {
    var payload
    try {
      payload = run()
    } catch (error) {
      payload = { error: String(error && error.message ? error.message : error) }
    }
    payload.settled = Boolean(settled)
    var sink = document.getElementById('probe-result')
    if (!sink) return
    sink.textContent = JSON.stringify(payload)
  }

  // React's first render is scheduled, not synchronous, so measuring on `load`
  // would sometimes catch an empty root and report a layout that is not there.
  // Wait for the chat column to exist, then for the faces the app ships (the wrap
  // depends on them), then publish.
  function waitForChat(remaining) {
    if (document.querySelector('#probe-root .chat-center')) return Promise.resolve()
    if (remaining <= 0) return Promise.resolve()
    return new Promise(function (resolve) {
      requestAnimationFrame(function () {
        resolve(waitForChat(remaining - 1))
      })
    })
  }

  // A font that never settles must not hold the measurement hostage: the wrap is
  // decided by the faces that did load, and a report is worth more than a perfect
  // one that never arrives.
  function withTimeout(promise, ms) {
    return Promise.race([
      promise,
      new Promise(function (resolve) {
        setTimeout(resolve, ms)
      }),
    ])
  }

  function whenPainted() {
    var fonts = document.fonts && document.fonts.ready ? document.fonts.ready : Promise.resolve()
    return withTimeout(fonts, 1500).then(function () {
      return new Promise(function (resolve) {
        requestAnimationFrame(function () {
          requestAnimationFrame(resolve)
        })
      })
    })
  }

  waitForChat(90).then(function () {
    publish(false)
    return whenPainted()
  }).then(function () {
    publish(true)
  })
})(window)
