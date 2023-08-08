import { Layer } from "./layer.js"
import { setImageSmoothing, resizeCanvas, clearCtx, drawRectTo, drawFullTo } from "./draw-utils.js"

# CompositeLayer forms its image by sequentially copying over the images from its source layers.
class CompositeLayer extends Layer
  # See comment on `ViewController` class for type info on `LayerOptions`. This object is meant to be shared and may
  # mutate.
  # (LayerOptions, Array[Layer]) -> Unit
  constructor: (@_layerOptions, @_sourceLayers) ->
    super()
    @_latestWorldShape = undefined
    @_canvas = document.createElement('canvas')
    @_ctx = @_canvas.getContext('2d')
    return

  getWorldShape: -> @_latestWorldShape

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

  repaint: ->
    changed = false
    for layer in @_sourceLayers
      if layer.repaint() then changed = true
    if not changed then return false

    @_latestWorldShape = @_sourceLayers[0].getWorldShape()
    cleared = resizeCanvas(@_canvas, @_latestWorldShape, @_layerOptions.quality)
    if not cleared then clearCtx(@_ctx)
    setImageSmoothing(@_ctx, false)
    for layer in @_sourceLayers
      layer.blindlyDrawTo(@_ctx)
    true

export {
  CompositeLayer
}
