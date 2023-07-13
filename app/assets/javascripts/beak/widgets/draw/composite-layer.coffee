import { Layer } from "./layer.js"
import { setImageSmoothing, resizeCanvas, clearCtx, drawRectTo, drawFullTo } from "./draw-utils.js"

# CompositeLayer forms its image by sequentially copying over the images from its source layers.
class CompositeLayer extends Layer
  constructor: (@_quality, @_sourceLayers) ->
    super()
    @_canvas = document.createElement('canvas')
    @_ctx = @_canvas.getContext('2d')
    return

  drawRectTo: (ctx, x, y, w, h) ->
    drawRectTo(@_canvas, ctx, x, y, w, h, @_latestWorldShape, @_quality)
    return

  drawFullTo: (ctx) ->
    drawFullTo(@_canvas, ctx)
    return

  blindlyDrawTo: (context) ->
    context.drawImage(@_canvas, 0, 0)
    return

  repaint: (worldShape, model) ->
    super(worldShape, model)
    cleared = resizeCanvas(@_canvas, worldShape, @_quality)
    if not cleared then clearCtx(@_ctx)
    setImageSmoothing(@_ctx, false)
    for layer in @_sourceLayers
      layer.blindlyDrawTo(@_ctx)
    return

  getDirectDependencies: -> @_sourceLayers

export {
  CompositeLayer
}
