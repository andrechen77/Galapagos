import defaultShapes from "/default-shapes.js"
import { LayerManager } from "./layer.js"
import { CompositeLayer } from "./composite-layer.js"
import { TurtleLayer } from "./turtle-layer.js"
import { PatchLayer } from "./patch-layer.js"
import { DrawingLayer } from "./drawing-layer.js"
import { SpotlightLayer } from "./spotlight-layer.js"
import { setImageSmoothing, resizeCanvas, clearCtx } from "./draw-utils.js"

AgentModel = tortoise_require('agentmodel')

# Due to the requirement that "config-shims.coffee" be able to have some `importImage` method to
# use, we're forced to expose the `importImage` function of the "drawing" layer, and return it
# alongside the main result of this function (which is the LayerManager).
createLayerManager = (fontSize, font) ->
  quality = Math.max(window.devicePixelRatio ? 2, 2)
  turtles = new TurtleLayer(fontSize, font)
  patches = new PatchLayer(fontSize, font)
  drawing = new DrawingLayer(quality, fontSize, font)
  world = new CompositeLayer(quality, [patches, drawing, turtles])
  spotlight = new SpotlightLayer()
  all = new CompositeLayer(quality, [world, spotlight])

  layerManager = new LayerManager({
    'turtles': turtles,
    'patches': patches,
    'drawing': drawing,
    'world': world,
    'spotlight': spotlight,
    'all': all
  })

  {
    layerManager,
    importImage: drawing.importImage.bind(drawing)
  }

class ViewController
  constructor: (fontSize) ->
    {
      layerManager: @_layerManager
      importImage
    } = createLayerManager(fontSize, '"Lucida Grande", sans-serif')
    @importImage = (b64, x, y) =>
      importImage(b64, x, y)
      .then(=> @repaint())
    @_layerUseCount = {} # Stores how many views are using each layer.
    @_views = [] # Stores the views themselves; some values might be null for destructed views
    @_model = undefined
    # _sharedMouseState is an object shared by all Views plus the ViewController that any one of
    # them can update when they have more up-to-date information about the mouse. The `x` and `y`
    # properties should be kept at their last valid positions when the mouse leaves a view, and the
    # `down` property should be set false at the same time that the mouse leaves a view. We have
    # faith that mutations to this object do not interleave; it's not likely/possible that the mouse
    # moves quickly enough to cause that.
    @_sharedMouseState = {
      inside: false,
      down: false,
      x: 0,
      y: 0
    }
    @resetModel()
    @repaint()
    return

  mouseInside: => @_sharedMouseState.inside
  mouseXcor: => @_sharedMouseState.x
  mouseYcor: => @_sharedMouseState.y
  mouseDown: => @_sharedMouseState.down

  resetModel: ->
    @_model = new AgentModel()
    @_model.world.turtleshapelist = defaultShapes
    return

  repaint: ->
    @_layerManager.repaintLayers(
      @_model,
      Object.keys(@_layerUseCount).filter((layerName) => @_layerUseCount[layerName] > 0)
    )
    for view in @_views when view?
      view.repaint(@_model)
    return

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

  # Returns a new WindowView that controls the specified container
  # The returned View must be destructed before it is dropped.
  getNewWindowView: (container, layerName, windowRectGen) ->
    layer = @_layerManager.getLayer(layerName)
    sharedMouseState = @_sharedMouseState
    @_registerView(layerName, (unregisterThisView) ->
      new WindowView(container, layer, sharedMouseState, unregisterThisView, windowRectGen)
    )

  # Returns a new FullView that controls the specified container.
  # The returned View must be destructed before it is dropped.
  getNewFullView: (container, layerName) ->
    layer = @_layerManager.getLayer(layerName)
    sharedMouseState = @_sharedMouseState
    @_registerView(layerName, (unregisterThisView) ->
      new FullView(container, layer, sharedMouseState, unregisterThisView)
    )

  # Using the passed in `createView` function, creates and registers a new View to this
  # ViewController, then returns that view. The `createView` function should handle everything
  # involved with creating the view, except for the View's unregister function, which it takes as
  # a parameter (because it's only during the registration process that the unregister function
  # can be determined).
  _registerView: (layerName, createView) ->
    if not @_layerUseCount[layerName]? then @_layerUseCount[layerName] = 0
    ++@_layerUseCount[layerName]

    # find the first unused index to put this view
    index = @_views.findIndex((element) -> not element?)
    if index is -1 then index = @_views.length
    # Create a new scope so that variables are protected in case someone decides to create
    # like-named variables in a higher scope, thus causing CoffeeScript to destroy this scope.
    # CoffeeScript issues ;-; --Andre C.
    return do (layerName, index) =>
      unregisterThisView = =>
        --@_layerUseCount[layerName]
        @_views[index] = null
      view = createView(unregisterThisView)
      @_views[index] = view
      return view

# Abstract class controlling each view into the NetLogo universe. Assumes that the canvas element
# that is used has no padding. To instantiate, requires a `repaint` method that repaints the canvas
# and updates `window...` variables to match the window that the view is looking at.
class View
  # _windowRectGen: see "./window-generators.coffee" for type info; returns the
  # dimensions (in patch coordinates) of the window that this view looks at.
  # _sharedMouseState: see comment in Viewcontroller
  constructor: (container, @_sourceLayer, @_sharedMouseState, @_unregisterThisView) ->
    @_windowCornerX = undefined # the top left corner of this view window in patch coordinates
    @_windowCornerY = undefined
    @_windowWidth = undefined # the width and height of this view window in patch coordinates
    @_windowHeight = undefined
    @_latestWorldShape = undefined # tracked so that the `pixToPcor` methods can handle wrapping

    # N.B.: since the canvas's dimensions might often change, the canvas is always kept at its
    # default drawing state (no transformations, no fillStyle, etc.) except temporarily when it is
    # actively being drawn to.
    @_visibleCanvas = document.createElement('canvas')
    @_visibleCanvas.classList.add('netlogo-canvas', 'unselectable')
    @_visibleCtx = @_visibleCanvas.getContext('2d')
    setImageSmoothing(@_visibleCtx, false)
    container.appendChild(@_visibleCanvas)

    @_initMouseTracking()
    @_initTouchTracking()
    return

  # Unit -> Unit
  _initMouseTracking: ->
    @_visibleCanvas.addEventListener('mousedown', => @_sharedMouseState.down = true)
    document.addEventListener('mouseup', => @_sharedMouseState.down = false)

    @_visibleCanvas.addEventListener('mouseenter', => @_sharedMouseState.inside = true)
    @_visibleCanvas.addEventListener('mouseleave', =>
      @_sharedMouseState.inside = false
      @_sharedMouseState.down = false
    )

    @_visibleCanvas.addEventListener('mousemove', (e) =>
      @_sharedMouseState.x = @xPixToPcor(e.offsetX)
      @_sharedMouseState.y = @yPixToPcor(e.offsetY)
    )
    return

  # Unit -> Unit
  _initTouchTracking: ->
    # event -> Unit
    endTouch = (e) =>
      @_sharedMouseState.inside = false
      @_sharedMouseState.down   = false
      return

    # Touch -> Unit
    trackTouch = ({ clientX, clientY }) =>
      { bottom, left, top, right } = @_visibleCanvas.getBoundingClientRect()
      if (left <= clientX <= right) and (top <= clientY <= bottom)
        @_sharedMouseState.inside = true
        @_sharedMouseState.x = @xPixToPcor(clientX - left)
        @_sharedMouseState.y = @yPixToPcor(clientY - top)
      else
        @_sharedMouseState.inside = false
        @_sharedMouseState.down = false
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

  # Repaints the visible canvas, updating its dimensions. Overriding methods should call `super()`.
  repaint: ->
    @_latestWorldShape = @_sourceLayer.getWorldShape()
    return

  # These convert between model coordinates and position in the canvas DOM element
  # This will differ from untransformed canvas position if quality != 1. BCH 5/6/2015
  xPixToPcor: (xPix) ->
    { actualMinX, worldWidth, wrapX } = @_latestWorldShape
    # Calculate the patch coordinate by extrapolating from the window dimensions and the point's
    # relative position to the window, ignoring possible wrapping.
    rawPcor = @_windowCornerX + xPix / @_visibleCanvas.clientWidth * @_windowWidth
    if wrapX
      # Account for wrapping in the world.
      (rawPcor - actualMinX) %% worldWidth + actualMinX
    else
      rawPcor
  yPixToPcor: (yPix) ->
    { actualMinY, worldHeight, wrapY } = @_latestWorldShape
    # Calculate the patch coordinate by extrapolating from the window dimensions and the point's
    # relative position to the window, ignoring possible wrapping.
    rawPcor = @_windowCornerY - yPix / @_visibleCanvas.clientHeight * @_windowHeight
    if wrapY
      # Account for wrapping in the world
      (rawPcor - actualMinY) %% worldHeight + actualMinY
    else
      rawPcor

  destructor: ->
    @_container.replaceChildren()
    @_unregisterThisView()
    return

# A View that takes an iterator to determine which part of the universe to display. The height of
# the view is set by the `setCanvasHeight` method, but the aspect ratio is determined by the window
# into the universe that this view looks at.
class WindowView extends View
  # _windowRectGen: see "./window-generators.coffee" for type info; returns the
  # dimensions (in patch coordinates) of the window that this view looks at.
  # _sharedMouseState: see comment in ViewController
  constructor: (container, sourceLayer, sharedMouseState, unregisterThisView, @_windowRectGen) ->
    super(container, sourceLayer, sharedMouseState, unregisterThisView)
    return

  repaint: ->
    super()
    @_updateDimensions(@_windowRectGen.next().value)
    @_sourceLayer.drawRectTo(@_visibleCtx, @_windowCornerX, @_windowCornerY, @_windowWidth, @_windowHeight)
    return

  # Sets the height of the visible canvas, maintaining aspect ratio. The width will always respect
  # the aspect ratio of the rectangles returned by the passed-in window generator.
  setCanvasHeight: (canvasHeight, quality) ->
    @_visibleCanvas.width = quality * canvasHeight * @_visibleCanvas.width / @_visibleCanvas.height
    @_visibleCanvas.height = quality * canvasHeight
    @_visibleCanvas.style.height = canvasHeight
    return

  # Takes the new windowRect object and changes this view's visible canvas dimensions to match
  # the aspect ratio of the new window. Clears the canvas as a side effect. This function tries to
  # avoid changing the canvas's dimensions when possible, as that is an expensive operation
  # (https://stackoverflow.com/a/6722031)
  # See "./window-generators.coffee" for type info on `windowRect`
  _updateDimensions: (windowRect) ->
    # The rectangle must always specify at least a new top-left corner.
    { x: @_windowCornerX, y: @_windowCornerY, w: newWindowWidth, h: newWindowHeight } = windowRect

    # See if the height has changed.
    if not newWindowHeight? or newWindowHeight is @windowHeight
      # The new rectangle has the same dimensions as the old, so there's no dimension fiddling to do.
      # Just clear the canvas and be done with it.
      clearCtx(@_visibleCtx)
      return

    # Now we know the rectangle must specify a new height.
    @_windowHeight = newWindowHeight

    # See if the width has changed.
    if newWindowWidth? and newWindowWidth isnt @windowWidth
      @_windowWidth = newWindowWidth
      # The rectangle specified a new width, and therefore the aspect ratio might change.
      @_visibleCanvas.width = @_visibleCanvas.height * newWindowWidth / newWindowHeight
    else
      # Since the rectangle did not specify a new width, we should calculate the width ourselves
      # to maintain the aspect ratio.
      @_windowWidth = newWindowHeight * @_visibleCanvas.width / @_visibleCanvas.height
      clearCtx(@_visibleCtx) # since we avoided clearing the canvas till now
    return

# A View that always displays the full NetLogo universe. The dimensions of the View are determined
# by the dimensions of the universe.
class FullView extends View
  constructor: (container, sourceLayer, sharedMouseState, unregisterThisView) ->
    super(container, sourceLayer, sharedMouseState, unregisterThisView)
    @_quality = 1
    return

  setQuality: (@_quality) ->

  repaint: ->
    super()
    @_updateDimensions()
    @_sourceLayer.drawFullTo(@_visibleCtx)
    return

  _updateDimensions: ->
    {
      actualMinX: @_windowCornerX,
      actualMinY: @_windowCornerY,
      worldWidth: @_windowWidth,
      worldHeight: @_windowHeight,
      patchsize
    } = @_latestWorldShape
    cleared = resizeCanvas(@_visibleCanvas, @_latestWorldShape, @_quality)
    if not cleared then clearCtx(@_visibleCtx)
    @_visibleCanvas.style.width = @_windowWidth * patchsize
    return

export default ViewController
