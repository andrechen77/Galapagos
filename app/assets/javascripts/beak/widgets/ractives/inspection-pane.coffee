import RactiveInspectionWindow from "./inspection-window.js"

RactiveInspectionPane = Ractive.extend({
  data: -> {
    # Props

    watchedAgents: [] # Array[Agent]
    viewController: undefined # ViewController; from which this inspection window is taking its ViewWindow

    # State

    # (Turtle|Patch|Link|Observer) -> String
    printProperties: (agent) ->
      pairList = for varName in agent.varNames()
        "#{varName}: #{agent.getVariable(varName)}"
      pairList.join("<br/>")

    # (Turtle|Patch|Link|Observer) -> String
    getAgentName: (agent) -> agent.getName()
  }

  components: {
    inspectionWindow: RactiveInspectionWindow
  }

  onrender: ->
    run = (input) =>
      if input.trim().length > 0
        agentSetReporter = 'turtle-set' # TODO: make it reflect the actual type of agents
        for turtle in @get('watchedAgents')
          agentSetReporter = agentSetReporter.concat(" turtle #{turtle.id}")
        input = "ask (#{agentSetReporter}) [ #{input} ]"
        # TODO consider using `show` if the command is a reporter
        @fire('run', {}, 'console', input)
        @fire('command-center-run', input)


    editor = new GalapagosEditor(@find('.netlogo-command-center-editor'), {
      Wrapping: true,
      OneLine: true,
      OnKeyUp: (event, editor) ->
        switch event.key
          when "Enter"
            run(editor.GetCode())
            editor.SetCode("")
    })

  template:
    """
    <div class='netlogo-tab-content'>
      watched agents: ===============<br/>
      {{#each watchedAgents as agent}}
        -----<br/>
        {{getAgentName(agent)}} <br/>
        {{{printProperties(agent)}}}
        -----<br/>
      {{/each}}
      <br/>

      <div class="netlogo-command-center-editor" style="width: 400px; height: 25px"></div>

      specific Agent: ===============
      {{#if watchedAgents.length > 0}}
      <inspectionWindow viewController={{viewController}} agentRef={{watchedAgents.at(-1)}}/>
      {{/if}}
    </div>
    """
})

export default RactiveInspectionPane
