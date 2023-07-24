import { extractWorldShape, drawRectTo, drawFullTo } from "./draw-utils.js"

# I would use the `unique` method of brazier, but it falsely marks some objects as equivalent even if they are not
# identical (and we care about identity).
unique = (arr) ->
  result = []
  for element in arr
    if not result.includes(element) # Uses `===` equality
      result.push(element)
  result

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
    return

  # Adds the specified layer object to this LayerManager under the specified name.
  # Must not create circular dependencies, or dependencies on layers outside this manager.
  # (String, Layer, Array[String]) -> Unit

  addLayer: (layerName, layer) ->
    @_dependencies[layerName] = unique(getAllDependencies(layer))
    @_layers[layerName] = layer
    return

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
    return

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
    # stores the latest info when this layer was repainted so that it can drawTo properly
    # Make sure to keep these updated by calling `super` from the `repaint` method, especially
    # if you use them (obviously).
    @_latestWorldShape = undefined
    @_latestModel = undefined
    return

  # (Unit) -> WorldShape
  getWorldShape: -> @_latestWorldShape
  # (Unit) -> AgentModel
  getModel: -> @_latestModel

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
  # This is a default implementation that works, but if it ends up being used, is probably a sign
  # that the layer should be refactored to get its own internal canvas which can be directly used.
  drawRectTo: (ctx, x, y, w, h) ->
    quality = 2
    sourceCanvas = convertLayerToCanvas(this, quality)
    drawRectTo(sourceCanvas, ctx, x, y, w, h, @_latestWorldShape, quality)
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
    return

  # Returns an array of all this layer's direct dependencies
  getDirectDependencies: -> []

export {
  LayerManager,
  Layer
}
