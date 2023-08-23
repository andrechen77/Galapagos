RactiveAgentVarField = Ractive.extend({
  data: -> {
    # Props
    agent: undefined # Agent; (from the actual agent)
    varName: undefined # string; as in `agent.hasVariable(varName)`

    # State
    currentInput: undefined
  }

  computed: {
    varValueAsStr: ->
      val = @get('agent').getVariable(@get('varName'))
      if typeof val is 'string'
        "\"#{val}\""
      else
        # assume that the value is convertible to a string
        "#{val}"
  }

  observe: {
    'varValueAsStr': (value) -> @set('currentInput', value)
  }

  on: {
    'submit-input': (_, input) ->
      cmd = "ask #{@get('agent').getName()} [ set #{@get('varName')} #{input}]"
      @fire('run', {}, 'agent-var-field', cmd)
      @update('varValueAsStr')
      @set('currentInput', @get('varValueAsStr'))
  }

  template: """
    <div>
      {{varName}}:
      <input value={{currentInput}} on-change="['submit-input', currentInput]"/>
    </div>
  """
})

export default RactiveAgentVarField
