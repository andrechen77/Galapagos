import { usePatchCoords, useWrapping } from "./draw-utils.js"
import { Layer } from "./layer.js"

# IDs used in watch, follow, and getCenteredAgent
turtleType = 1
patchType = 2
linkType = 3

# Perspective constants:
OBSERVE = 0
RIDE    = 1
FOLLOW  = 2
WATCH   = 3

# Returns the agent being watched, or null.
getWatchedAgent = (model) ->
  {observer: { perspective, targetagent }, turtles, links, patches} = model
  if perspective isnt OBSERVE and targetagent? and targetagent[1] >= 0
    [type, id] = targetagent
    switch type
      when turtleType then turtles[id]
      when patchType then patches[id]
      when linkType then links[id]
  else
    null

getDimensions = (agent) ->
  if agent.xcor?
    [agent.xcor, agent.ycor, 2 * agent.size]
  else if agent.pxcor?
    [agent.pxcor, agent.pycor, 2]
  else
    [agent.midpointx, agent.midpointy, agent.size]

adjustSize = (size, worldShape) ->
  Math.max(size, worldShape.worldWidth / 16, worldShape.worldHeight / 16)

outerRadius = (patchsize) -> 10 / patchsize
middleRadius = (patchsize) -> 8 / patchsize
innerRadius = (patchsize) -> 4 / patchsize

# Names and values taken from org.nlogo.render.SpotlightDrawer
dimmed = "rgba(0, 0, 50, #{ 100 / 255 })"
spotlightInnerBorder = "rgba(200, 255, 255, #{ 100 / 255 })"
spotlightOuterBorder = "rgba(200, 255, 255, #{ 50 / 255 })"
clear = 'white' # for clearing with 'destination-out' compositing

drawCircle = (ctx, x, y, innerDiam, outerDiam, color) ->
  ctx.save()
  ctx.fillStyle = color
  ctx.beginPath()
  ctx.arc(x, y, outerDiam / 2, 0, 2 * Math.PI)
  ctx.arc(x, y, innerDiam / 2, 0, 2 * Math.PI, true)
  ctx.fill()
  ctx.restore()

drawSpotlight = (ctx, worldShape, xcor, ycor, size, dimOther) ->
  { patchsize, actualMinX, actualMinY, worldWidth, worldHeight } = worldShape
  outer = outerRadius(patchsize)
  middle = middleRadius(patchsize)
  inner = innerRadius(patchsize)

  ctx.save()

  ctx.lineWidth = worldShape.onePixel
  ctx.beginPath()
  # Draw arc anti-clockwise so that it's subtracted from the fill. See the
  # fill() documentation and specifically the "nonzero" rule. BCH 3/17/2015
  if dimOther
    useWrapping(worldShape, ctx, xcor, ycor, size + outer, (ctx, x, y) =>
      ctx.moveTo(x, y) # Don't want the context to draw a path between the circles. BCH 5/6/2015
      ctx.arc(x, y, (size + outer) / 2, 0, 2 * Math.PI, true)
    )
    ctx.rect(actualMinX, actualMinY, worldWidth, worldHeight)
    ctx.fillStyle = dimmed
    ctx.fill()

  useWrapping(worldShape, ctx, xcor, ycor, size + outer, (ctx, x, y) =>
    drawCircle(ctx, x, y, size, size + outer, dimmed)
    drawCircle(ctx, x, y, size, size + middle, spotlightOuterBorder)
    drawCircle(ctx, x, y, size, size + inner, spotlightInnerBorder)
  )

  ctx.restore()

class SpotlightLayer extends Layer
  constructor: ->
    super()

  blindlyDrawTo: (ctx) ->
    watched = getWatchedAgent(@_latestModel)
    if !watched? then return
    usePatchCoords(@_latestWorldShape, ctx, (ctx) =>
      [xcor, ycor, size] = getDimensions(watched)
      drawSpotlight(
        ctx,
        @_latestWorldShape,
        xcor,
        ycor,
        adjustSize(size, @_latestWorldShape),
        @_latestModel.observer.perspective is WATCH
      )
    )

  repaint: (worldShape, model) ->
    super(worldShape, model)

  getDirectDependencies: -> []

export {
  SpotlightLayer
}
