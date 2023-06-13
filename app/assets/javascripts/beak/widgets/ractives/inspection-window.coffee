RactiveInspectionWindow = Ractive.extend({
  data: -> {
    agentType: undefined, # String; one of "turtle", "patch", or "link"
    agentRef: undefined, # Agent; a reference to the agent from the world
  }

  template:
    """
    <div style="border: 1px solid black;">
      inspection window<br/>
      type is {{agentType}}<br/>
      id is {{agentRef.id}}<br/>
      coords are {{agentRef.xcor}} and {{agentRef.ycor}}<br/>
      <div style="border: 10px solid red; width: 200px; height: 200px;">
        view here
      </div>
    </div>
    """
})

export default RactiveInspectionWindow
