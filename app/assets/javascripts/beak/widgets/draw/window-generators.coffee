import { extractWorldShape } from "./draw-utils.js"
import { getDimensionsDirect } from "./perspective-utils.js"

###
This file defines generators (more precisely, iterators) that are used to get the window that a
specific view should be looking at. Each value returned should be of Rectangle type:
- { x, y }, meaning a rectangle with its top left corner at (x, y) and the same dimensions as the
  previous rectangle.
- { x, y, h }, meaning a rectangle with a new corner and height; the width should be
  whatever it takes to keep the same aspect ratio as the previous rectangle.
- { x, y, h, w }, meaning a rectangle with completely new dimensions.
###

followWholeUniverse = (world) ->
  loop
    { actualMinX, actualMaxY, worldWidth, worldHeight } = extractWorldShape(world)
    yield {
      x: actualMinX,
      y: actualMaxY,
      w: worldWidth,
      h: worldHeight
    }

# Returns an iterator that generates windows following the specified agent. If the zoomRadius is specified during
# construction or later set to a number, that will be the Moore radius of the window. Otherwise, the zoomRadius will
# depend on the size of the agent (TODO how?).
# (Agent, number | null) -> Iterator<Rectangle>
# where Rectangle is defined above in the comment;
# can also safely set the public properties `agent` and `zoomRadius`
followAgentWithZoom = (agent, zoomRadius = null) -> return {
  agent,
  zoomRadius,
  next: ->
    [x, y, size] = getDimensionsDirect(@agent) # note that for some reason this is actually twice the agent size
    r = @zoomRadius ? size
    return {
      value: {
        x: x - r,
        y: y + r,
        w: r * 2,
        h: r * 2
      },
      done: false
    }
}

export {
  followWholeUniverse,
  followAgentWithZoom
}
