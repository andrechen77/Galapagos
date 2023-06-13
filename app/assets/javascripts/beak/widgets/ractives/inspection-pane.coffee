import RactiveInspectionWindow from "./inspection-window.js"

RactiveInspectionPane = Ractive.extend({
  data: -> {
    watchedAgents: [] # Array[Agent]
  }

  components: {
    inspectionWindow: RactiveInspectionWindow
  }

  template:
    """
    <div class='netlogo-tab-content'>
      watched agents: ===============
      {{#each watchedAgents}}
        watched agent here <br/>
      {{/each}}
      <br/>
      specific Agent: ===============
      {{#if watchedAgents.length > 0}}
      <inspectionWindow agentType="tortle" agentRef={{watchedAgents[0]}}/>
      {{/if}}
    </div>
    """
})

export default RactiveInspectionPane