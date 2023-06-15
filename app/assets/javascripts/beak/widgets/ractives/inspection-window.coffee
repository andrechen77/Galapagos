RactiveInspectionWindow = Ractive.extend({
  data: -> {
    agentType: undefined, # String; one of "turtle", "patch", or "link"
    agentRef: undefined, # Agent; a reference to the agent from the world
    viewController: undefined, # ViewController; a reference to the ViewController from which this inspection window is taking its ViewWindow
    viewWindow: undefined # ViewWindow; a reference to the ViewWindow associated with the current agent
  }

  onrender: ->
    viewController = @get('viewController')
    agent = @get('agentRef')
    newViewWindow = viewController.getNewViewWindow(
      @find('.inspection-window-view-container'),
      viewController.model.turtles[agent.id]
    )
    viewController.repaint()
    @set('viewWindow', newViewWindow)

  # TODO: have a lifecycle such that the viewWindow is property destructed/constructed as the agent being inspected changes

  template:
    """
    <div style="border: 1px solid black;">
      inspection window<br/>
      type is {{agentType}}<br/>
      id is {{agentRef.id}}<br/>
      coords are {{agentRef.xcor}} and {{agentRef.ycor}}<br/>
      <div class="inspection-window-view-container" style="border: 10px solid red;">
        view here
      </div>
    </div>
    """
})

export default RactiveInspectionWindow
