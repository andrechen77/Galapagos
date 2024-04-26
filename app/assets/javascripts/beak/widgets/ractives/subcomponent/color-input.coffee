import { netlogoColorToHexString, hexStringToNetlogoColor, netlogoColorToRGB } from "/colors.js"
import ColorPicker from '@netlogo/netlogo-color-picker';

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
      # Check if the ColorPicker is already open
      if document.querySelector('#colorPickerDiv')
        return

      cpDiv = document.createElement('div')
      cpDiv.id = 'colorPickerDiv'
      @find(".color-picker-temporary-holder").appendChild(cpDiv)

      currentRgba = [netlogoColorToRGB(@get('value'))..., 255]
      new ColorPicker(
        cpDiv,
        currentRgba,
        ([selectedColor, savedColors]) =>
          [r, g, b, _a] = selectedColor
          netlogoColor = ColorModel.nearestColorNumberOfRGB(r, g, b)
          @set('value', netlogoColor)
          @fire('change')
          cpDiv.remove()
          return
        []
      )
      @fire('popup-window', {}, cpDiv)

      false

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
    <div class="color-picker-temporary-holder" style="display: none;"></div>
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
