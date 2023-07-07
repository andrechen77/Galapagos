import defaultShapes from "/default-shapes.js"
import { LayerManager } from "./layer.js"
import { CompositeLayer } from "./composite-layer.js"
import { TurtleLayer } from "./turtle-layer.js"
import { PatchLayer } from "./patch-layer.js"

AgentModel = tortoise_require('agentmodel')

createLayerManager = (fontSize) ->
  quality = Math.max(window.devicePixelRatio ? 2, 2)
  turtles = new TurtleLayer(fontSize)
  patches = new PatchLayer(fontSize)
  # drawing = new DrawingLayer()
  world = new CompositeLayer(quality, [patches, turtles###, drawing ###])
  # spotlight = new SpotlightLayer()
  # all = new ComboLayer([world, spotlight])

  new LayerManager({
    'turtles': turtles,
    'patches': patches,
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

  mouseInside: => @_sharedMouseState.inside
  mouseXcor: => @_sharedMouseState.x
  mouseYcor: => @_sharedMouseState.y
  mouseDown: => @_sharedMouseState.down

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
        @_sharedMouseState,
        () =>
          --@_layerUseCount[layerName]
          @_views[firstUnused] = null
          container.replaceChildren()
      )

# Each view into the NetLogo universe. Assumes that the canvas element that is used has no padding.
class View
  # _windowRectGen: see "./window-generators.coffee" for type info; returns the
  # dimensions (in patch coordinates) of the window that this view looks at.
  # _sharedMouseState: see comment in Viewcontroller
  constructor: (container, @_sourceLayer, @_windowRectGen, @_sharedMouseState, @destructor) ->
    # clients of this class should only read, not write to, these public properties
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

export default ViewController
