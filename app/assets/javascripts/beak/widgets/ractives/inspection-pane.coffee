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
      watched agents: ===============<br/>
      {{#each watchedAgents}}
        -----<br/>
        watched agent here <br/>
        id is {{id}}<br/>
        coords are {{xcor}} and {{ycor}}<br/>
        -----<br/>
      {{/each}}
      <br/>
      specific Agent: ===============
      {{#if watchedAgents.length > 0}}
      <inspectionWindow viewController={{viewController}} agentType="tortle" agentRef={{watchedAgents.at(-1)}}/>
      {{/if}}
    </div>
    """
})

export default RactiveInspectionPane