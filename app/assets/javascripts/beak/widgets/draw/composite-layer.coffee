import { Layer, helperDrawRectTo } from "./layer.js"

# CompositeLayer forms its image by sequentially copying over the images from its source layers.
class CompositeLayer extends Layer
  constructor: (@_quality, @_sourceLayers) ->
    super()
    @_canvas = document.createElement('canvas')
    @_ctx = @_canvas.getContext('2d')

  drawRectTo: (ctx, x, y, w, h) ->
    helperDrawRectTo(@_canvas, ctx, x, y, w, h, @_latestWorldShape, @_quality)

  drawTo: (context) ->
    context.drawImage(@_canvas, 0, 0)

  repaint: (worldShape, model) ->
    super(worldShape, model)
    # Makes sure that the canvas is properly sized to the world, using this layer's @_quality. Avoids
    # resizing the canvas if possible, as that is an expensive operation. (https://stackoverflow.com/a/6722031)
    { worldWidth, worldHeight, patchsize } = worldShape
    newWidth = worldWidth * patchsize * @_quality
    newHeight = worldHeight * patchsize * @_quality
    if @_canvas.width != newWidth then @_canvas.width = newWidth
    if @_canvas.height != newHeight then @_canvas.height = newHeight
    # TODO should we keep these, or move them somewhere else?  Also note that I got rid of the font thing
    @_ctx.imageSmoothingEnabled = false
    @_ctx.webkitImageSmoothingEnabled = false
    @_ctx.mozImageSmoothingEnabled = false
    @_ctx.oImageSmoothingEnabled = false
    @_ctx.msImageSmoothingEnabled = false
    for layer in @_sourceLayers
      layer.drawTo(@_ctx)

  getDirectDependencies: -> @_sourceLayers

export {
  CompositeLayer
}