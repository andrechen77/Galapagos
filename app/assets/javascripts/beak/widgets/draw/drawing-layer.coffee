import { Layer } from "./layer.js"
import { drawTurtle } from "./draw-shape.js"
import { drawLink } from "./link-drawer.js"
import { resizeCanvas, usePatchCoords, useCompositing, useImageSmoothing } from "./draw-utils.js"

rgbToCss = ([r, g, b]) -> "rgb(#{r}, #{g}, #{b})"

compositingOperation = (mode) ->
  if mode is 'erase' then 'destination-out' else 'source-over'

makeMockTurtleObject = ({ x: xcor, y: ycor, shapeName: shape, size, heading, color }) ->
  { xcor, ycor, shape, size, heading, color }

makeMockLinkObject = ({ x1, y1, x2, y2, shapeName, color, heading, size, 'directed?': isDirected
                      , 'hidden?': isHidden, midpointX, midpointY, thickness }) ->
  end1 = { xcor: x1, ycor: y1 }
  end2 = { xcor: x2, ycor: y2 }

  mockLink = { shape: shapeName, color, heading, size, 'directed?': isDirected
                , 'hidden?': isHidden, midpointX, midpointY, thickness }

  [mockLink, end1, end2]

###
type DrawingEvent = { type: "clear-drawing" | "line" | "stamp-image" | "import-drawing" }

Possible drawing events:
{ type: "clear-drawing" }
{ type: "line", fromX, fromY, toX, toY, rgb, size, penMode }
{ type: "stamp-image", agentType: "turtle", stamp: {x, y, size, heading, color, shapeName, stampMode} }
{ type: "stamp-image", agentType: "link", stamp: {
    x1, y1, x2, y2, midpointX, midpointY, heading, color, shapeName, thickness, 'directed?', size, 'hidden?', stampMode
  }
}
{ type: "import-drawing", imageBase64 }
###

class DrawingLayer extends Layer
  constructor: (@_quality, @_fontSize, @_font) ->
    super()
    @_canvas = document.createElement('canvas')
    @_ctx = @_canvas.getContext('2d')

  blindlyDrawTo: (ctx) ->
    ctx.drawImage(@_canvas, 0, 0)

  repaint: (worldShape, model) ->
    super(worldShape, model)
    resizeCanvas(@_canvas, worldShape, @_quality)
    { world } = model
    for event in model.drawingEvents
      switch event.type
        when 'clear-drawing' then @_clearDrawing()
        when 'line' then @_drawLine(event)
        when 'stamp-image'
          switch event.agentType
            when 'turtle' then @_drawTurtleStamp(event.stamp)
            when 'link' then @_drawLinkStamp(event.stamp)
        when 'import-drawing' then @_importDrawing(event.imageBase64)
    # For those who still remember, `model.drawingEvents` is now reset by the LayerManager after
    # every layer has finished repainting.

  getDirectDependencies: -> []

  _clearDrawing: ->
    @_ctx.clearRect(0, 0, @_canvas.width, @_canvas.height)

  _drawLine: ({ rgb, size, penMode, fromX, fromY, toX, toY }) ->
    if penMode is 'up' then return

    usePatchCoords(@_latestWorldShape, @_ctx, (ctx) =>
      ctx.save()

      ctx.strokeStyle = rgbToCss(rgb)
      ctx.lineWidth   = size * @_latestWorldShape.onePixel
      ctx.lineCap     = 'round'

      ctx.beginPath()
      ctx.moveTo(fromX, fromY)
      ctx.lineTo(toX, toY)
      useCompositing(compositingOperation(penMode), ctx, (ctx) ->
        ctx.stroke()
      )

      ctx.restore()
    )

  _drawTurtleStamp: (turtleStamp) ->
    mockTurtleObject = makeMockTurtleObject(turtleStamp)
    usePatchCoords(@_latestWorldShape, @_ctx, (ctx) =>
      useCompositing(compositingOperation(turtleStamp.stampMode), ctx, (ctx) =>
        drawTurtle(@_latestWorldShape, @_latestModel.world.turtleshapelist, ctx, mockTurtleObject, true)
      )
    )

  _drawLinkStamp: (linkStamp) ->
    mockLinkObject = makeMockLinkObject(linkStamp)
    usePatchCoords(@_latestWorldShape, @_ctx, (ctx) =>
      useCompositing(compositingOperation(linkStamp.stampMode), ctx, (ctx) =>
        drawLink(
          @_latestModel.world.linkshapelist,
          mockLinkObject...,
          @_latestWorldShape,
          ctx,
          @_fontSize,
          @_font,
          true
        )
      )
    )

  _importDrawing: (base64) ->
    _clearDrawing()
    image = new Image()
    image.onload = () =>
      canvasRatio = @_canvas.width / @_canvas.height
      imageRatio  = image.width / image.height
      width  = @_canvas.width
      height = @_canvas.height
      if (canvasRatio >= imageRatio)
        # canvas is "wider" than the image, use full image height and partial width
        width = (imageRatio / canvasRatio) * @_canvas.width
      else
        # canvas is "thinner" than the image, use full image width and partial height
        height = (canvasRatio / imageRatio) * @_canvas.height

      @_ctx.drawImage(image, (@_canvas.width - width) / 2, (@_canvas.height - height) / 2, width, height)
    image.src = base64

  # x and y coordinates are given in CSS pixels not accounting for quality.
  # Because this depends on some image to load, this method returns a Promise that resolves once the
  # image has actually been drawn to this DrawingLayer.
  importImage: (base64, x, y) ->
    ctx = @_ctx
    q = @_quality
    image = new Image()
    new Promise((resolve) ->
      image.onload = ->
        useImageSmoothing(false, ctx, (ctx) =>
          ctx.drawImage(image, x * q, y * q, image.width * q, image.height * q)
        )
        resolve()
      image.src = base64 # What's the reason this line comes *after* setting image.onload? --Andre C
    )

export {
  DrawingLayer
}
