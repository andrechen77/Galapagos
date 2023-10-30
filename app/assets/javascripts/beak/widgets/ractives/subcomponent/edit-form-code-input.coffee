import RactiveCodeContainer from "./code-container.js"

RactiveEditFormCode = Ractive.extend({
  components: {
    codeContainer: RactiveCodeContainer
  }

  data: -> {
    # Props
    id: undefined # string
    codeContainerType: undefined # CodeContainerType; see "code-container.coffee" for definition
    label: undefined # String
    value: undefined # string
    isDisabled: false # boolean
    isCollapsible: false # Boolean
    onchange: (_) -> # (string) -> Unit
    parentEditor: null # GalapagosEditor | null

    # State, but can be set by parent
    isExpanded: undefined # boolean | undefined
                          # if undefined this will be immediately set to the opposite of 'isCollapsible'
  }

  computed: {
    # string
    code: -> @findComponent('codeContainer').get('code')
  }

  on: {
    init: ->
      if not @get('isExpanded')?
        @set('isExpanded', not @get('isCollapsible'))
    "toggle-expansion": ->
      if @get('isCollapsible')
        @toggle('isExpanded')
      false
    "codeContainer.change": (context) ->
      code = context.component.get('code')
      @get('onchange')(code)
  }

  template: """
    <div
      class="flex-row code-container-label{{#isExpanded}} open{{/}}"
      on-click="toggle-expansion"
    >
      {{# isCollapsible }}
        <div for="{{id}}-is-expanded" class="expander widget-edit-checkbox-wrapper">
          <span id="{{id}}-is-expanded" class="widget-edit-input-label expander-label">&#9654;</span>
        </div>
      {{/}}
      <label for="{{id}}" class="expander-text">{{label}}</label>
    </div>
    <div class="{{# isCollapsible && !isExpanded }}hidden{{/}}">
      <codeContainer
        codeContainerType={{codeContainerType}}
        initialCode={{value}}
        isDisabled={{isDisabled}}
        parentEditor={{parentEditor}}
      />
    </div>
  """
})

export default RactiveEditFormCode
