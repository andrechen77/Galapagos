import { followAgentWithZoom } from '../draw/window-generators.js'
import { getDimensions } from "../draw/perspective-utils.js"
import { getClickedAgents, agentToContextMenuOption } from "../view-context-menu-utils.js"
import { getEquivalentAgent } from "../draw/agent-conversion.js"
import RactiveAgentVarField from './agent-var-field.js'
import RactiveCommandInput from "./command-input.js"

{ Perspective: { Ride, Follow, Watch } } = tortoise_require('engine/core/observer')

RactiveInspectionWindow = Ractive.extend({
  components: {
    agentVarField: RactiveAgentVarField,
    commandInput: RactiveCommandInput
  }

  data: -> {
    # Props

    agent: undefined, # Agent; a reference to the actual agent from the engine
    isEditing: undefined, # boolean
    checkIsReporter: undefined, # (string) -> boolean
    parentEditor: null, # GalapagosEditor | null
    setInspect: undefined, # (SetInspectAction) -> Unit
    viewController: undefined, # ViewController; from which this inspection window is taking its ViewWindow

    # State

    viewModelAgent: undefined, # Agent; but not the same type as `agent`; this is a reference to the equivalent agent
    # from the ViewController's AgentModel. This should be kept in sync with the `agent` data.
    agentType: undefined # 'turtle' | 'patch' | 'link'; This should be kept in sync with the `agent` data.
    viewWindow: undefined # View; a reference to the View associated with the current agent
    windowGenerator: undefined # result of `followAgentWithZoom`; see "window-generators.coffee"
    zoomLevel: 0.7 # number; represents how much of the screen the agent takes up

    # Consts

    # (Unit) -> Unit
    replaceView: ->
      if @get('viewWindow')?
        @get('viewWindow').destructor()
      viewController = @get('viewController')
      { worldWidth, worldHeight } = viewController.getWorldShape()
      windowGenerator = followAgentWithZoom(
        300,
        @get('viewModelAgent'),
        @get('zoomLevel'),
        Math.min(worldWidth, worldHeight) / 2
      )
      viewWindow = viewController.getNewView(
        @find('.inspection-window-view-container'),
        'world',
        windowGenerator
      )
      @set({ viewWindow, windowGenerator })
      # Repaints the view; we do this instead of calling repaint directly because this also accounts for zoom.
      @get('zoomView')(@get('zoomLevel'))
      return

    # (number) -> Unit
    zoomView: (zoomLevel) ->
      @get('windowGenerator').zoomLevel = zoomLevel
      @get('viewWindow').repaint()
      return

    # (Turtle|Patch|Link|Observer) -> String
    printProperties: (agent) ->
      pairList = for varName in agent.varNames()
        "#{varName}: #{agent.getVariable(varName)}"
      pairList.join("<br/>")
  }

  computed: {
    # Array[string]
    varNames: -> @get('agent').varNames()

    # { agentType: AgentType, agents?: Array[Agent] }
    targetedAgentObj: ->
      agentType = switch @get('agentType')
        when 'turtle' then 'turtles'
        when 'patch' then 'patches'
        when 'link' then 'links'
      agent = @get('agent')
      { agentType, agents: [agent] }
  }

  onrender: ->
    # We want to run `updateView` and `zoomView` only after the instance has been rendered to the DOM, but Ractive
    # observers initialize before rendering. And for some reason, using the `defer` option does not work
    # (see Ractive API).
    @_syncAgentData(@get('agent'))
    @get('replaceView')()

  on: {
    'world-might-change': ->
      @update('agent')
    'watch-button-clicked': ->
      observer = world.observer
      persp = observer.getPerspective()
      inspectedAgent = @get('agent')
      if (persp is Ride or persp is Follow or persp is Watch) and observer.subject() is inspectedAgent
        observer.resetPerspective()
      else
        inspectedAgent.watchMe()
    'agentVarField.agent-id-var-changed': (_, varName, newValue) ->
      currentAgent = @get('agent')
      newAgent = switch @get('agentType')
        when 'turtle'
          id = if varName is 'who' then parseInt(newValue) else currentAgent.id
          world.turtleManager.getTurtle(id)
        when 'patch'
          pxcor = if varName is 'pxcor' then parseInt(newValue) else currentAgent.pxcor
          pycor = if varName is 'pycor' then parseInt(newValue) else currentAgent.pycor
          world.getPatchAt(pxcor, pycor)
        when 'link'
          who1 = if varName is 'end1' then parseInt(newValue) else currentAgent.end1.id
          who2 = if varName is 'end2' then parseInt(newValue) else currentAgent.end2.id
          breedName = if varName is 'breed' then newValue else currentAgent.getBreedName()
          if world.breedManager.get(breedName)?
            world.linkManager.getLink(who1, who2, breedName)
          else
            # The breed name is invalid; asking the link manager for the link of an invalid breed will cause it to panic
            # We have to design around this.
            currentAgent
      # the agent could be Nobody
      if newAgent.id isnt -1
        @set('agent', newAgent)
      false
  }

  observe: {
    # While all other data about the agent is automatically updated once this Ractive
    # realizes that the agentRef has changed, the view is controlled by the ViewController,
    # so we need to interact with the ViewController to get a new view that reflects the
    # agent.
    'agent': {
      handler: (newValue, oldValue) ->
        if oldValue is newValue then return # we only care about when the identity changes (see Ractive API)
        @_syncAgentData(newValue)
        @get('replaceView')()
      init: false # see `onrender`
    }
    'zoomLevel': {
      handler: (newZoomLevel) ->
        @get('zoomView')(newZoomLevel)
      init: false # see `onrender`
    }
  }

  getContextMenuOptions: (x, y) ->
    viewWindow = @get('viewWindow')
    { left, top, bottom, right } = viewWindow.getBoundingClientRect()
    if left <= x <= right and top <= y <= bottom
      getClickedAgents(@get('viewController').getModel())(world, viewWindow, x, y).map(agentToContextMenuOption(@get('setInspect')))
    else
      # The cursor is not actually inside the bounding box of the canvas (probably on the border)
      []

  # Updates the 'viewModelAgent' and 'agentType' data to reflect the specified 'agent' data
  # (Unit) -> Unit
  _syncAgentData: (agent) ->
    [viewModelAgent, agentType] = getEquivalentAgent(@get('viewController').getModel())(agent)
    @set({ viewModelAgent, agentType })

  template:
    """
    <div style="border: 1px solid black;">
      <b>{{agent.getName()}}</b><span style="float: right;" on-click=["closed-inspection-window", agent]><b>(X)</b></span>
      <div
        class="inspection-window-view-container"
        style="width: fit-content;"
        on-contextmenu="show-context-menu"
      ></div>
      <div>
        <button on-click="watch-button-clicked">Watch</button>
        <input type="range" min=0 max=1 step=0.01 value="{{zoomLevel}}"/>
        ZOOM LEVEL {{zoomLevel}}
      </div>
      {{#each varNames as varName}}
        <agentVarField agent={{agent}} varName={{varName}}/>
      {{/each}}
      <commandInput
        isReadOnly={{isEditing}}
        source="inspection-window"
        checkIsReporter={{checkIsReporter}}
        targetedAgentObj={{targetedAgentObj}}
        placeholderText="Input command for {{agent.getName()}}"
        parentEditor={{parentEditor}}
      />
    </div>
    """
})

export default RactiveInspectionWindow
