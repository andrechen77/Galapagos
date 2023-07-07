import { Layer } from "./layer.js"
import { ShapeDrawer } from "./draw-shape.js"
import { usePatchCoords, drawTurtle } from "./draw-utils.js"
import { LinkDrawer } from "./link-drawer.js"

filteredByBreed = (agents, breeds) ->
  # TODO is it necessary that we draw agents by breed? We can optimize this generator if we draw
  # agents in the order that they're given. --Andre C.
  breededAgents = {}
  for _, agent of agents
    members = []
    breedName = agent.breed.toUpperCase()
    if not breededAgents[breedName]?
      breededAgents[breedName] = members
    else
      members = breededAgents[breedName]
    members.push(agent)
  for breedName in breeds
    if breededAgents[breedName]?
      members = breededAgents[breedName]
      for agent in members
        yield agent

class TurtleLayer extends Layer
  constructor: (@_fontSize) ->
    super()

  drawTo: (context) ->
    { world, turtles, links } = @_latestModel
    turtleDrawer = new ShapeDrawer(world.turtleshapelist ? {}, @_latestWorldShape.onePixel)
    linkDrawer = new LinkDrawer(@_latestWorldShape, context, world.linkshapelist ? {}, @_fontSize)
    usePatchCoords(
      @_latestWorldShape,
      context,
      (context) =>
        for link from filteredByBreed(links, world.linkbreeds ? ["LINKS"])
          linkDrawer.draw(
            link,
            turtles[link.end1],
            turtles[link.end2],
            world.wrappingallowedinx,
            world.wrappingallowediny,
            context
          )
        context.lineWidth = @_latestWorldShape.onePixel # TODO can be more elegant?
        for turtle from filteredByBreed(turtles, world.turtlebreeds ? ["TURTLES"])
          drawTurtle(turtleDrawer, @_latestWorldShape, context, turtle, false, @_fontSize)
    )

  getDirectDependencies: -> []

export {
  TurtleLayer
}
