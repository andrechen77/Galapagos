###
This file defines generators (more precisely, iterators) that are used to get the window that a
specific view should be looking at. Each value returned should be one of:
- null, meaning the whole universe should be shown
- { x, y }, meaning a rectangle with its top left corner at (x, y) and the same dimensions as the
  previous rectangle.
- { x, y, h }, meaning a rectangle with a new corner and height; the width should be
  whatever it takes to keep the same aspect ratio as the previous rectangle.
- { x, y, h, w }, meaning a rectangle with completely new dimensions.
###

followWholeUniverse = () ->
  loop
    yield null

followAgent = (agent) ->
  yield {
    x: agent.xcor - 10,
    y: agent.ycor + 10,
    w: 20,
    h: 20
  }
  loop
    yield {
      x: agent.xcor - 10
      y: agent.ycor + 10
    }

followAgentChangeAspRatio = (agent) ->
  width = 20
  loop
    yield {
      x: agent.xcor - 10,
      y: agent.ycor + 10,
      h: 20,
      w: width
    }
    width += 1
    if width > 100 then width = 20

followAgentPreserveAspRatio = (agent) ->
  sideLength = 100
  yield {
    x: agent.xcor - sideLength / 2,
    y: agent.ycor + sideLength / 2,
    h: sideLength
    w: sideLength
  }
  loop
    yield {
      x: agent.xcor - sideLength / 2,
      y: agent.ycor + sideLength / 2,
      h: sideLength
    }
    sideLength -= 1
    if sideLength <= 0 then sideLength = 100

export {
  followWholeUniverse,
  followAgent,
  followAgentChangeAspRatio,
  followAgentPreserveAspRatio
}