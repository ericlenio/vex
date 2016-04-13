vexDialogFactory = (vex) ->

    throw 'Vex is required to use vex.dialog' unless vex

    $formToObject = ($form) ->
        object = {}
        Array.prototype.map.call( $form.elements, (field, index) ->
            type = field.type
            name = field.name
            nodeName = field.nodeName.toLowerCase()
            return if not name or nodeName == 'fieldset' or field.disabled or type == 'submit' or type == 'reset' or type == 'button' or type == 'file'
            return if (type == 'radio' or type == 'checkbox') and not field.checked
            value = field.value
            if object[name]
                object[name] = [object[name]] if !object[name].push
                object[name].push(value || '')
            else
                object[name] = value || '';
            )
        object

    dialog = {}

    dialog.buttons =

        YES:
            text: 'OK'
            type: 'submit'
            className: 'vex-dialog-button-primary'

        NO:
            text: 'Cancel'
            type: 'button'
            className: 'vex-dialog-button-secondary'
            click: (id, event) ->
                options = vex.getOptionsById(id)
                options.value = false
                vex.close id

    dialog.defaultOptions =
        callback: (value) ->
        afterOpen: ->
        message: 'Message'
        input: """<input name="vex" type="hidden" value="_vex-empty-value" />"""
        value: false
        buttons: [
            dialog.buttons.YES
            dialog.buttons.NO
        ]
        showCloseButton: false
        onSubmit: (event) ->
            $form = event.target
            $vexContent = $form.parentNode
            event.preventDefault()
            event.stopPropagation()
            id = $vexContent.getAttribute("data-vex-id")
            options = vex.getOptionsById(id)
            options.value = dialog.getFormValueOnSubmit $formToObject $form
            vex.close id
        focusFirstInput: true

    dialog.defaultAlertOptions =
        message: 'Alert'
        buttons: [
            dialog.buttons.YES
        ]

    dialog.defaultConfirmOptions =
        message: 'Confirm'

    dialog.open = (options) ->
        options = vex.extend {}, vex.defaultOptions, dialog.defaultOptions, options
        options.content = dialog.buildDialogForm options

        beforeClose = options.beforeClose
        options.beforeClose = ($vexContent, config) ->
            options.callback? config.value
            beforeClose? $vexContent, config

        $vexContent = vex.open options

        if options.focusFirstInput
            inputs = Array.prototype.slice.call(
                $vexContent.querySelectorAll('button[type="submit"], button[type="button"], input[type="submit"], input[type="button"], textarea, input[type="date"], input[type="datetime"], input[type="datetime-local"], input[type="email"], input[type="month"], input[type="number"], input[type="password"], input[type="search"], input[type="tel"], input[type="text"], input[type="time"], input[type="url"], input[type="week"]'),
                0
                )
            inputs.shift().focus() if inputs.length

        return $vexContent

    dialog.alert = (options) ->
        if typeof options is 'string'
            options = message: options

        options = vex.extend {}, dialog.defaultAlertOptions, options

        dialog.open options

    dialog.confirm = (options) ->
        if typeof options is 'string'
            throw '''dialog.confirm(options) requires options.callback.'''

        options = vex.extend {}, dialog.defaultConfirmOptions, options

        dialog.open options

    dialog.prompt = (options) ->
        if typeof options is 'string'
            throw '''dialog.prompt(options) requires options.callback.'''

        defaultPromptOptions =
            message: """<label for="vex">#{ options.label or 'Prompt:' }</label>"""
            input: """<input name="vex" type="text" class="vex-dialog-prompt-input" placeholder="#{ options.placeholder or '' }"  value="#{ options.value or '' }" />"""

        options = vex.extend {}, defaultPromptOptions, options

        dialog.open options

    dialog.buildDialogForm = (options) ->
        $form = document.createElement 'form'
        $form.classList.add "vex-dialog-form"

        $message = document.createElement 'div'
        $message.classList.add "vex-dialog-message"
        $input = document.createElement 'div'
        $input.classList.add "vex-dialog-input"

        $form.appendChild $message
        $message.appendChild vex.textToDOM options.message
        $form.appendChild $input
        $input.appendChild vex.textToDOM options.input
        buttons = dialog.getButtons options.buttons
        $input.appendChild buttons
        $form.addEventListener 'submit', options.onSubmit

        return $form

    dialog.getFormValueOnSubmit = (formData) ->
        if formData.vex or formData.vex is ''
            return true if formData.vex is '_vex-empty-value'
            return formData.vex

        else
            return formData

    dialog.getButtons = (buttons) ->
        $buttons = document.createElement 'div'
        $buttons.classList.add "vex-dialog-buttons"
        buttons.forEach( (button, index) ->
            b = document.createElement 'button'
            b.type = button.type
            b.appendChild document.createTextNode button.text
            b.classList.add(button.className, 'vex-dialog-button')
            b.classList.add 'vex-first' if index==0
            b.classList.add 'vex-last' if index==buttons.length-1
            b.addEventListener( 'click', (e) ->
                if button.click
                    id = vex.getVexId(b)
                    button.click(id, e)
            )
            $buttons.appendChild b
            )
        return $buttons

    # return dialog from factory
    dialog

if typeof define is 'function' and define.amd
    # AMD
    define ['vex'], vexDialogFactory
else if typeof exports is 'object'
    # CommonJS
    module.exports = vexDialogFactory require('./vex.js')
else
    # Global
    window.vex.dialog = vexDialogFactory window.vex
