# TODO actually import the enum and use the constants instead of the equivalent literals

codeContainerMapping = {
  'full_model': { parseMode: 'Normal', oneLine: false },
  'command': { parseMode: 'Oneline', oneLine: true },
  'one_line_reporter': { parseMode: 'Reporter', oneLine: true },
  'multi_line_reporter': { parseMode: 'Reporter', oneLine: false },
  'embedded': { parseMode: 'Embedded', oneLine: false },
  'generative': { parseMode: 'Generative', oneLine: false }
}
# type CodeContainerType = keyof typeof codeContainerMapping

RactiveCodeContainer = Ractive.extend({
  data: -> {
    # Props
    codeContainerType: undefined # CodeContainerType
    initialCode: "" # string
    onKeyUp: -> # (KeyboardEvent) -> Unit
    isDisabled: false # boolean
    placeholder: "" # string
    parentEditor: null # GalapagosEditor | null

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
      { parseMode, oneLine } = codeContainerMapping[@get('codeContainerType')]
      editor = new GalapagosEditor(@find(".netlogo-code"), {
        ReadOnly: @get('isDisabled'),
        Language: 0,
        Placeholder: @get('placeholderElement'),
        ParseMode: parseMode,
        OneLine: oneLine,
        Wrapping: not oneLine,
        OnUpdate: (_documentChanged, _viewUpdate) =>
          @update('code')
          return
        OnKeyUp: (event, _) =>
          @get('onKeyUp')(event)
          return
        OnBlurred: (_view) =>
          @fire('change')
          return
      })
      editor.SetCode(@get('initialCode'))
      @set('editor', editor)

      # We create the observer here instead of as an initialization option
      # because if this code container was rendered with a `parentEditor`
      # prop already specified, we should wait for this editor to actually be
      # created before we try to add it as a child to the parent editor.
      @observe('parentEditor', ((parentEditor) ->
        if parentEditor?
          parentEditor.AddChild(@get('editor'))
          # Note that there is a potential memory leak here. If this code
          # container gets unrendered and destroyed, we have no way of
          # unregistering our GalapagosEditor instance from the parent editor,
          # which means that it will be kept alive (even as the Ractive itself
          # is destroyed). Thus, if the user keeps rendering and unrendering
          # GalapagosEditors, then the parent editor's number of children will
          # only grow with dead children.
      ))
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
    @get('editor').Selection.Select(index - procedureName.length, index)
    return

  template: """
    <div class="netlogo-code"></div>
  """
})

# Does it make sense for the `RactiveCodeContainer` to have a parent, but also
# have the `RactiveParentCodeContainer` extend it? This would imply that parents
# themselves can also have parents, which would result in a runtime error if
# attempted. I'm going to leave it like this because the nature of a "parent"
# relationship implies that it is possible, and also because I don't want to
# change all the code that already uses `RactiveCodeContainer`. -Andre C.

RactiveParentCodeContainer = RactiveCodeContainer.extend({
  data: -> {
    # Props

    setAsParent: null # (GalapagosEditor) -> Unit | null
    # 'setAsParent', if not null, will be called when the editor is rendered.
    # The intention of this function is so that the parent of this Ractive has
    # a way to get a handle on the editor so that it can be set as the parent
    # of other editors. Thus, it wouldn't make sense to have both `parentEditor`
    # and `setAsParent` set at the same time for a component.

    # State

    widgetVarNames: [] # Array[String]
  }

  on: {
    render: ->
      if (setAsParent = @get('setAsParent'))?
        setAsParent(@get('editor'))

      # add observer here because we want to make sure the editor exists before
      # the observer fires.
      @observe('widgetVarNames', (widgetVarNames) ->
        @get('editor').SetWidgetVariables(widgetVarNames)
      )
  }
})


export default RactiveCodeContainer
export { RactiveParentCodeContainer }
