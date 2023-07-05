# Given an World, returns WorldShape, an object with properties of the world relevant to rendering
# N.B. this depends on window.devicePixelRatio (not a pure function)
extractWorldShape = (world) ->
  worldShape = {
    quality: Math.max(window.devicePixelRatio ? 2, 2),
    maxpxcor: world.maxpxcor ? 25,
    minpxcor: world.minpxcor ? -25,
    maxpycor: world.maxpycor ? 25,
    minpycor: world.minpycor ? -25,
    patchsize: world.patchsize ? 9,
    wrapX: world.wrappingallowedinx,
    wrapY: world.wrappingallowediny,
  }
  worldShape.onePixel = 1 / worldShape.patchsize
  worldShape.worldWidth = worldShape.maxpxcor - worldShape.minpxcor + 1
  worldShape.worldHeight = worldShape.maxpycor - worldShape.minpycor + 1
  worldShape.worldCenterX = (worldShape.maxpxcor + worldShape.minpxcor) / 2
  worldShape.worldCenterY = (worldShape.maxpycor + worldShape.minpycor) / 2
  worldShape

# WorldShape, (Context, Fn) -> Unit
# where Fn: (Context) -> Unit
usePatchCoords = (worldShape, ctx, fn) ->
  ctx.save()
  # naming: world width/height and canvas width/height
  { worldWidth: ww, worldHeight: wh, minpxcor, maxpycor } = worldShape
  { width: cw, height: ch } = ctx.canvas
  # Argument rows are the standard transformation matrix columns. See spec.
  # http://www.w3.org/TR/2dcontext/#dom-context-2d-transform
  # BCH 5/16/2015
  ctx.setTransform(
    cw / ww,                      0,
    0,                            -ch / wh,
    -(minpxcor-0.5) * cw / ww,    (maxpycor+0.5) * ch / wh
  )
  fn(ctx)
  ctx.restore()

# Fn: (Context, xcor, ycor) -> Unit
useWrapping = (worldShape, ctx, xcor, ycor, size, fn) ->
  { wrapX, wrapY, worldWidth, worldHeight, minpxcor, maxpxcor, minpycor, maxpycor } = worldShape
  xs = if wrapX then [xcor - worldWidth,  xcor, xcor + worldWidth ] else [xcor]
  ys = if wrapY then [ycor - worldHeight, ycor, ycor + worldHeight] else [ycor]
  for x in xs when (x + size / 2) > (minpxcor - 0.5) and (x - size / 2) < (maxpxcor + 0.5)
    for y in ys when (y + size / 2) > (minpycor - 0.5) and (y - size / 2) < (maxpycor + 0.5)
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
  usePatchCoords,
  useWrapping,
  useCompositing,
  drawTurtle,
  drawLabel
}