import { extractWorldShape } from "./draw-utils.js"
{ unique } = tortoise_require('brazier/array')

getAllDependencies = (layer) ->
  result = unique(layer.getDirectDependencies().flatMap(getAllDependencies))
  result.push(layer)
  result

###
LayerManager owns all the layers

Layers can have dependencies on other layers (but the layers being depended on don't know that)

Client requests the LayerManager update some Layers, given the state of some agent model.
LayerManager goes through each of the Layers and tells them to update in the correct order.
###
class LayerManager
  # `layers` is an object mapping each layer name to its layer object. There must not be circular
  # dependencies or dependencies outside this LayerManager.
  constructor: (layers = {}) ->
    @_layers = {}
    # `_dependencies` (Map<String, Array[Layer]>) is an object mapping each layer name to a sequence
    # of layers that must update before that layer can be correctly updated. Always includes the
    # layer itself as the final element ("to update layer A, one must first update layer A")
    @_dependencies = {}
    for layerName, layer of layers
      @addLayer(layerName, layer)

  # Adds the specified layer object to this LayerManager under the specified name.
  # Must not create circular dependencies, or dependencies on layers outside this manager.
  # (String, Layer, Array[String]) -> Unit

  addLayer: (layerName, layer) ->
    @_dependencies[layerName] = unique(getAllDependencies(layer))
    @_dependencies[layerName].push(layer)
    @_layers[layerName] = layer

  getLayer: (layerName) -> @_layers[layerName]

  # Updates the specified layers with the specified models (may also update their dependencies)
  # Unfortunately, due to the design of the model, this will mutate the model:
  # - resets `model.drawingEvents`
  # Array[String]-> Unit
  repaintLayers: (model, layerNames) ->
    worldShape = extractWorldShape(model.world)
    layersToRepaint = unique(layerNames.flatMap((layerName) => @_dependencies[layerName]))
    for layer in layersToRepaint
      layer.repaint(worldShape, model)
    model.drawingEvents = []

# Draws a rectangle (specified in patch coordinates) from a source canvas to a destination canvas,
# assuming that neither canvas has transformations and scaling the image to fit the destination.
# The rectangle is specified by its top-left corner and width and height. `worldShape` and
# `srcQuality` are used to make the calculation for which pixels from the source canvas are actually
# inside the specified rectangle.
helperDrawRectTo = (srcCanvas, dstCtx, xPcor, yPcor, wPcor, hPcor, worldShape, srcQuality) ->
  { patchsize, actualMinX, actualMaxY, wrapX, wrapY } = worldShape
  { width: canvasWidth, height: canvasHeight } = srcCanvas
  scale = srcQuality * patchsize # the size of a patch in canvas pixels

  # Imagine "wrapping" as, instead of taking one small rectangle from the source canvas,
  # simultaneously taking a 3 by 3 grid of rectangles spaced apart by the width/height of the source
  # canvas and putting them together.

  # Convert patch coordinates to canvas coordinates
  centerXPix = (xPcor - actualMinX) * scale # the top-left corner of the rectangle at the center of the 3 by 3
  centerYPix = (actualMaxY - yPcor) * scale
  wPix = wPcor * scale
  hPix = hPcor * scale

  xPixs = if wrapX then [centerXPix - canvasWidth, centerXPix, centerXPix + canvasWidth] else [centerXPix]
  yPixs = if wrapY then [centerYPix - canvasHeight, centerYPix, centerYPix + canvasHeight] else [centerYPix]
  for xPix in xPixs
    for yPix in yPixs
      dstCtx.drawImage(
        srcCanvas,
        xPix, yPix, wPix, hPix,
        0, 0, dstCtx.canvas.width, dstCtx.canvas.height
      )

###
Interface for parts of the full view universe.
###
class Layer
  constructor: ->
    # stores the latest info when this layer was repainted so that it can drawTo properly
    # Make sure to keep these updated by calling `super` from the `repaint` method, especially
    # if you use them (obviously).
    @_latestWorldShape = undefined
    @_latestModel = undefined

  # Given dimensions specifying (in patch coordinates) a rectangle, draws that rectangle from this
  # layer to the specified context, scaling to fit. It is the responsibility of the caller to ensure
  # that the destination context has enough pixels to render a good-looking image. The rectangle is
  # specified by its top-left corner and width and height.
  # prefer to use `drawTo` when possible.
  # This is a default implementation that works, but if it ends up being used, is probably a sign
  # that the layer should be refactored to get its own internal canvas which can be directly used.
  drawRectTo: (ctx, x, y, w, h) ->
    { worldWidth, worldHeight, patchsize } = @_latestWorldShape
    quality = 2
    sourceCanvas = document.createElement('canvas')
    sourceCanvas.width = worldWidth * patchsize * quality
    sourceCanvas.height = worldHeight * patchsize * quality
    @drawTo(sourceCanvas.getContext('2d'))
    helperDrawRectTo(sourceCanvas, ctx, x, y, w, h, @_latestWorldShape, quality)

  # Draws the rectangle from this layer onto the specified context. Assumes that the destination
  # context is correctly sized to hold the whole image from this layer.
  drawTo: (context) ->

  # Updates the current layer assuming that all its dependencies are up-to-date. Doesn't necessarily
  # update an internal canvas, but it must be enough for the `drawTo` method to accurately
  # draw this layer to another. Does not modify its arguments.
  # Overriding methods should still call `super(worldShape, model)` to ensure that
  # @_latestWorldShape is updated.
  # Rendering is often split between between this method and the `drawTo` method, depending on what
  # makes most sense for the layer to store internally.
  repaint: (worldShape, model) ->
    @_latestWorldShape = worldShape
    @_latestModel = model

  # Returns an array of all this layer's direct dependencies
  getDirectDependencies: -> []

export {
  LayerManager,
  helperDrawRectTo,
  Layer
}
