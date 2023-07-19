import { followAgentWithZoom } from '../draw/window-generators.js'
import { getDimensionsDirect } from "../draw/perspective-utils.js"

RactiveInspectionWindow = Ractive.extend({
  data: -> {
    # Props
    agentRef: undefined, # Agent; a reference to the agent from the world
    viewController: undefined, # ViewController; from which this inspection window is taking its ViewWindow

    # State
    viewWindow: undefined # ViewWindow; a reference to the ViewWindow associated with the current agent
    windowGenerator: undefined # result of `followAgentWithZoom`; see "window-generators.coffee"
    zoomLevel: 0.7 # number
    # (Unit) -> Unit
    replaceView: ->
      if @get('viewWindow')?
        @get('viewWindow').destructor()
      windowGenerator = followAgentWithZoom(@get('agentRef'), @get('zoomLevel'))
      viewWindow = @get('viewController').getNewView(
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
      [_, _, size] = getDimensionsDirect(@get('agentRef'))
      maxRadius = Math.max(50, size * 10)
      # Simple linear function mapping zoomLevel to zoomRadius, where zoomLevel of 0 maps to maxRadius and
      # zoomLevel of 1 maps to the agent's size. Might want to revisit this.
      r = size + (size - maxRadius) * (zoomLevel - 1)
      @get('windowGenerator').zoomRadius = r
      @get('viewWindow').repaint()
      return
  }

  onrender: ->
    # We want to run `updateView` and `zoomView` only after the instance has been rendered to the DOM, but Ractive
    # observers initialize before rendering. And for some reason, using the `defer` option does not work
    # (see Ractive API).
    @get('replaceView')()

  observe: {
    # While all other data about the agent is automatically updated once this Ractive
    # realizes that the agentRef has changed, the view is controlled by the ViewController,
    # so we need to interact with the ViewController to get a new view that reflects the
    # agent.
    'agentRef': {
      handler: (newValue, oldValue) ->
        if oldValue is newValue then return # we only care about when the identity changes (see Ractive API)
        @get('replaceView')()
      init: false # see `onrender`
    }
    'zoomLevel': {
      handler: (newZoomLevel) ->
        @get('zoomView')(newZoomLevel)
      init: false # see `onrender`
    }
  }

  template:
    """
    <div style="border: 1px solid black;">
      inspection window<br/>
      <div class="inspection-window-view-container" style="border: 10px solid red; width: fit-content;"></div>
      <input type="range" min=0 max=1 step=0.01 value="{{ zoomLevel }}"/>
      ZOOM LEVEL {{ zoomLevel }}
    </div>
    """
})

export default RactiveInspectionWindow
