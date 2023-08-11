import defaultShapes from "/default-shapes.js"
import { CompositeLayer } from "./composite-layer.js"
import { TurtleLayer } from "./turtle-layer.js"
import { PatchLayer } from "./patch-layer.js"
import { DrawingLayer } from "./drawing-layer.js"
import { SpotlightLayer } from "./spotlight-layer.js"
import { HighlightLayer } from "./highlight-layer.js"
import { setImageSmoothing, clearCtx, extractWorldShape } from "./draw-utils.js"

AgentModel = tortoise_require('agentmodel')

# TODO type signature
initLayers = (layerDeps) ->
  # Tis important that we don't access the properties of `layerDeps` except within the client code using `layerDeps`,
  # because the identities of the objects will change (see "./layers.coffee"'s comment on layer dependencies' for why).
  turtles = new TurtleLayer(-> layerDeps)
  patches = new PatchLayer(-> layerDeps)
  drawing = new DrawingLayer(-> layerDeps)
  world = new CompositeLayer([patches, drawing, turtles], -> layerDeps)
  spotlight = new SpotlightLayer(-> layerDeps)
  highlight = new HighlightLayer(-> layerDeps)
  all = new CompositeLayer([world, spotlight, highlight], -> layerDeps)
  { turtles, patches, drawing, world, spotlight, highlight, all }

class ViewController
  # (Unit) -> Unit
  constructor: ->
    @resetModel() # defines `@_model`
    @_layerDeps = {
      model: {
        model: @_model
        worldShape: extractWorldShape(@_model)
        highlightedAgents: []
      },
      quality: { quality: Math.max(window.devicePixelRatio ? 2, 2) },
      font: {
        fontFamily: '"Lucida Grande", sans-serif',
        fontSize: 50 # some random number; can be set by the client
      }
    }
    @_layers = initLayers(@_layerDeps)

    repaint = => @repaint()
    drawingLayer = @_layers.drawing
    allLayer = @_layers.all
    @configShims = {
      importImage: (b64, x, y) -> drawingLayer.importImage(b64, x, y).then(repaint),
      getViewBase64: -> allLayer.getCanvas().toDataURL("image/png"),
      getViewBlob: (callback) -> allLayer.getCanvas().toBlob(callback, "image/png")
    }

    @_views = [] # Stores the views themselves; some values might be null for destructed views
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
    @repaint()
    return

  mouseInside: => @_sharedMouseState.inside # (Unit) -> boolean
  mouseXcor: => @_sharedMouseState.x # (Unit) -> number; patch coordinates
  mouseYcor: => @_sharedMouseState.y # (Unit) -> number; patch coordinates
  mouseDown: => @_sharedMouseState.down # (Unit) -> boolean

  # Forces the mouse state to consider the mouse as not being clicked. Only lasts until the next time the presses the
  # mouse or begins a touch.
  # (Unit) -> Unit
  forceMouseUp: -> @_sharedMouseState.down = false

  # (Unit) -> Unit
  resetModel: ->
    @_model = new AgentModel()
    @_model.world.turtleshapelist = defaultShapes
    return

  # (Unit) -> AgentModel
  getModel: => @_model

  # (Unit) -> WorldShaspe
  getWorldShape: => @_layerDeps.model.worldShape

  # (Unit) -> Unit
  repaint: ->
    for view in @_views when view?
      view.repaint()
    return

  # (Update|Array[Update]) => Unit
  _applyUpdateToModel: (modelUpdate) ->
    updates = if Array.isArray(modelUpdate) then modelUpdate else [modelUpdate]
    @_model.update(u) for u in updates
    return

  # (Update|Array[Update]) => Unit
  update: (modelUpdate) ->
    @_applyUpdateToModel(modelUpdate)
    @_layerDeps.model = {
      @_layerDeps.model...,
      worldShape: extractWorldShape(@_model.world)
    }
    @repaint()
    @_model.drawingEvents = []
    return

  # (number) -> Unit
  setQuality: (quality) ->
    # It's important that we create a new object instead of setting the property on the old object.
    @_layerDeps.quality = { quality }
    @repaint()
    return

  # (Array[Agent]) -> Unit
  # where `Agent` is the actual agent object as opposed to the `AgentModel` analogue
  setHighlightedAgents: (highlightedAgents) ->
    # It's important that we create a new object instead of simply setting the property on the old `@_layerDeps.model`
    # object.
    @_layerDeps.model = { @_layerDeps.model..., highlightedAgents }
    @repaint()
    return

  # We have the `avoidRepaint` parameter because the view widget sets the font size while rendering, but the world is
  # not ready to render yet. I'd like to see a way to eliminate this mess.
  # (string?, number?, boolean) -> Unit
  setFont: (fontFamily, fontSize, avoidRepaint = false) ->
    fontFamily or= @_layerDeps.font.fontFamily
    fontSize or= @_layerDeps.font.fontSize
    # It's important that we create a new object instead of setting the properties on the old one.
    @_layerDeps.font = { fontFamily, fontSize }
    if not avoidRepaint then @repaint()
    return

  # Returns a new WindowView that controls the specified container
  # The returned View must be destructed before it is dropped.
  # (Node, string, Iterator<Rectangle>) -> WindowView
  getNewView: (container, layerName, windowRectGen) ->
    layer = @_layers[layerName]
    sharedMouseState = @_sharedMouseState
    @_registerView((unregisterThisView) ->
      new View(container, layer, sharedMouseState, windowRectGen, unregisterThisView)
    )

  # Using the passed in `createView` function, creates and registers a new View to this
  # ViewController, then returns that view. The `createView` function should handle everything
  # involved with creating the view, except for the View's unregister function, which it takes as
  # a parameter (because it's only during the registration process that the unregister function
  # can be determined).
  # (((Unit) -> Unit) -> View) -> View
  _registerView: (createView) ->
    # find the first unused index to put this view
    index = @_views.findIndex((element) -> not element?)
    if index is -1 then index = @_views.length
    # Create a new scope so that variables are protected in case someone decides to create
    # like-named variables in a higher scope, thus causing CoffeeScript to destroy this scope.
    # CoffeeScript issues ;-; --Andre C.
    return do (index) =>
      unregisterThisView = =>
        @_views[index] = null
      view = createView(unregisterThisView)
      @_views[index] = view
      return view

# Each view into the NetLogo universe.
# Takes an iterator that returns Rectangles (see "./window-generators.coffee" for type info) to determine which part of
# the universe to observe, as well as the size of the canvas.
class View
  # _sharedMouseState: see comment in ViewController
  # (Node, Layer, { x: number, y: number, inside: boolean, down: boolean }, Iterator<Rectangle>, (Unit) -> Unit) -> Unit
  constructor: (@_container, @_sourceLayer, @_sharedMouseState, @_windowRectGen, @_unregisterThisView) ->
    # Track the dimensions of the window rectangle currently being displayed so that we know when the canvas
    # dimensions need to be updated.
    @_windowCornerX = undefined
    @_windowCornerY = undefined
    @_windowWidth = undefined
    @_windowHeight = undefined

    @_quality = 1

    @_latestWorldShape = undefined # tracked so that the `pixToPcor` methods can handle wrapping

    # N.B.: since the canvas's dimensions might often change, the canvas is always kept at its
    # default drawing state (no transformations, no fillStyle, etc.) except temporarily when it is
    # actively being drawn to.
    @_visibleCanvas = document.createElement('canvas')
    @_visibleCanvas.classList.add('netlogo-canvas', 'unselectable')
    @_visibleCtx = @_visibleCanvas.getContext('2d')
    setImageSmoothing(@_visibleCtx, false)
    @_container.appendChild(@_visibleCanvas)

    @_initMouseTracking()
    @_initTouchTracking()
    return

  # (Unit) -> DOMRect
  getBoundingClientRect: -> @_visibleCanvas.getBoundingClientRect()

  # Note: For proper mouse and touch tracking, the <canvas> element must have no padding or border. This is because the
  # `offsetX` and `offsetY` properties plus the client bounding box, used in the mouse-tracking functions, account for
  # padding and/or border, which we do not want.

  # (number, number) -> Unit
  _updateMouseLoc: (xPix, yPix) ->
    xPcor = @xPixToPcor(xPix)
    yPcor = @yPixToPcor(yPix)
    if not xPcor? or not yPcor?
      # Mouse is outside the world boundaries.
      @_sharedMouseState.inside = false
      # Leave the `.x` and `.y` properties untouched, so that they report the coordinates the last time the mouse was
      # inside.
    else
      @_sharedMouseState.inside = true
      @_sharedMouseState.x = xPcor
      @_sharedMouseState.y = yPcor
    # Leave the `.down` property untouched, since that doesn't care about whether the mouse is outside world
    # boundaries, in parity with NetLogo Desktop behavior. (This might change, and IMO should)

  # Unit -> Unit
  _initMouseTracking: ->
    @_visibleCanvas.addEventListener('mousedown', => @_sharedMouseState.down = true)
    @_visibleCanvas.addEventListener('mouseup', => @_sharedMouseState.down = false)
    @_visibleCanvas.addEventListener('mousemove', (e) => @_updateMouseLoc(e.offsetX, e.offsetY))
    @_visibleCanvas.addEventListener('mouseleave', =>
      @_sharedMouseState.inside = false
      @_sharedMouseState.down = false
    )
    return

  # Unit -> Unit
  _initTouchTracking: ->
    # event -> Unit
    endTouch = =>
      @_sharedMouseState.inside = false
      @_sharedMouseState.down   = false
      return

    # Touch -> Unit
    trackTouch = ({ clientX, clientY }) =>
      { left, top, right, bottom } = @_visibleCanvas.getBoundingClientRect()
      if (left <= clientX <= right) and (top <= clientY <= bottom)
        # equivalent to a "mousemove" event
        @_updateMouseLoc(clientX - left, clientY - top)
      else
        # equivalent to a "mouseleave" event
        @_sharedMouseState.inside = false
        @_sharedMouseState.down = false
      return

    @_visibleCanvas.addEventListener('touchend',    endTouch)
    @_visibleCanvas.addEventListener('touchcancel', endTouch)
    @_visibleCanvas.addEventListener('touchmove', (e) =>
      e.preventDefault()
      trackTouch(e.changedTouches[0])
      return
    )
    @_visibleCanvas.addEventListener('touchstart', (e) =>
      @_sharedMouseState.down = true
      trackTouch(e.touches[0])
      return
    )
    return

  # (number) -> Unit
  setQuality: (@_quality) ->

  # Repaints the visible canvas, updating its dimensions. Overriding methods should call `super()`.
  # (Unit) -> Unit
  repaint: ->
    # Just because the source layer didn't change since the last time *it* was repainted, doesn't mean that it hasn't
    # changed since the last time *this view* was repainted, so don't short circuit even if `repaint` returns false.
    @_sourceLayer.repaint()
    @_latestWorldShape = @_sourceLayer.getWorldShape()
    @_updateDimensionsAndClear(@_windowRectGen.next().value)
    @_sourceLayer.drawRectTo(@_visibleCtx, @_windowCornerX, @_windowCornerY, @_windowWidth, @_windowHeight)
    return

  # Updates this view's canvas dimensions, as well as the `_windowWidth` and `_windowHeight` properties to match the
  # aspect ratio of the specified Rectangle, and clears the visible canvas.
  # (Rectangle) -> { x: number, y: number, w: number, h: number }
  # See "./window-generators.coffee" for type info on "Rectangle"
  _updateDimensionsAndClear: ({ x: @_windowCornerX, y: @_windowCornerY, w, h, canvasHeight }) ->
    # See if the height has changed.
    if not h? or h is @_windowHeight
      # The new rectangle has the same dimensions as the old.
      @_setCanvasDimensionsAndClear(canvasHeight, false)
      return

    # Now we know the rectangle must specify a new height.
    @_windowHeight = h

    # See if the width has changed.
    if not w? or w is @_windowWidth
      # Since the rectangle did not specify a new width, we should calculate the width ourselves
      # to maintain the aspect ratio. We use the canvas dimensions to calculate the aspect ratio since
      # they haven't changed from the last frame, whereas `@_windowHeight` has.
      @_windowWidth = h * @_visibleCanvas.width / @_visibleCanvas.height
      @_setCanvasDimensionsAndClear(canvasHeight, false)
      return

    # Now we know the rectangle must specify a new width and the aspect ratio might change.
    @_windowWidth = w
    @_setCanvasDimensionsAndClear(canvasHeight, true)
    return

  # Ensures that the canvas is property sized to have the specified height while maintaining the aspect ratio specified
  # by `@_windowWidth` and @_windowHeight`. `canvasHeight` can be optional, in which case it will keep the same height
  # and maintain aspect ratio.
  _setCanvasDimensionsAndClear: (canvasHeight, changedAspRatio) ->
    if canvasHeight? and canvasHeight * @_quality isnt @_visibleCanvas.height
      # The canvas height must change.
      @_visibleCanvas.height = canvasHeight * @_quality
      @_visibleCanvas.width = @_visibleCanvas.height * @_windowWidth / @_windowHeight
      @_visibleCanvas.style.height = canvasHeight
    else if changedAspRatio
      # The canvas height did not change but the aspect ratio did.
      @_visibleCanvas.width = @_visibleCanvas.height * @_windowWidth / @_windowHeight
    else
      # Neither the canvas height not the aspect ratio changed; just clear the canvas and be done with it.
      clearCtx(@_visibleCtx)

  # These convert between model coordinates and position in the canvas DOM element
  # This will differ from untransformed canvas position if quality != 1. BCH 5/6/2015
  # Return null if the point lies outside the moudel coordinates.
  # (number) -> number | null
  xPixToPcor: (xPix) ->
    { actualMinX, actualMaxX, worldWidth, wrapX } = @_latestWorldShape
    # Calculate the patch coordinate by extrapolating from the window dimensions and the point's
    # relative position to the window, ignoring possible wrapping.
    rawPcor = @_windowCornerX + xPix / @_visibleCanvas.clientWidth * @_windowWidth
    if wrapX
      # Account for wrapping in the world.
      (rawPcor - actualMinX) %% worldWidth + actualMinX
    else if actualMinX <= rawPcor and rawPcor <= actualMaxX
      rawPcor
    else
      null
  yPixToPcor: (yPix) ->
    { actualMinY, actualMaxY, worldHeight, wrapY } = @_latestWorldShape
    # Calculate the patch coordinate by extrapolating from the window dimensions and the point's
    # relative position to the window, ignoring possible wrapping.
    rawPcor = @_windowCornerY - yPix / @_visibleCanvas.clientHeight * @_windowHeight
    if wrapY
      # Account for wrapping in the world
      (rawPcor - actualMinY) %% worldHeight + actualMinY
    else if actualMinY <= rawPcor and rawPcor <= actualMaxY
      rawPcor
    else
      null

  # (Unit) -> Unit
  destructor: ->
    @_container.replaceChildren()
    @_unregisterThisView()
    return

export default ViewController
