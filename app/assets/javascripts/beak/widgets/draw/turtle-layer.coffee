import { Layer } from "./layer.js"
import { ShapeDrawer } from "./draw-shape.js"
import { usePatchCoords, drawTurtle } from "./draw-utils.js"
import { LinkDrawer } from "./link-drawer.js"

# Yields each name in `breedNames`, except that `unbreededName` comes last if it exists.
breedNameGen = (unbreededName, breedNames) ->
  seenUnbreededName = false
  for breedName in breedNames
    if breedName is unbreededName
      seenUnbreededName = true
    else
      yield breedName
  if seenUnbreededName then yield unbreededName

filteredByBreed = (unbreededName, agents, breeds) ->
  breededAgents = {}
  for _, agent of agents
    members = []
    breedName = agent.breed.toUpperCase()
    if not breededAgents[breedName]?
      breededAgents[breedName] = members
    else
      members = breededAgents[breedName]
    members.push(agent)
  for breedName from breedNameGen(unbreededName, breeds)
    if breededAgents[breedName]?
      members = breededAgents[breedName]
      for agent in members
        yield agent

class TurtleLayer extends Layer
  constructor: (@_fontSize, @_font) ->
    super()
    return

  blindlyDrawTo: (context) ->
    { world, turtles, links } = @_latestModel
    turtleDrawer = new ShapeDrawer(world.turtleshapelist ? {}, @_latestWorldShape.onePixel)
    linkDrawer = new LinkDrawer(@_latestWorldShape, context, world.linkshapelist ? {}, @_fontSize, @_font)
    usePatchCoords(
      @_latestWorldShape,
      context,
      (context) =>
        for link from filteredByBreed('LINKS', links, world.linkbreeds ? [])
          linkDrawer.draw(
            link,
            turtles[link.end1],
            turtles[link.end2],
            world.wrappingallowedinx,
            world.wrappingallowediny,
            context
          )
        context.lineWidth = @_latestWorldShape.onePixel # TODO can be more elegant?
        for turtle from filteredByBreed('TURTLES', turtles, world.turtlebreeds ? [])
          drawTurtle(turtleDrawer, @_latestWorldShape, context, turtle, false, @_fontSize, @_font)
    )
    return

  getDirectDependencies: -> []

export {
  TurtleLayer
}
