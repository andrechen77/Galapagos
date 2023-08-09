import { Layer } from "./layer.js"
import { usePatchCoords } from "./draw-utils.js"
import { netlogoColorToCSS } from "/colors.js"
import { getEquivalentAgent } from "./agent-conversion.js"

drawGlow = (ctx, x, y, r, color) ->
  ctx.save()
  grad = ctx.createRadialGradient(x, y, 0, x, y, r)
  grad.addColorStop(0, color)
  grad.addColorStop(1, 'rgb(0, 0, 0, 0)')
  ctx.fillStyle = grad
  ctx.beginPath()
  ctx.arc(x, y, r, 0, 2 * Math.PI)
  ctx.fill()
  ctx.restore()

class HighlightLayer extends Layer
  # See comment on `ViewController` class for type info on `LayerOptions` (which is meant to be shared and may mutate)
  # as well as `ModelState`.
  # (LayerOptions, (Unit) -> ModelState, (Unit) -> Array[Agent]) -> Unit
  # where `Agent` is the actual agent object instead of the `AgentModel` analogue
  constructor: (@_getModelState, @_getHighlightedAgents) ->
    super()
    @_latestModelState = { updateSym: Symbol() } # other fields left undefined should not cause issues
    return

  getWorldShape: -> @_getModelState.worldShape

  blindlyDrawTo: (ctx) ->
    { highlightedAgents, model, worldShape } = @_latestModelState
    toModelAgent = getEquivalentAgent(model) # function that converts from actual agent object to AgentModel analogue
    usePatchCoords(
      worldShape,
      ctx,
      (ctx) =>
        for agent in highlightedAgents
          [agent, type] = toModelAgent(agent)
          switch type
            when 'turtle'
              drawGlow(ctx, agent.xcor, agent.ycor, agent.size, netlogoColorToCSS(agent.color))
            when 'patch'
              console.log("highlighting patch #{agent.pxcor} #{agent.pycor}")
            when 'link'
              console.log("highlighting #{agent.getName()}")
        return
    )

  repaint: ->
    lastUpdateSym = @_getModelState.updateSym
    { updateSym } = @_latestModelState = @_getModelState()
    lastUpdateSym isnt updateSym

export {
  HighlightLayer
}
