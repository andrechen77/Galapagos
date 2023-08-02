import RactiveWidget from "./widget.js"

RactiveContextMenu = Ractive.extend({

  data: -> {
    options: undefined # ContextMenuOptions
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
    @fire('unlock-selection')
    return

  # Returns whether the context menu actually revealed itself, which will not happen if there are no options to display.
  # (Ractive, number, number) -> boolean
  reveal: (component, x, y) ->
    options = component?.getContextMenuOptions(x, y) ? []
    visible = options.length > 0
    @set({
      target: component,
      options,
      visible,
      mouseX: x,
      mouseY: y
    })

    if component instanceof RactiveWidget
      @fire('lock-selection', component)

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
