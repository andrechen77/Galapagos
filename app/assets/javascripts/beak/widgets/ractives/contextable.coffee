RactiveContextable = Ractive.extend({

  # type ContextMenuOptions = [{ text: String, isEnabled: Boolean, action: () => Unit }]

  getStandardOptions: -> {
    delete: {
      text: "Delete"
    , isEnabled: true
    , action: =>
        @fire('hide-context-menu')
        widget = @get('widget')
        @fire('unregister-widget', widget.id, false, @getExtraNotificationArgs())
    }
  , edit: { text: "Edit", isEnabled: true, action: => @fire('edit-widget') }
  }

  # (number, number) -> ContextMenuOptions
  getContextMenuOptions: (x, y) ->
    isEditing = @get('isEditing') ? false # the Ractive must have the `isEditing` property set to true
    if isEditing
      Object.values(@getStandardOptions())
    else
      []

})

export default RactiveContextable
