import { extractWorldShape } from "./draw-utils.js"

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
    [x, y, size] = getDimensions(@agent) # note that for some reason the returned size is actually twice agent._size
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

# TODO Ideally we'd want to reuse the `getDimensions` function in "./perspective-utils.coffee" to find the dimensions of
# the agent, but since the agent argument that we have access to here is is taken directly from the model, while the
# other `getDimensions` function was designed for agents of the duplicate AgentModel used in ViewController, the code
# cannot be reused. When unification of the models happens, this should be revisited.
getDimensions = (agent) ->
  if agent.xcor?
    [agent.xcor, agent.ycor, 2 * agent._size]
  else if agent.pxcor?
    [agent.pxcor, agent.pycor, 2]
  else
    [agent.midpointx, agent.midpointy, agent._size]

export {
  followWholeUniverse,
  followAgentWithZoom
}
