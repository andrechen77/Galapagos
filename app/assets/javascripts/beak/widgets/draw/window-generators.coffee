
followWholeUniverse = (model) -> () ->
  {
    x: model.world.minpxcor - 0.5,
    y: model.world.minpycor - 0.5,
    width: model.world.maxpxcor - model.world.minpxcor + 1,
    height: model.world.maxpycor - model.world.minpycor + 1,
  }

export {
	followWholeUniverse
}