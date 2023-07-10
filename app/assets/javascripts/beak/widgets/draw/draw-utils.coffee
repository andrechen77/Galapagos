import { netlogoColorToCSS } from "/colors.js"

# Given an World, returns WorldShape, an object with properties of the world relevant to rendering
extractWorldShape = (world) ->
  worldShape = {
    # note on "actual": the so-called "min"/"max" coordinates are actually the *center* of the
    # extreme patches, meaning there are actually 0.5 units of space beyond the "min/max"
    # coordinates. Doing that extra addition now saves us from littering our code with +0.5 and -0.5
    # and +1.
    actualMinX: (world.minpxcor ? -25) - 0.5,
    actualMaxX: (world.maxpxcor ? 25) + 0.5,
    actualMinY: (world.minpycor ? -25) - 0.5,
    actualMaxY: (world.maxpycor ? 25) + 0.5,
    patchsize: world.patchsize ? 9,
    wrapX: world.wrappingallowedinx,
    wrapY: world.wrappingallowediny,
  }
  worldShape.onePixel = 1 / worldShape.patchsize
  worldShape.worldWidth = worldShape.actualMaxX - worldShape.actualMinX
  worldShape.worldHeight = worldShape.actualMaxY - worldShape.actualMinY
  worldShape.worldCenterX = (worldShape.actualMaxX + worldShape.actualMinX) / 2
  worldShape.worldCenterY = (worldShape.actualMaxY + worldShape.actualMinY) / 2
  worldShape

clearCtx = (ctx) ->
  ctx.save()
  ctx.resetTransform()
  ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height)
  ctx.restore()

# Makes sure that the canvas is properly sized to the world, using quality and patchsize to
# calculate pixel density. Avoids resizing the canvas if possible, as that is an expensive
# operation. (https://stackoverflow.com/a/6722031). Returns whether the canvas dimensions changed.
resizeCanvas = (canvas, worldShape, quality) ->
  { worldWidth, worldHeight, patchsize } = worldShape
  newWidth = worldWidth * patchsize * quality
  newHeight = worldHeight * patchsize * quality
  changed = false
  if canvas.width != newWidth
    canvas.width = newWidth
    changed = true
  if canvas.height != newHeight
    canvas.height = newHeight
    changed = true
  changed

# Draws a rectangle (specified in patch coordinates) from a source canvas to a destination canvas,
# assuming that neither canvas has transformations and scaling the image to fit the destination.
# The rectangle is specified by its top-left corner and width and height. `worldShape` and
# `srcQuality` are used to make the calculation for which pixels from the source canvas are actually
# inside the specified rectangle.
drawRectTo = (srcCanvas, dstCtx, xPcor, yPcor, wPcor, hPcor, worldShape, srcQuality) ->
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

drawFullTo = (srcCanvas, dstCtx) ->
  dstCtx.drawImage(
    srcCanvas,
    0, 0, srcCanvas.width, srcCanvas.height,
    0, 0, dstCtx.canvas.width, dstCtx.canvas.height
  )

# WorldShape, (Context, Fn) -> Unit
# where Fn: (Context) -> Unit
usePatchCoords = (worldShape, ctx, fn) ->
  ctx.save()
  # naming: world width/height and canvas width/height
  { worldWidth: ww, worldHeight: wh, actualMinX, actualMaxY } = worldShape
  { width: cw, height: ch } = ctx.canvas
  # Argument rows are the standard transformation matrix columns. See spec.
  # http://www.w3.org/TR/2dcontext/#dom-context-2d-transform
  # BCH 5/16/2015
  ctx.setTransform(
    cw / ww,                  0,
    0,                        -ch / wh,
    -actualMinX * cw / ww,    actualMaxY * ch / wh
  )
  fn(ctx)
  ctx.restore()

# Assumes that the context is already using patch coordinates.
# Fn: (Context, xcor, ycor) -> Unit
useWrapping = (worldShape, ctx, xcor, ycor, size, fn) ->
  { wrapX, wrapY, worldWidth, worldHeight, actualMinX, actualMaxX, actualMinY, actualMaxY } = worldShape
  xs = if wrapX then [xcor - worldWidth,  xcor, xcor + worldWidth ] else [xcor]
  ys = if wrapY then [ycor - worldHeight, ycor, ycor + worldHeight] else [ycor]
  for x in xs when (x + size / 2) > actualMinX and (x - size / 2) < actualMaxX
    for y in ys when (y + size / 2) > actualMinY and (y - size / 2) < actualMaxY
      fn(ctx, x, y)

# Fn: (Context) -> Unit
useCompositing = (compositingOperation, ctx, fn) ->
  oldGCO = ctx.globalCompositeOperation
  ctx.globalCompositeOperation = compositingOperation
  fn(ctx)
  ctx.globalCompositeOperation = oldGCO

drawTurtle = (turtleDrawer, worldShape, ctx, turtle, isStamp = false, fontSize = 10) ->
  if not turtle['hidden?']
    { xcor, ycor, size } = turtle
    useWrapping(worldShape, ctx, xcor, ycor, size,
      ((ctx, x, y) => drawTurtleAt(turtleDrawer, turtle, x, y, ctx)))
    if not isStamp
      drawLabel(
        worldShape,
        ctx,
        xcor + turtle.size / 2,
        ycor - turtle.size / 2,
        turtle.label,
        turtle['label-color'],
        fontSize
      )

drawTurtleAt = (turtleDrawer, turtle, xcor, ycor, ctx) ->
  heading = turtle.heading
  scale = turtle.size
  angle = (180-heading)/360 * 2*Math.PI
  shapeName = turtle.shape
  shape = turtleDrawer.shapes[shapeName] or defaultShape
  ctx.save()
  ctx.translate(xcor, ycor)
  if shape.rotate
    ctx.rotate(angle)
  else
    ctx.rotate(Math.PI)
  ctx.scale(scale, scale)
  turtleDrawer.drawShape(ctx, turtle.color, shapeName, 1 / scale)
  ctx.restore()

drawLabel = (worldShape, ctx, xcor, ycor, label, color, fontSize) ->
  label = if label? then label.toString() else ''
  if label.length > 0
    useWrapping(worldShape, ctx, xcor, ycor, label.length * fontSize / worldShape.onePixel, (ctx, x, y) =>
      ctx.save()
      ctx.translate(x, y)
      ctx.scale(worldShape.onePixel, -worldShape.onePixel)
      ctx.textAlign = 'left'
      ctx.fillStyle = netlogoColorToCSS(color)
      # This magic 1.2 value is a pretty good guess for width/height ratio for most fonts. The 2D context does not
      # give a way to get height directly, so this quick and dirty method works fine.  -Jeremy B April 2023
      lineHeight   = ctx.measureText("M").width * 1.2
      lines        = label.split("\n")
      lineWidths   = lines.map( (line) -> ctx.measureText(line).width )
      maxLineWidth = Math.max(lineWidths...)
      # This magic 1.5 value is to get the alignment to mirror what happens in desktop relatively closely.  Without
      # it, labels are too far out to the "right" of the agent since the origin of the text drawing is calculated
      # differently there.  -Jeremy B April 2023
      xOffset      = -1 * (maxLineWidth + 1) / 1.5
      lines.forEach( (line, i) ->
        yOffset = i * lineHeight
        ctx.fillText(line, xOffset, yOffset)
      )
      ctx.restore()
    )

export {
  extractWorldShape,
  resizeCanvas,
  clearCtx,
  drawRectTo,
  drawFullTo,
  usePatchCoords,
  useWrapping,
  useCompositing,
  drawTurtle,
  drawLabel
}