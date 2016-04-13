vexFactory = ($) ->

    animationEndSupport = false

    # Detect CSS Animation Support

    s = (document.body || document.documentElement).style
    animationEndSupport = s.animation isnt undefined or s.WebkitAnimation isnt undefined or s.MozAnimation isnt undefined or s.MsAnimation isnt undefined or s.OAnimation isnt undefined

    # Register global handler for ESC

    window.addEventListener 'keyup', (event) ->
        vex.closeByEscape() if event.keyCode is 27

    # Vex

    triggerCustom = (el, evtName, data) ->
        if window.CustomEvent
            event = new CustomEvent evtName, {detail: data}
        else
            event = document.createEvent('CustomEvent')
            event.initCustomEvent evtName, true, true, data
        el.dispatchEvent event

    addClass = (el, spaceSeparatedClassList) ->
      if spaceSeparatedClassList
        spaceSeparatedClassList.split(/\s+/).map (cls) ->
            el.classList.add cls

    vex =

        globalID: 1

        textToDOM: (htmlString) ->
            # wrap text in a div to take advantage of innerHTML converting it
            # to DOM
            div = document.createElement('div')
            div.innerHTML = htmlString
            children = div.children.length
            return div.children[0] if children == 1
            return div

        # simulate jquery's extend
        extend: (out) ->
            out = out || {};
            for i in [1...arguments.length]
                continue if not arguments[i]
                for key of arguments[i]
                    out[key] = arguments[i][key]
            out

        animationEndEvent: 'animationend webkitAnimationEnd mozAnimationEnd MSAnimationEnd oanimationend' # Inconsistent casings are intentional http://stackoverflow.com/a/12958895/131898

        # store each vex's options in this hash
        optionsHash: {}

        baseClassNames:
            vex: 'vex'
            content: 'vex-content'
            overlay: 'vex-overlay'
            close: 'vex-close'
            closing: 'vex-closing'
            open: 'vex-open'

        defaultOptions:
            content: ''
            showCloseButton: true
            escapeButtonCloses: true
            overlayClosesOnClick: true
            appendLocation: 'body'
            className: ''
            css: {}
            overlayClassName: ''
            overlayCSS: {}
            contentClassName: ''
            contentCSS: {}
            closeClassName: ''
            closeCSS: {}

        open: (options) ->
            options = vex.extend {}, vex.defaultOptions, options

            options.id = vex.globalID
            vex.globalID += 1
            vex.optionsHash[options.id] = options

            # Vex

            options.$vex = document.createElement 'div'
            addClass options.$vex, vex.baseClassNames.vex
            addClass options.$vex, options.className
            options.$vex.setAttribute "data-vex-id", options.id

            # Overlay

            options.$vexOverlay = document.createElement 'div'
            addClass options.$vexOverlay, vex.baseClassNames.overlay
            addClass options.$vexOverlay, options.overlayClassName
            options.$vexOverlay.setAttribute "data-vex-id", options.id

            if options.overlayClosesOnClick
                options.$vexOverlay.addEventListener 'click', (e) ->
                    return unless e.target is @
                    vex.close options.id

            options.$vex.appendChild options.$vexOverlay

            # Content

            options.$vexContent = document.createElement 'div'
            addClass options.$vexContent, vex.baseClassNames.content
            addClass options.$vexContent, options.contentClassName
            options.$vexContent.setAttribute "data-vex-id", options.id
            options.$vexContent.appendChild options.content

            options.$vex.appendChild options.$vexContent

            # Close button

            if options.showCloseButton
                options.$closeButton = document.createElement 'div'
                addClass options.$closeButton, vex.baseClassNames.close
                addClass options.$closeButton, options.closeClassName
                options.$closeButton.setAttribute "data-vex-id", options.id
                options.$closeButton.addEventListener 'click', (event) -> vex.close event.target.getAttribute "data-vex-id"

                options.$vexContent.appendChild options.$closeButton

            # Inject DOM and trigger callbacks/events

            document.querySelector(options.appendLocation).appendChild(options.$vex)

            # Set up body className

            vex.setupBodyClassName options.$vex

            # Call afterOpen callback and trigger vexOpen event

            options.afterOpen options.$vexContent, options if options.afterOpen
            setTimeout (-> triggerCustom options.$vexContent, 'vexOpen', options), 0

            return options.$vexContent # For chaining

        getSelectorFromBaseClass: (baseClass) ->
            return ".#{baseClass.split(' ').join('.')}"

        getAllVexes: ->
            vexes = Array.prototype.filter.call(
                document.querySelectorAll("."+vex.baseClassNames.vex),
                (el) ->
                    if el.classList.contains(vex.baseClassNames.closing)
                        return false
                    return true
            )
            selector = vex.getSelectorFromBaseClass(vex.baseClassNames.content)
            return vexes.map( (vex) ->
                return vex.querySelector( selector )
                )

        getOptionsById: (id) ->
            return vex.optionsHash[id]

        getVexId: (el) ->
            if el == document.body
                throw "getVexId: could not get vex id"
            id = el.getAttribute("data-vex-id")
            return vex.getVexId(el.parentNode) if !id
            return id

        getVexByID: (id) ->
            vexes = vex.getAllVexes().filter (el) ->
                return Number(el.getAttribute("data-vex-id")) == Number(id)
            if vexes.length
                return vexes.shift()
            return null

        close: (id) ->
            if not id
                vexes = vex.getAllVexes
                return false if not vexes.length
                id = vexes.pop().getAttribute("data-vex-id")
            return vex.closeByID id

        closeByID: (id) ->
            options = vex.getOptionsById(id)
            $vexContent = vex.getVexByID(id)
            return if not $vexContent
            $vex = $vexContent.parentNode
            beforeClose = ->
                if options.beforeClose
                    options.beforeClose($vexContent, options)
            close = ->
                return unless id of vex.optionsHash
                delete vex.optionsHash[id]
                triggerCustom($vexContent, 'vexClose', options)
                $vex.parentNode.removeChild($vex)
                triggerCustom(document.body, 'vexAfterClose', options)
                options.afterClose($vexContent, options) if options.afterClose

            hasAnimation = $vexContent.style.animationName != 'none' && $vexContent.style.animationDuration != '0s';
            if animationEndSupport && hasAnimation
                if beforeClose() != false
                    $vex.classList.add vex.baseClassNames.closing
                    vex.animationEndEvent.split(/\s+/).map( (evtName) ->
                        $vex.addEventListener(evtName, (event) ->
                            close()
                        )
                    )
            else
                if beforeClose() != false
                    close()
            return true

        closeByEscape: ->
            ids = vex.getAllVexes().map( (el) ->
                return el.getAttribute('data-vex-id')
            )
            return if not ids or not ids.length
            id = Math.max.apply(Math,ids)
            $lastVex = vex.getVexByID(id)
            options = vex.getOptionsById(id)
            return if not options.escapeButtonCloses
            return vex.closeByID(id)

        setupBodyClassName: ($vex) ->
            body = document.body
            body.addEventListener('vexOpen', -> body.classList.add(vex.baseClassNames.open))
            body.addEventListener('vexAfterClose', -> body.classList.remove(vex.baseClassNames.open) unless vex.getAllVexes().length)


if typeof define is 'function' and define.amd
    # AMD
    define vexFactory
else if typeof exports is 'object'
    # CommonJS
    module.exports = vexFactory()
else
    # Global
    window.vex = vexFactory()
