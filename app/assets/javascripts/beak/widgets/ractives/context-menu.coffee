RactiveContextMenu = Ractive.extend({

  data: -> {
    options: undefined # [ContextMenuOption]
  , mouseX:          0 # Number
  , mouseY:          0 # Number
  , target:  undefined # Ractive
  , visible:     false # Boolean
  }

  on: {
    'ignore-click': ->
      false
  }

  unreveal: ->
    @set('visible', false)
    return

  # Returns whether the context menu actually revealed itself, which will not happen if there are no options to display.
  # (Ractive, number, number) -> boolean
  reveal: (component, pageX, pageY) ->
    options = component?.getContextMenuOptions(pageX, pageY) ? []
    visible = options.length > 0
    @set({
      target: component,
      options,
      visible,
      mouseX: pageX,
      mouseY: pageY
    })

    # while we want the context menu to be positioned relative to the page, its
    # closest positioned ancestor is out of the Ractive's control and does not
    # have a bounding box that coincides with the page, so do some math to
    # convert to absolute position (i.e. relative to nearest positioned
    # ancestor)
    offsetParent = @find('#netlogo-widget-context-menu').offsetParent
    @set({
      mouseX: pageX - offsetParent.offsetLeft,
      mouseY: pageY - offsetParent.offsetTop
    })

    visible

  template:
    """
    {{# visible }}
    <div id="netlogo-widget-context-menu" class="widget-context-menu" style="top: {{mouseY}}px; left: {{mouseX}}px;">
      <div id="{{id}}-context-menu" class="netlogo-widget-editor-menu-items">
        <ul class="context-menu-list">
          {{# options }}
            {{# (enabler !== undefined && enabler(target)) || isEnabled }}
              <li class="context-menu-item" on-mouseup="action(target, mouseX, mouseY)">{{text}}</li>
            {{ else }}
              <li class="context-menu-item disabled" on-mouseup="ignore-click">{{text}}</li>
            {{/}}
          {{/}}
        </ul>
      </div>
    </div>
    {{/}}
    """

})

export default RactiveContextMenu
