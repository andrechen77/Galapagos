# Makes the specified `ViewController` listen for drags. Whenever a drag is finished, the `onComplete` function is
# executed with the list of agents within the the dragged area as as argument.
# Returns an unsubscribe function that can be used to stop listening; running this function will not run `onComplete`.
# Requires the `world` global variable (of type `World`) to be available.
# (ViewController, RactiveDragSelectionBox, (Array[Agent]) -> Unit) -> (Unit) -> Unit
attachDragSelector = (viewController, dragSelectionBox, onComplete) ->
  # These coordinates are in patch coordinates.
  # Creating these variables in this private scope essentially turns them into state that is used by the handler
  # functions below.
  startX = 0
  startY = 0
  endX = 0
  endY = 0

  # (Unit) -> Array[Agent]
  getAgentsInArea = ->
    world.turtles().iterator().filter((turtle) ->
      # TODO more robust calculations that account for wrapping, mouse-out-of-bounds, mouse dragging the other way, etc.
      (startX < turtle.xcor < endX) and (startY < turtle.ycor < endY)
    )

  downHandler = ({ pageX, pageY, xPcor, yPcor }) ->
    dragSelectionBox.beginDrag(pageX, pageY)
    startX = endX = xPcor
    startY = endY = yPcor
  moveHandler = ({ pageX, pageY, xPcor, yPcor }) ->
    if dragSelectionBox.checkDragInProgress()
      dragSelectionBox.continueDrag(pageX, pageY)
      endX = xPcor
      endY = yPcor
  upHandler = ->
    dragSelectionBox.endDrag()
    onComplete(getAgentsInArea())
  unsubscribe = viewController.registerMouseListeners(downHandler, moveHandler, upHandler)
  unsubscribe

export {
  attachDragSelector
}
