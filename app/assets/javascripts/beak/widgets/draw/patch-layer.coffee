import { usePatchCoords, drawLabel } from "./draw-utils.js"
import { Layer } from "./layer.js"
import { netlogoColorToRGB } from "/colors.js"

clearPatches = (ctx) ->
  ctx.fillStyle = "black"
  ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height)

colorPatches = (ctx, worldShape, patches) ->
  { worldWidth, worldHeight } = worldShape
  ctx.canvas.width = worldWidth
  ctx.canvas.height = worldHeight
  imageData = ctx.createImageData(worldWidth, worldHeight)
  numPatches = worldWidth * worldHeight
  for i in [0...numPatches] # Is there a reason we iterate by number instead of directly?
    patch = patches[i]
    j = 4 * i
    [r, g, b] = netlogoColorToRGB(patch.pcolor)
    imageData.data[j + 0] = r
    imageData.data[j + 1] = g
    imageData.data[j + 2] = b
    imageData.data[j + 3] = 255
  ctx.putImageData(imageData, 0, 0)

labelPatches = (ctx, worldShape, patches, fontSize) ->
  usePatchCoords(
    worldShape,
    ctx,
    (ctx) ->
      for _, patch of patches
        drawLabel(
          worldShape,
          ctx,
          patch.pxcor + 0.5,
          patch.pycor - 0.5,
          patch.plabel,
          patch['plabel-color'],
          fontSize
        )
  )

# Works by creating a scratchCanvas that has a pixel per patch. Those pixels
# are colored accordingly. Then, the scratchCanvas is drawn onto the main
# canvas scaled. This is very, very fast. It also prevents weird lines between
# patches.
class PatchLayer extends Layer
  constructor: (@_fontSize) ->
    super()
    @_canvas = document.createElement('canvas')
    @_ctx = @_canvas.getContext('2d')

  drawTo: (context) ->
    context.drawImage(@_canvas, 0, 0, context.canvas.width, context.canvas.height)
    if @_latestModel.world.patcheswithlabels
      labelPatches(context, @_latestWorldShape, @_latestModel.patches, @_fontSize)

  repaint: (worldShape, model) ->
    super(worldShape, model)
    if model.world.patchesallblack
      clearPatches(@_ctx)
    else
      colorPatches(@_ctx, worldShape, model.patches)

  getDirectDependencies: -> []

export {
  PatchLayer
}