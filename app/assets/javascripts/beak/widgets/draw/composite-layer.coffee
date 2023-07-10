import { Layer } from "./layer.js"
import { setImageSmoothing, resizeCanvas, clearCtx, drawRectTo, drawFullTo } from "./draw-utils.js"

# CompositeLayer forms its image by sequentially copying over the images from its source layers.
class CompositeLayer extends Layer
  constructor: (@_quality, @_sourceLayers) ->
    super()
    @_canvas = document.createElement('canvas')
    @_ctx = @_canvas.getContext('2d')

  drawRectTo: (ctx, x, y, w, h) ->
    drawRectTo(@_canvas, ctx, x, y, w, h, @_latestWorldShape, @_quality)

  drawFullTo: (ctx) ->
    drawFullTo(@_canvas, ctx)

  blindlyDrawTo: (context) ->
    context.drawImage(@_canvas, 0, 0)

  repaint: (worldShape, model) ->
    super(worldShape, model)
    cleared= resizeCanvas(@_canvas, worldShape, @_quality)
    if !cleared then clearCtx(@_ctx)
    setImageSmoothing(@_ctx, false)
    for layer in @_sourceLayers
      layer.blindlyDrawTo(@_ctx)

  getDirectDependencies: -> @_sourceLayers

export {
  CompositeLayer
}