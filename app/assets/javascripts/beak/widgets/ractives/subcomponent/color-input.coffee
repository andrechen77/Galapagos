import { netlogoColorToHexString, hexStringToNetlogoColor } from "/colors.js"

RactiveColorInput = Ractive.extend({

  data: -> {
    class:      undefined # String
  , id:         undefined # String
  , isEnabled:  true      # Boolean
  , name:       undefined # String
  , style:      undefined # String
  , value:      undefined # String; represents a NetLogo color
  }

  on: {
    'click': ->
      console.log("clicked!")
      # color =
      #   try hexStringToNetlogoColor(hexValue)
      #   catch ex
      #     0
      # @set('value', color)
      # @fire('change')
      # false
      return

    render: ->
      @observe('value', (newValue, oldValue) ->
        if newValue isnt oldValue
          hexValue =
            try netlogoColorToHexString(@get('value'))
            catch ex
              "#000000"
          div = @find('.color-display')
          div.style.backgroundColor = hexValue
        return
      )

      return

  }

  template:
    """
    <div
      id="{{id}}"
      class="color-display {{class}}"
      name="{{name}}"
      style="{{style}}"
      on-click="click"
      {{# !isEnabled }}disabled{{/}}
    ></div>
    """

})

export default RactiveColorInput
