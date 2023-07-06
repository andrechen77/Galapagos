import { netlogoColorToCSS, netlogoColorToRGB } from "/colors.js"
import defaultShapes from "/default-shapes.js"
import { ShapeDrawer, defaultShape } from "./draw-shape.js"
import { LinkDrawer } from "./link-drawer.js"
import { extractWorldShape, usePatchCoords, useWrapping, drawTurtle, drawLabel } from "./draw-utils.js"
import { followWholeUniverse } from "./window-generators.js"

{ unique } = tortoise_require('brazier/array')
AgentModel = tortoise_require('agentmodel')

createLayerManager = (fontSize) ->
  quality = Math.max(window.devicePixelRatio ? 2, 2)
  turtles = new TurtleLayer(fontSize)
  # patches = new PatchLayer()
  # drawing = new DrawingLayer()
  world = new CompositeLayer(quality, [turtles### , patches, drawing ###])
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
    @_views = [] # Stores the views themselves; some values might be null for destructed views
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
    for view in @_views when view?
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
    for view in @_views when view?
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

  # returns a new ViewWindow that controls the specified container
  # The returned ViewWindow must be destructed before it is dropped.
  getNewViewWindow: (container, windowRectGen, layerName) ->
    if !@_layerUseCount[layerName]? then @_layerUseCount[layerName] = 0
    ++@_layerUseCount[layerName]

    # find the first unused index
    firstUnused = @_views.findIndex((element) -> !element?)
    if firstUnused == -1 then firstUnused = @_views.length
    # create a new scope so that the variables specific to this one view are protected from mutation
    # by future invocations of `getNewViewWindow`; I think the `this` variable should already be
    # protected because it is bound by the fat arrow. --Andre C.
    do (layerName, firstUnused, container) =>
      return @_views[firstUnused] = new View(
        container,
        @_layerManager.getLayer(layerName),
        windowRectGen,
        () =>
          --@_layerUseCount[layerName]
          @_views[firstUnused] = null
          container.replaceChildren()
      )

# Each view into the NetLogo universe. Assumes that the canvas element that is used has no padding.
class View
  # _windowRectGen: see "./window-generators.coffee" for type info; returns the
  # dimensions (in patch coordinates) of the window that this view looks at.
  constructor: (container, @_sourceLayer, @_windowRectGen, @destructor) ->
    # clients of this class should only read, not write to, these public properties

    @mouseInside = false # the other mouse data members are only valid if this is true
    @mouseDown = false
    @mouseX = 0 # where the mouse is in pixels relative to the canvas
    @mouseY = 0

    @windowCornerX = undefined # the top left corner of this view window in patch coordinates
    @windowCornerY = undefined
    @windowWidth = undefined # the width and height of this view window in patch coordinates
    @windowHeight = undefined

    # N.B.: since the canvas's dimensions might often change, the canvas is always kept at its
    # default drawing state (no transformations, no fillStyle, etc.) except temporarily when it is
    # actively being drawn to.
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

  # Sets the height of the visible canvas, maintaining aspect ratio. The width will always respect
  # the aspect ratio of the rectangles returned by the passed-in window generator.
  setCanvasHeight: (canvasHeight, quality) ->
    @_visibleCanvas.width = quality * canvasHeight * @_visibleCanvas.width / @_visibleCanvas.height
    @_visibleCanvas.height = quality * canvasHeight
    @_visibleCanvas.style.height = "#{canvasHeight}px"

  _clearCanvas: ->
    @_visibleCtx.clearRect(0, 0, @_visibleCanvas.width, @_visibleCanvas.height);



  # Takes the new windowRect object and changes this view's visible canvas dimensions to match
  # the aspect ratio of the new window. Clears the canvas as a side effect. This function tries to
  # avoid changing the canvas's dimensions when possible, as that is an expensive operation
  # (https://stackoverflow.com/a/6722031)
  # See "./window-generators.coffee" for type info on `windowRect`
  _updateDimensions: (windowRect) ->
    # The rectangle must always specify at least a new top-left corner.
    { x: @windowCornerX, y: @windowCornerY, w: newWindowWidth, h: newWindowHeight } = windowRect

    # See if the height has changed.
    if !newWindowHeight? or newWindowHeight == @windowHeight
      # The new rectangle has the same dimensions as the old, so there's no dimension fiddling to do.
      # Just clear the canvas and be done with it.
      @_clearCanvas()
      return

    # Now we know the rectangle must specify a new height.
    @windowHeight = newWindowHeight

    # See if the width has changed.
    if newWindowWidth? and newWindowWidth != @windowWidth
      @windowWidth = newWindowWidth
      # The rectangle specified a new width, and therefore the aspect ratio might change.
      @_visibleCanvas.width = @_visibleCanvas.height * newWindowWidth / newWindowHeight
    else
      # Since the rectangle did not specify a new width, we should calculate the width ourselves
      # to maintain the aspect ratio.
      @windowWidth = newWindowHeight * @_visibleCanvas.width / @_visibleCanvas.height
      @_clearCanvas() # since we avoided clearing the canvas till now

  # Repaints the visible canvas, updating its dimensions and making it so that mouse tracking is
  # relative to the new frame.
  repaint: ->
    @_updateDimensions(@_windowRectGen.next().value)
    @_sourceLayer.drawRectTo(@_visibleCtx, @windowCornerX, @windowCornerY, @windowWidth, @windowHeight)

  # These convert between model coordinates and position in the canvas DOM element
  # This will differ from untransformed canvas position if quality != 1. BCH 5/6/2015
  xPixToPcor: (xPix) ->
    (@windowCornerX + xPix / @_visibleCanvas.clientWidth * @windowWidth)
  yPixToPcor: (yPix) ->
    (@windowCornerY - yPix / @_visibleCanvas.clientHeight * @windowHeight)

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

# Draws a rectangle (specified in patch coordinates) from a source canvas to a destination canvas,
# assuming that neither canvas has transformations and scaling the image to fit the destination.
# The rectangle is specified by its top-left corner and width and height. `worldShape` and `quality`
# are used to make the calculation for which pixels from the source canvas are actually inside the
# specified rectangle.
helperDrawRectTo = (srcCanvas, dstCtx, x, y, w, h, worldShape, quality) ->
  { patchsize, actualMinX, actualMaxY } = worldShape
  scale = quality * patchsize # the size of a patch in canvas pixels
  dstCtx.drawImage(
    srcCanvas,
    (x - actualMinX) * scale, (actualMaxY - y) * scale, w * scale, h * scale,
    0, 0, dstCtx.canvas.width, dstCtx.canvas.height
  )
  # TODO handle wrapping

###
Interface for parts of the full view universe.
###
class Layer
  constructor: ->
    @_latestWorldShape = undefined # stores the latest world shape when this layer is repainted so
                                   # that it can drawTo properly

  # Given dimensions specifying (in patch coordinates) a rectangle, draws that rectangle from this
  # layer to the specified context, scaling to fit. It is the responsibility of the caller to ensure
  # that the destination context has enough pixels to render a good-looking image. The rectangle is
  # specified by its top-left corner and width and height.
  # prefer to use `drawTo` when possible.
  # This is a default implementation that works, but if it ends up being used, is probably a sign
  # that the layer should be refactored to get its own internal canvas which can be directly used.
  drawRectTo: (ctx, x, y, w, h) ->
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
    { worldWidth, worldHeight, patchsize } = worldShape
    @_canvas.width = worldWidth * patchsize * @_quality
    @_canvas.height = worldHeight * patchsize * @_quality
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
            world.wrappingallowediny,
            context
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
