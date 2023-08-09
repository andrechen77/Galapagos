import { drawRectTo, drawFullTo } from "./draw-utils.js"

# Returns a canvas with the current state of the layer like a freeze frame.
convertLayerToCanvas = (layer, quality) ->
  { worldWidth, worldHeight, patchsize } = layer.getWorldShape()
  canvas = document.createElement('canvas')
  canvas.width = worldWidth * patchsize * quality
  canvas.height = worldHeight * patchsize * quality
  layer.drawTo(canvas.getContext('2d'))
  canvas

###
Interface for parts of the full view universe.
###
class Layer
  constructor: ->

  # (Unit) -> WorldShape
  getWorldShape: -> throw new Error('not implemented')

  # Returns a <canvas> element with the contents of the current layer. This canvas should be considered read-only.
  # This is a default implementation that works, but if it ends up being used, is probably a sign that the layer should
  # be refactored to get its own internal canvas which can be directly used.
  # (Unit) -> HTMLCanvasElement
  getCanvas: -> convertLayerToCanvas(this, 2)

  # Given dimensions specifying (in patch coordinates) a rectangle, draws that rectangle from this
  # layer to the specified context, scaling to fit and accounting for wrapping. It is the
  # responsibility of the caller to ensure that the destination context has enough pixels to render
  # a good-looking image. The rectangle is specified by its top-left corner and width and height.
  # Prefer to use `drawFullTo` or `blindlyDrawTo` when possible for performance reasons.
  # Must call `repaint` at least once before this method, since it depends on knowing the world shape.
  # This is a default implementation that works, but if it ends up being used, is probably a sign
  # that the layer should be refactored to get its own internal canvas which can be directly used.
  drawRectTo: (ctx, x, y, w, h) ->
    quality = 2
    sourceCanvas = convertLayerToCanvas(this, quality)
    drawRectTo(sourceCanvas, ctx, x, y, w, h, @getWorldShape(), quality)
    return

  # Draws the full layer onto the specified context, scaling to fit. It is the responsibility of the
  # caller to ensure that the destination context has enough pixels to render a good-looking image.
  # Prefer to use `blindlyDrawTo` when possible for performance reasons.
  # This is a default implementation that works, but if it ends up being used, is probably a sign
  # that the layer should be refactored to get its own internal canvas which can be directly used.
  drawFullTo: (ctx) ->
    quality = 2
    sourceCanvas = convertLayerToCanvas(this, quality)
    drawFullTo(sourceCanvas, ctx)
    return

  # Draws the rectangle from this layer onto the specified context. Assumes that the destination
  # context is correctly sized to hold the whole image from this layer.
  blindlyDrawTo: (context) ->

  # Updates the current layer, ensuring that all its dependencies are up-to-date. Returns whether any change was
  # actually made to this layer (which dependent layers might want be interested in). Doesn't necessarily
  # update an internal canvas, but it must be enough for the `drawTo` method to accurately
  # draw this layer to another. Does not modify its arguments. Must update @_latestWorldShape to a valid value.
  # Rendering is often split between between this method and the `drawTo` method, depending on what
  # makes most sense for the layer to store internally.
  # (Unit) -> boolean
  repaint: -> false

  # Returns an array of all this layer's direct dependencies
  getDirectDependencies: -> []

export {
  Layer
}
