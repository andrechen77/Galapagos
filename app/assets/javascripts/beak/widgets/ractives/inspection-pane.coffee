import RactiveInspectionWindow from "./inspection-window.js"

RactiveInspectionPane = Ractive.extend({
  data: -> {
    watchedAgents: [] # Array[Agent]
    viewController: undefined # ViewController; a reference to the ViewController from which this inspection window is taking its ViewWindow
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
      <inspectionWindow viewController={{viewController}} agentType="tortle" agentRef={{watchedAgents[0]}}/>
      {{/if}}
    </div>
    """
})

export default RactiveInspectionPane