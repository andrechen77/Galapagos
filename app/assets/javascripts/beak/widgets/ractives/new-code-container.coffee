# TODO actually import the enum and use the constants instead of the equivalent literals

parseModeMapping = {
  'normal': 'Normal',
  'oneline': 'Oneline',
  'onelinereporter': 'OnelineReporter',
  'embedded': 'Embedded',
  'generative': 'Generative'
}
# type ParseMode = keyof typeof parseModeMapping
# corresponding to the parse modes of the GalapagosEditor

RactiveCodeContainer = Ractive.extend({
  data: -> {
    # Props
    parseMode: undefined # ParseMode
    initialCode: "" # string
    onKeyUp: -> # (KeyboardEvent) -> Unit
    isDisabled: false # boolean
    placeholder: "" # string

    # State
    editor: undefined # GalapagosEditor
    placeholderElement: document.createElement('span')
  }

  computed: {
    # Shouldn't be overridden by parent component mapping data
    # string
    code: {
      get: ->
        editor = @get('editor')
        if editor?
          editor.GetCode()
        else
          ""
      set: (code) -> @get('editor').SetCode(code)
    }
  }

  on: {
    render: ->
      parseMode = @get('parseMode')
      oneLine = parseMode is 'oneline' or parseMode is 'onelinereporter'
      editor = new GalapagosEditor(@find(".netlogo-code"), {
        ReadOnly: @get('isDisabled'),
        Language: 0,
        Placeholder: @get('placeholderElement'),
        ParseMode: parseModeMapping[parseMode],
        OneLine: oneLine,
        Wrapping: not oneLine,
        OnUpdate: (_documentChanged, _viewUpdate) =>
          @update('code')
          return
        OnKeyUp: (event, _) =>
          @get('onKeyUp')(event)
          return
      })
      editor.SetCode(@get('initialCode'))
      @set('editor', editor)
  }

  observe: {
    isDisabled: {
      handler: (isDisabled) -> @get('editor').SetReadOnly(isDisabled)
      init: false # the editor is already initialized to have the correct setting
    }

    placeholder: (text) -> @get('placeholderElement').textContent = text
  }

  # (Unit) -> Unit
  focus: ->
    @get('editor').Focus()
    return

  # (string, number) -> Unit
  highlightProcedure: (procedureName, index) ->
    console.log("Unimplemented: highlight procedure `#{procedureName}` at index #{index}")
    return

  template: """
    <div class="netlogo-code"></div>
  """
})

export default RactiveCodeContainer
