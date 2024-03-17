import RactiveAgentVarField from "./agent-var-field.js"

omittedVarNames = ['who', 'pxcor', 'pycor', 'end1', 'end2', 'breed']

RactiveMiniAgentCard = Ractive.extend({
  data: -> {
    # Props

    agent: undefined # Agent
    selected: false # boolean
  }

  template: """
    <div
      style="border: 1px solid black; padding: 2px; min-width: 100px; height: min-content; {{#selected}}background-color: lightblue;{{/}}"
      on-click="['clicked-agent-card', agent]"
      on-dblclick="['dblclicked-agent-card', agent]"
    >
      <b>{{agent.getName()}}</b>
      <span style="float: right;" on-click="['closed-agent-card', agent]"><b>(X)</b></span>
    </div>
  """
})

export default RactiveMiniAgentCard
