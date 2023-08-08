import { Layer } from "./layer.js"
import { drawTurtle } from "./draw-shape.js"
import { usePatchCoords } from "./draw-utils.js"
import { drawLink } from "./link-drawer.js"

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
  # See comment on `ViewController` class for type info on `LayerOptions`. This object is meant to be shared and may
  # mutate.
  # (LayerOptions, (Unit) -> { model: AgentModel, worldShape: WorldShape }) -> Unit
  constructor: (@_layerOptions, @_getModelState) ->
    super()
    @_latestWorldShape = undefined
    @_latestModel = undefined
    return

  getWorldShape: -> @_latestWorldShape

  blindlyDrawTo: (context) ->
    { world, turtles, links } = @_latestModel
    usePatchCoords(
      @_latestWorldShape,
      context,
      (context) =>
        for link from filteredByBreed('LINKS', links, world.linkbreeds ? [])
          drawLink(
            world.linkshapelist
            link,
            turtles[link.end1],
            turtles[link.end2],
            @_latestWorldShape,
            context,
            @_layerOptions.fontSize,
            @_layerOptions.font
          )
        for turtle from filteredByBreed('TURTLES', turtles, world.turtlebreeds ? [])
          drawTurtle(
            @_latestWorldShape,
            world.turtleshapelist,
            context,
            turtle,
            false,
            @_layerOptions.fontSize,
            @_layerOptions.font
          )
    )
    return

  repaint: ->
    { model: @_latestModel, worldShape: @_latestWorldShape } = @_getModelState()
    return

  getDirectDependencies: -> []

export {
  TurtleLayer
}
