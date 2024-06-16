import { netlogoColorToHexString, hexStringToNetlogoColor, netlogoColorToRGBA } from "/colors.js"
import ColorPicker from '@netlogo/netlogo-color-picker'
{ arrayEquals } = tortoise_require("brazier/equals")

RactiveColorInput = Ractive.extend({

  data: -> {
    class:      undefined # String
  , id:         undefined # String
  , isEnabled:  true      # Boolean
  , name:       undefined # String
  , style:      undefined # String
  , value:      undefined # [number, number, number, number]; RBGA value
  }

  on: {
    'click': ->
      # Check if the ColorPicker is already open
      if document.querySelector('#colorPickerDiv')
        return

      cpDiv = document.createElement('div')
      cpDiv.id = 'colorPickerDiv'
      @find(".color-picker-temporary-holder").appendChild(cpDiv)

      currentRgba = netlogoColorToRGBA(@get('value'))
      new ColorPicker({
        parent: cpDiv,
        initColor: currentRgba,
        onColorSelect: ([selectedColor, savedColors]) =>
          { netlogo, rgba } = selectedColor
          [r, g, b, a] = rgba
          # replace with netlogo color number if it is an exact match
          newValue = if a == 255 and arrayEquals([r, g, b])(ColorModel.colorToRGB(netlogo))
            netlogo
          else
            rgba
          @set('value', newValue)
          @fire('change')
          cpDiv.remove()
          return
        savedColors: []
      })
      @fire('popup-window', {}, cpDiv)

      false

    render: ->
      @observe('value', (newValue, oldValue) ->
        if newValue isnt oldValue
          [r, g, b, a] = netlogoColorToRGBA(newValue)
          a /= 255 # because CSS alpha values are 0.0 - 1.0 instead of 0 - 255
          div = @find('.netlogo-color-display')
          imageCss = "linear-gradient(to right, rgba(#{r}, #{g}, #{b}, #{a}), rgba(#{r}, #{g}, #{b}, #{a}))"
          div.style.backgroundImage = imageCss
        return
      )

      return

  }

  template:
    """
    <div class="color-picker-temporary-holder" style="display: none;"></div>
    <div
      id="{{id}}"
      class="netlogo-color-display {{class}}"
      name="{{name}}"
      style="{{style}}"
      on-click="click"
      {{# !isEnabled }}disabled{{/}}
    >
      <span>{{value}}</span>
    </div>
    """

})

export default RactiveColorInput
