import { netlogoColorToCSS, netlogoColorToRGB } from "/colors.js"
import defaultShapes from "/default-shapes.js"
import { ShapeDrawer, defaultShape } from "./draw-shape.js"
import { LinkDrawer } from "./link-drawer.js"
import { extractWorldShape, usePatchCoords, useWrapping, drawTurtle, drawLabel } from "./draw-utils.js"
import { followWholeUniverse } from "./window-generators.js"

{ unique } = tortoise_require('brazier/array')
AgentModel = tortoise_require('agentmodel')

createLayerManager = (fontSize) ->
  turtles = new TurtleLayer(fontSize)
  # patches = new PatchLayer()
  # drawing = new DrawingLayer()
  world = new CompositeLayer([turtles### , patches, drawing ###])
  # spotlight = new SpotlightLayer()
  # all = new ComboLayer([world, spotlight])

  new LayerManager({
    'turtles': turtles,
    # 'patches': patches,
    # 'drawing': drawing,
    'world': world,
    # 'spotlight': spotlight,
    # 'all': all
  })

class ViewController
  constructor: (fontSize) ->
    @_layerManager = createLayerManager(fontSize)
    @_layerUseCount = {} # Stores how many views are using each layer.
    @_views = []
    @_model = undefined
    @resetModel()
    @repaint()

  # TODO refactor the rest of the engine so that we don't need to loop for each property
  # i.e. report all of x, y, mouseDown, mouseInside using the single method "getMouseState"
  mouseInside: => @getMouseState().mouseInside
  mouseXcor: => @getMouseState().mouseX # could be undefined if the mouse is not inside
  mouseYcor: => @getMouseState().mouseY # could be undefined if the mouse is not inside
  mouseDown: => @getMouseState().mouseDown # could be undefined if the mouse is not inside

  # Unit -> { mouseInside: boolean, mouseDown: boolean | undefined, mouseX: number | undefined, mouseY: number | undefined }
  getMouseState: ->
    for view in @_views
      if view.mouseInside
        return {
          mouseInside: true,
          mouseDown: view.mouseDown,
          mouseX: view.getMouseXCor(),
          mouseY: view.getMouseYCor(),
        }
    { mouseInside: false }

  resetModel: ->
    @_model = new AgentModel()
    @_model.world.turtleshapelist = defaultShapes

  repaint: ->
    @_layerManager.repaintLayers(
      @_model,
      Object.keys(@_layerUseCount).filter((layerName) => @_layerUseCount[layerName] > 0)
    )
    for view in @_views
      view.repaint(@_model)

  # (Update|Array[Update]) => Unit
  _applyUpdateToModel: (modelUpdate) ->
    updates = if Array.isArray(modelUpdate) then modelUpdate else [modelUpdate]
    @_model.update(u) for u in updates
    return

  # (Update|Array[Update]) => Unit
  update: (modelUpdate) ->
    @_applyUpdateToModel(modelUpdate)
    @repaint()
    return

  getPogViewWindow: (container, layerName) ->
    @getNewViewWindow(container, followWholeUniverse(@_model), layerName)

  # returns a new ViewWindow that controls the specified container
  # The returned ViewWindow must be destructed before it is dropped.
  getNewViewWindow: (container, getWindowRect, layerName) ->
    if !@_layerUseCount[layerName]? then @_layerUseCount[layerName] = 0
    ++@_layerUseCount[layerName]
    do => # create a new scope so that the `firstUnused` variable is protected from mutation by
          # invocations of `getNewViewWindow`
      # find the first unused index
      firstUnused = @_views.find((element) -> element?) ? @_views.length
      @_views.push(new View(
        container,
        @_layerManager.getLayer(layerName),
        getWindowRect,
        () =>
          @_views[firstUnused] = null
          container.replaceChildren()
      ))
    @_views.at(-1)

# Each view into the NetLogo universe. Assumes that the canvas element that is used has no padding.
class View
  # _getWindowRect: (Unit) -> { x, y, width, height }; returns the
  # dimensions (in patch coordinates) of the window that this view looks at.
  constructor: (container, @_sourceLayer, @_getWindowRect, @destructor) ->
    # clients of this class should only read, not write to, these public properties
    @mouseInside = false # the other mouse data members are only valid if this is true
    @mouseDown = false
    @mouseX = 0 # where the mouse is in pixels relative to the canvas
    @mouseY = 0

    @cornerX = undefined # the top left corner of this view window in patch coordinates
    @cornerY = undefined
    @width = undefined # the width and height of this view window in patch coordinates
    @height = undefined

    @_visibleCanvas = document.createElement('canvas')
    @_visibleCanvas.classList.add('netlogo-canvas', 'unselectable')
    @_visibleCtx = @_visibleCanvas.getContext('2d')
    container.appendChild(@_visibleCanvas)

    @_initMouseTracking()
    @_initTouchTracking()

  # Unit -> Number
  # Returns the mouse coordinates in model coordinates
  getMouseXCor: -> @xPixToPcor(@mouseX)
  getMouseYCor: -> @yPixToPcor(@mouseY)

  # Unit -> Unit
  _initMouseTracking: ->
    @_visibleCanvas.addEventListener('mousedown', => @mouseDown = true)
    document.addEventListener('mouseup', => @mouseDown = false)

    @_visibleCanvas.addEventListener('mouseenter', => @mouseInside = true)
    @_visibleCanvas.addEventListener('mouseleave', => @mouseInside = false)

    @_visibleCanvas.addEventListener('mousemove', (e) =>
      # rect = @_visibleCanvas.getBoundingClientRect()
      # @mouseX = e.clientX - rect.left
      # @mouseY = e.clientY - rect.top
      @mouseX = e.offsetX
      @mouseY = e.offsetY
    )

  # Unit -> Unit
  _initTouchTracking: ->
    # event -> Unit
    endTouch = (e) =>
      @mouseDown   = false
      @mouseInside = false
      return

    # Touch -> Unit
    trackTouch = ({ clientX, clientY }) =>
      { bottom, left, top, right } = @_visibleCanvas.getBoundingClientRect()
      if (left <= clientX <= right) and (top <= clientY <= bottom)
        @mouseInside = true
        @mouseX      = clientX - left
        @mouseY      = clientY - top
      else
        @mouseInside = false
      return

    document.addEventListener('touchend',    endTouch)
    document.addEventListener('touchcancel', endTouch)
    @_visibleCanvas.addEventListener('touchmove', (e) =>
      e.preventDefault()
      trackTouch(e.changedTouches[0])
      return
    )
    @_visibleCanvas.addEventListener('touchstart', (e) =>
      @mouseDown = true
      trackTouch(e.touches[0])
      return
    )

    return

  # Sets the dimensions of this View's visible canvas; doesn't change the part of the source layer
  # being copied.
  setDimensions: (width, height, quality) ->
    @_visibleCanvas.width = width * quality
    @_visibleCanvas.height = height * quality
    @_visibleCanvas.style.width = "#{width}px"
    @_visibleCanvas.style.height = "#{height}px"

  # Repaints the visible canvas and updates the object such that mouse tracking is relative to the
  # new frame.
  repaint: ->
    @_visibleCtx.clearRect(0, 0, @_visibleCanvas.width, @_visibleCanvas.height);
    { x: @cornerX, y: @cornerY, width: @width, height: @height } = @_getWindowRect()
    { canvas: sourceCanvas, worldShape } = @_sourceLayer.getImageAndWorldShape()
    { quality, patchsize, actualMinX, actualMinY } = worldShape
    scale = quality * patchsize
    @_visibleCtx.drawImage(
      sourceCanvas,
      (@cornerX - actualMinX) * scale, (@cornerY - actualMinY) * scale, @width * scale, @height * scale,
      0, 0, @_visibleCanvas.width, @_visibleCanvas.height
    )
    # TODO handle wrapping

  # These convert between model coordinates and position in the canvas DOM element
  # This will differ from untransformed canvas position if @quality != 1. BCH 5/6/2015
  xPixToPcor: (xPix) ->
    (@cornerX + xPix / @_visibleCanvas.clientWidth * @width)
  yPixToPcor: (yPix) ->
    (@cornerY + yPix / @_visibleCanvas.clientHeight * @height)

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
  # Array[String]-> Unit
  repaintLayers: (model, layerNames) ->
    worldShape = extractWorldShape(model.world)
    layersToRepaint = unique(layerNames.flatMap((layerName) => @_dependencies[layerName]))
    for layer in layersToRepaint
      layer.repaint(worldShape, model)

###
Interface for parts of the full view universe.
###
class Layer
  constructor: ->
    @_latestWorldShape = undefined # stores the latest world shape when this layer is repainted so
                                   # that it can drawTo properly

  # (Unit) -> { image: HTMLCanvasElement, worldShape }
  # Returns a source canvas from which another canvas can `drawImage` onto itself. This canvas
  # should not be modified. Unless this layer is repainted, the returned canvas should always hold
  # the same image.
  # Prefer to use `drawTo` when possible.
  # This is a default implementation that works, but if it ends up being used, it's probably a sign
  # that the layer should be refactored to get its own internal canvas which can be directly
  # returned.
  getImageAndWorldShape: ->
    canvas = document.createElement('canvas')
    ctx = canvas.getContext('2d')
    @drawTo(ctx)
    { canvas, worldShape: @_latestWorldShape }

  # Draws the rectangle from this layer onto the specified context. Assumes that the destination
  # context is correctly sized to hold the whole image from this layer.
  drawTo: (context) ->

  # Updates the current layer assuming that all its dependencies are up-to-date. Doesn't necessarily
  # update an internal canvas, but it must be enough for the `drawTo` method to accurately
  # draw this layer to another. Overriding methods should still call `super(worldShape, model)` to
  # ensure that @_latestWorldShape is updated.
  repaint: (worldShape, model) ->
    @_latestWorldShape = worldShape

  # Returns an array of all this layer's direct dependencies
  getDirectDependencies: -> []

filteredByBreed = (agents, breeds) ->
  # TODO is it necessary that we draw agents by breed? We can optimize this generator if we draw
  # agents in the order that they're given. --Andre C.
  breededAgents = {}
  for _, agent of agents
    members = []
    breedName = agent.breed.toUpperCase()
    if not breededAgents[breedName]?
      breededAgents[breedName] = members
    else
      members = breededAgents[breedName]
    members.push(agent)
  for breedName in breeds
    if breededAgents[breedName]?
      members = breededAgents[breedName]
      for agent in members
        yield agent

# CompositeLayer forms its image by sequentially copying over the images from its source layers.
class CompositeLayer extends Layer
  constructor: (@_sourceLayers) ->
    super()
    @_canvas = document.createElement('canvas')
    @_ctx = @_canvas.getContext('2d')

  getImageAndWorldShape: ->
    { canvas: @_canvas, worldShape: @_latestWorldShape }

  drawTo: (context) ->
    context.drawImage(@_canvas, 0, 0)

  repaint: (worldShape, model) ->
    super(worldShape, model)
    { worldWidth, worldHeight, patchsize, quality } = worldShape
    @_canvas.width = worldWidth * patchsize * quality
    @_canvas.height = worldHeight * patchsize * quality
    @_canvas.style.width = "#{worldWidth * patchsize}px"
    @_canvas.style.height = "#{worldHeight * patchsize}px"
    # TODO should we keep these, or move them somewhere else?  Also note that I got rid of the font thing
    @_ctx.imageSmoothingEnabled = false
    @_ctx.webkitImageSmoothingEnabled = false
    @_ctx.mozImageSmoothingEnabled = false
    @_ctx.oImageSmoothingEnabled = false
    @_ctx.msImageSmoothingEnabled = false
    for layer in @_sourceLayers
      layer.drawTo(@_ctx)

  getDirectDependencies: -> @_sourceLayers

class TurtleLayer extends Layer
  constructor: (@_fontSize) ->
    super()
    @_latestModel = undefined # stores the latest model from when this layer was repainted so that
                              # it can drawTo properly

  drawTo: (context) ->
    { world, turtles, links } = @_latestModel
    turtleDrawer = new ShapeDrawer(world.turtleshapelist ? {}, @_latestWorldShape.onePixel)
    linkDrawer = new LinkDrawer(@_latestWorldShape, context, world.linkshapelist ? {}, @_fontSize)
    usePatchCoords(
      @_latestWorldShape,
      context,
      (context) =>
        for link from filteredByBreed(links, world.linkbreeds ? ["LINKS"])
          linkDrawer.draw(
            link,
            turtles[link.end1],
            turtles[link.end2],
            world.wrappingallowedinx,
            world.wrappingallowediny
          )
        context.lineWidth = @_latestWorldShape.onePixel # TODO can be more elegant?
        for turtle from filteredByBreed(turtles, world.turtlebreeds ? ["TURTLES"])
          drawTurtle(turtleDrawer, @_latestWorldShape, context, turtle, false, @_fontSize)
    )

  repaint: (worldShape, model) ->
    super(worldShape, model)
    @_latestModel = model

  getDirectDependencies: -> []

export default ViewController
