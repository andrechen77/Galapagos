import RactiveAgentVarField from "./agent-var-field.js"

omittedVarNames = ['who', 'pxcor', 'pycor', 'end1', 'end2', 'breed']

RactiveMiniAgentCard = Ractive.extend({
  data: -> {
    # Props

    agent: undefined # Agent
    selected: false # boolean
    opened: false # boolean
  }

  template: """
    <div
      class="inspection__mini-agent-card {{#selected}}selected{{/}} {{#opened}}opened{{/}}"
      title="{{agent.getName()}}"
      on-click="['clicked-agent-card', agent]"
      on-dblclick="['dblclicked-agent-card', agent]"
    >
      <span>{{agent.getName()}}</span>
      <div
        class="inspection__button"
        on-click="['closed-agent-card', agent]"
      >
        <img width=15 src="https://static.thenounproject.com/png/6447-200.png"/>
      </div>
    </div>
  """
})

export default RactiveMiniAgentCard
