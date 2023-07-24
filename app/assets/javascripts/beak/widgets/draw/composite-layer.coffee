import { Layer } from "./layer.js"
import { setImageSmoothing, resizeCanvas, clearCtx, drawRectTo, drawFullTo } from "./draw-utils.js"

# CompositeLayer forms its image by sequentially copying over the images from its source layers.
class CompositeLayer extends Layer
  constructor: (@_layerOptions, @_sourceLayers) ->
    super()
    @_canvas = document.createElement('canvas')
    @_ctx = @_canvas.getContext('2d')
    return

  getCanvas: -> @_canvas

  drawRectTo: (ctx, x, y, w, h) ->
    drawRectTo(@_canvas, ctx, x, y, w, h, @_latestWorldShape, @_layerOptions.quality)
    return

  drawFullTo: (ctx) ->
    drawFullTo(@_canvas, ctx)
    return

  blindlyDrawTo: (context) ->
    context.drawImage(@_canvas, 0, 0)
    return

  repaint: (worldShape, model) ->
    super(worldShape, model)
    cleared = resizeCanvas(@_canvas, worldShape, @_layerOptions.quality)
    if not cleared then clearCtx(@_ctx)
    setImageSmoothing(@_ctx, false)
    for layer in @_sourceLayers
      layer.blindlyDrawTo(@_ctx)
    return

  getDirectDependencies: -> @_sourceLayers

export {
  CompositeLayer
}
