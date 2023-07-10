import { Layer } from "./layer.js"
import { resizeCanvas, clearCtx, drawRectTo, drawFullTo } from "./draw-utils.js"

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
    # TODO should we keep these, or move them somewhere else?  Also note that I got rid of the font thing
    @_ctx.imageSmoothingEnabled = false
    @_ctx.webkitImageSmoothingEnabled = false
    @_ctx.mozImageSmoothingEnabled = false
    @_ctx.oImageSmoothingEnabled = false
    @_ctx.msImageSmoothingEnabled = false
    for layer in @_sourceLayers
      layer.blindlyDrawTo(@_ctx)

  getDirectDependencies: -> @_sourceLayers

export {
  CompositeLayer
}