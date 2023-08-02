# Given a world and a view into that world, returns a list of all the agents around the specified point. The point is
# specified in DOM coordinates relative to the given view.
# (World, View, number, number) -> [Agent]
getClickedAgents = (world, view, xPix, yPix) ->
  { left, top } = view.getBoundingClientRect()
  agentList = []
  xPcor = view.xPixToPcor(xPix - left)
  yPcor = view.yPixToPcor(yPix - top)

  patchHere = world.getPatchAt(xPcor, yPcor)
  if patchHere? then agentList.push(patchHere)

  # TODO what follows is a rudimentary implementation that does not reflect NetLogo JVM's behavior. Whether the agents
  # are hidden has to be taken into account, and the turtle calculations are more complicated.
  # coffeelint: disable=max_line_length
  # https://github.com/NetLogo/NetLogo/blob/c328d9663de7efc07184bde971dd22e162acfea4/netlogo-gui/src/main/window/View.java#L440
  # coffeelint: enable=max_line_length

  world.links().iterator().forEach((link) ->
    if world.topology.distance(xPcor, yPcor, link) < 0.5
      agentList.push(link)
  )

  world.turtles().iterator().forEach((turtle) ->
    if world.topology.distance(xPcor, yPcor, turtle) < 0.5
      agentList.push(turtle)
  )

  agentList

# ((Agent) -> Unit) -> (Agent) -> ContextMenuOption
# see "./ractives/contextable.coffee"
agentToContextMenuOption = (inspectFn) -> (agent) -> {
  text: "inspect #{agent.getName()}"
  isEnabled: true,
  action: -> inspectFn(agent)
}

export {
  getClickedAgents,
  agentToContextMenuOption
}
