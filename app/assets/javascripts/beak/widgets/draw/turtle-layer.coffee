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
  # See comment on `ViewController` class for type info on `LayerOptions` (which is meant to be shared and may mutate)
  # as well as `ModelState`.
  # (LayerOptions, (Unit) -> ModelState) -> Unit
  constructor: (@_layerOptions, @_getModelState) ->
    super()
    @_latestModelState = { updateSym: Symbol() } # other fields left undefined should not cause issues
    return

  getWorldShape: -> @_latestModelState.worldShape

  blindlyDrawTo: (context) ->
    { model: { world, turtles, links }, worldShape } = @_latestModelState
    usePatchCoords(
      worldShape,
      context,
      (context) =>
        for link from filteredByBreed('LINKS', links, world.linkbreeds ? [])
          drawLink(
            world.linkshapelist
            link,
            turtles[link.end1],
            turtles[link.end2],
            worldShape,
            context,
            @_layerOptions.fontSize,
            @_layerOptions.font
          )
        for turtle from filteredByBreed('TURTLES', turtles, world.turtlebreeds ? [])
          drawTurtle(
            worldShape,
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
    lastUpdateSym = @_latestModelState.updateSym
    { updateSym } = @_latestModelState = @_getModelState()
    lastUpdateSym isnt updateSym

export {
  TurtleLayer
}
