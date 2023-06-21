import RactiveInspectionWindow from "./inspection-window.js"

RactiveInspectionPane = Ractive.extend({
  data: -> {
    watchedAgents: [] # Array[Agent]
    viewController: undefined # ViewController; a reference to the ViewController from which this inspection window is taking its ViewWindow

    input: ''
  }

  components: {
    inspectionWindow: RactiveInspectionWindow
  }

  onrender: ->
    run = =>
      input = @get('input')
      if input.trim().length > 0
        agentSetReporter = 'turtle-set' # TODO: make it reflect the actual type of agents
        for turtle in @get('watchedAgents')
          agentSetReporter = agentSetReporter.concat(" turtle #{turtle.id}")
        input = "ask (#{agentSetReporter}) [ #{input} ]"
        # TODO consider using `show` if the command is a reporter
        console.log(input)
        @fire('run', {}, 'console', input)
        @fire('command-center-run', input)
        @set('input', '')
        @set('workingEntry', {})

    commandCenterEditor = CodeMirror(@find('.netlogo-command-center-editor'), {
      value: @get('input'),
      mode:  'netlogo',
      theme: 'netlogo-default',
      scrollbarStyle: 'null',
      extraKeys: {
        Enter: run
      }
    })

    commandCenterEditor.on('beforeChange', (_, change) ->
      oneLineText = change.text.join('').replace(/\n/g, '')
      change.update(change.from, change.to, [oneLineText])
      true
    )

    commandCenterEditor.on('change', =>
      @set('input', commandCenterEditor.getValue())
    )

    @observe('input', (newValue) ->
      if newValue isnt commandCenterEditor.getValue()
        commandCenterEditor.setValue(newValue)
        commandCenterEditor.execCommand('goLineEnd')
    )

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

      <div class="netlogo-command-center-editor" style="width: 200px;"></div>

      specific Agent: ===============
      {{#if watchedAgents.length > 0}}
      <inspectionWindow viewController={{viewController}} agentType="turtle" agentRef={{watchedAgents.at(-1)}}/>
      {{/if}}
    </div>
    """
})

export default RactiveInspectionPane