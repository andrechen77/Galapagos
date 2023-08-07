RactiveMiniAgentCard = Ractive.extend({
  data: -> {
    # Props

    agent: undefined # Agent
    selected: false # boolean

    # Consts

    # (Turtle|Patch|Link|Observer) -> String
    printPropertiesBrief: (agent) ->
      pairList = for varName in agent.varNames()
        "#{varName}: #{agent.getVariable(varName)}"
      pairList[1...6].join("<br/>")
  }

  on: {
    'world-might-change': ->
      @update('agent')
  }

  template: """
    <div
      style="border: 1px solid black; min-width: 300px; {{#selected}}background-color: lightblue;{{/}}"
      on-click="['clicked-agent-card', agent]"
      on-dblclick="['dblclicked-agent-card', agent]"
    >
      <b>{{agent.getName()}}</b><br/>
      {{{printPropertiesBrief(agent)}}}
    </div>
  """
})

export default RactiveMiniAgentCard
