import RactiveAgentVarField from "./agent-var-field.js"

RactiveMiniAgentCard = Ractive.extend({
  components: {
    agentVarField: RactiveAgentVarField
  }

  data: -> {
    # Props

    agent: undefined # Agent
    selected: false # boolean
  }

  computed: {
    # Array[string]
    varNames: -> @get('agent').varNames()[1...6] # first 5 variables, ignoring who number
  }

  on: {
    'world-might-change': ->
      @update('agent')
  }

  template: """
    <div
      style="border: 1px solid black; min-width: 160px; {{#selected}}background-color: lightblue;{{/}}"
      on-click="['clicked-agent-card', agent]"
      on-dblclick="['dblclicked-agent-card', agent]"
    >
      <b>{{agent.getName()}}</b>
      <span style="float: right;" on-click="['closed-agent-card', agent]">(-)</span>
      <br/>
      {{#each varNames as varName}}
        <agentVarField agent={{agent}} varName={{varName}}/>
      {{/each}}
    </div>
  """
})

export default RactiveMiniAgentCard
