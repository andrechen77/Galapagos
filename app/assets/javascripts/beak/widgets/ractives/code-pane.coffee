import CodeUtils from "/beak/widgets/code-utils.js"
import RactiveCodeContainer from "./new-code-container.js"

RactiveCodePane = Ractive.extend({
  components: {
    codeContainer: RactiveCodeContainer
  }

  data: -> {
    # Props
    initialCode: "initial code goes here" # string

    # Internal State
    procedureNames: {} # Object<string, number>
  }

  getCode: ->
    console.log('getting code from new-code-editor')
    @findComponent('codeContainer').get('code')

  on: {
    render: ->
      @_setupProceduresDropdown()
  }

  _setupProceduresDropdown: ->
    dropdownElement = $(@find('.netlogo-procedurenames-dropdown'))
    dropdownElement.chosen({ search_contains: true })
    dropdownElement.on('change', =>
      procedureNames = @get('procedureNames')
      selectedProcedure = dropdownElement.val()
      index = procedureNames[selectedProcedure]
      @findComponent('codeContainer').highlightProcedure(selectedProcedure, index)
    )
    dropdownElement.on('chosen:showing_dropdown', =>
      procedureNames = CodeUtils.findProcedureNames(@getCode(), 'as-written')
      @set('procedureNames', procedureNames)
      dropdownElement.trigger('chosen:updated')
    )
    return

  template: """
    <div id="netlogo-code-tab" class="netlogo-tab-content netlogo-code-container">
      <ul class="netlogo-codetab-widget-list">
        <li class="netlogo-codetab-widget-listitem">
          <select class="netlogo-procedurenames-dropdown" data-placeholder="Jump to Procedure" tabindex="2">
            {{#each procedureNames:name}}
              <option value="{{name}}">{{name}}</option>
            {{/each}}
          </select>
        </li>
        <li class="netlogo-codetab-widget-listitem">
          {{# !isReadOnly }}
            <button class="netlogo-widget netlogo-ugly-button netlogo-recompilation-button{{#isEditing}} interface-unlocked{{/}}"
                on-click="['recompile', 'user']" {{# !isStale }}disabled{{/}} >Recompile Code</button>
          {{/}}
        </li>
        <li class="netlogo-codetab-widget-listitem">
          <input type='checkbox' class="netlogo-autocomplete-checkbox" checked='{{autoCompleteStatus}}'>
          <label class="netlogo-autocomplete-label">
            Auto Complete {{# autoCompleteStatus}}Enabled{{else}}Disabled{{/}}
          </label>
        </li>
      </ul>
      <codeContainer parseMode="normal" initialCode={{initialCode}}/>
    </div>
  """
})

export default RactiveCodePane
