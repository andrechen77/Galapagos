import { followAgent } from '../draw/window-generators.js'

RactiveInspectionWindow = Ractive.extend({
  data: -> {
    agentType: undefined, # String; one of "turtle", "patch", or "link"
    agentRef: undefined, # Agent; a reference to the agent from the world
    viewController: undefined, # ViewController; a reference to the ViewController from which this inspection window is taking its ViewWindow
    viewWindow: undefined # ViewWindow; a reference to the ViewWindow associated with the current agent
    updateView: ->
      if @get('viewWindow')?
        @get('viewWindow').destructor()
      viewController = @get('viewController')
      agent = @get('agentRef')
      newViewWindow = viewController.getNewViewWindow(
        @find('.inspection-window-view-container'),
        followAgent(agent)
        'world'
      )
      viewController.repaint()
      @set('viewWindow', newViewWindow)
  }

  onrender: ->
    @get('updateView')() # (see `observe.agentRef`) We want to run `updateView` only after the
    # instance has been rendered to the DOM, but Ractive observers initialize before rendering.
    # and for some reason, using the `defer` option does not work (see Ractive API).

  observe: {
    # While all other data about the agent is automatically updated once this Ractive
    # realizes that the agentRef has changed, the view is controlled by the ViewController,
    # so we need to interact with the ViewController to get a new view that reflects the
    # agent.
    'agentRef.id': {
      handler: ->
        @get('updateView')()
      init: false # see `onrender`
    }
  }

  template:
    """
    <div style="border: 1px solid black;">
      inspection window<br/>
      type is {{agentType}}<br/>
      id is {{agentRef.id}}<br/>
      coords are {{agentRef.xcor}} and {{agentRef.ycor}}<br/>
      <div class="inspection-window-view-container" style="border: 10px solid red; width: fit-content;">
      </div>
    </div>
    """
})

export default RactiveInspectionWindow
