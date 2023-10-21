import RactiveValueWidget from "./value-widget.js"
import EditForm from "./edit-form.js"
import { RactiveEditFormCheckbox } from "./subcomponent/checkbox.js"
import RactiveEditFormCode from "./subcomponent/edit-form-code-input.js"
import RactiveEditFormVariable from "./subcomponent/variable.js"
import RactiveEditFormSpacer from "./subcomponent/spacer.js"
import { RactiveEditFormLabeledInput } from "./subcomponent/labeled-input.js"

# coffeelint: disable=max_line_length
FlexColumn = Ractive.extend({
  template:
    """
    <div class="flex-column" style="align-items: stretch; flex-grow: 1; max-width: 140px;">
      {{ yield }}
    </div>
    """
})

SliderEditForm = EditForm.extend({

  data: -> {
    bottom:    undefined # Number
  , direction: undefined # String
  , left:      undefined # Number
  , maxCode:   undefined # String
  , minCode:   undefined # String
  , right:     undefined # Number
  , stepCode:  undefined # String
  , top:       undefined # Number
  , units:     undefined # String
  , value:     undefined # Number
  , variable:  undefined # String
  }

  twoway: false

  components: {
    column:       FlexColumn
  , formCheckbox: RactiveEditFormCheckbox
  , formMaxCode:  RactiveEditFormCode
  , formMinCode:  RactiveEditFormCode
  , formStepCode: RactiveEditFormCode
  , formVariable: RactiveEditFormVariable
  , labeledInput: RactiveEditFormLabeledInput
  , spacer:       RactiveEditFormSpacer
  }

  genProps: (form) ->

    value = Number.parseFloat(form.value.value)

    oldTop    = @get('top')
    oldRight  = @get('right')
    oldBottom = @get('bottom')
    oldLeft   = @get('left')

    [right, bottom] =
      if (@get('direction') is 'horizontal' and     form.vertical.checked) or
         (@get('direction') is 'vertical'   and not form.vertical.checked)
        [oldLeft + (oldBottom - oldTop), oldTop + (oldRight - oldLeft)]
      else
        [oldRight, oldBottom]

    {
            bottom
    , currentValue: value
    ,      default: value
    ,    direction: (if form.vertical.checked then "vertical" else "horizontal")
    ,      display: form.variable.value
    ,          max: @findComponent('formMaxCode' ).get('code')
    ,          min: @findComponent('formMinCode' ).get('code')
    ,        right
    ,         step: @findComponent('formStepCode').get('code')
    ,        units: (if form.units.value isnt "" then form.units.value else undefined)
    ,     variable: form.variable.value.toLowerCase()
    }

  partials: {

    title: "Slider"

    widgetFields:
      """
      <formVariable id="{{id}}-varname" name="variable" value="{{variable}}"/>

      <spacer height="15px" />

      <div class="flex-row" style="align-items: stretch; justify-content: space-around">
        <column>
          <formMinCode id="{{id}}-min-code" label="Minimum" name="minCode" {{! config="{ scrollbarStyle: 'null' }" }}
                       parseMode="onelinereporter"
                       value="{{minCode}}" />
        </column>
        <column>
          <formStepCode id="{{id}}-step-code" label="Increment" name="stepCode" {{! config="{ scrollbarStyle: 'null' }" }}
                        parseMode="onelinereporter"
                        value="{{stepCode}}" />
        </column>
        <column>
          <formMaxCode id="{{id}}-max-code" label="Maximum" name="maxCode" {{! config="{ scrollbarStyle: 'null' }" }}
                       parseMode="onelinereporter"
                       value="{{maxCode}}" />
        </column>
      </div>

      <div class="widget-edit-hint-text" style="margin-left: 4px; margin-right: 4px;">min, increment, and max may be numbers or reporters</div>

      <div class="flex-row" style="align-items: center;">
        <labeledInput id="{{id}}-value" labelStr="Default value:" name="value" type="number" value="{{value}}" attrs="required step='any'"
                      style="flex-grow: 1; text-align: right;" />
        <labeledInput id="{{id}}-units" labelStr="Units:" labelStyle="margin-left: 10px;" name="units" type="text" value="{{units}}"
                      style="flex-grow: 1; " />
      </div>

      <spacer height="15px" />

      <formCheckbox id="{{id}}-vertical" isChecked="{{ direction === 'vertical' }}" labelText="Vertical?"
                    name="vertical" />
      """

  }

})

RactiveSlider = RactiveValueWidget.extend({

  data: -> {
    errorClass:         undefined # String
  , internalValue:      0         # Number
  }

  widgetType: "slider"

  on: {
    'reset-if-invalid': (context) ->
      # input elements don't reject out-of-range hand-typed numbers so we have to do the dirty work
      if (context.node.validity.rangeOverflow)
        @set('internalValue', @get('widget.maxValue'))
      else if (context.node.validity.rangeUnderflow)
        @set('internalValue', @get('widget.minValue'))

      @fire('widget-value-change')
      return
  }

  computed: {
    resizeDirs: {
      get: -> if @get('widget.direction') isnt 'vertical' then ['left', 'right'] else ['top', 'bottom']
      set: (->)
    }
    textWidth: ->
      internalValue = @get('internalValue')
      if internalValue?
        (internalValue.toString().length) + 3.0
      else
        3
  }

  components: {
    editForm: SliderEditForm
  }

  eventTriggers: ->
    {
      currentValue: [@_weg.updateEngineValue]
    ,          max: [@_weg.recompile]
    ,          min: [@_weg.recompile]
    ,         step: [@_weg.recompile]
    ,     variable: [@_weg.recompile, @_weg.rename]
    }

  minWidth:  60
  minHeight: 33

  template:
    """
    {{>editorOverlay}}
    {{>slider}}
    <editForm direction="{{widget.direction}}" idBasis="{{id}}" maxCode="{{widget.max}}"
              minCode="{{widget.min}}" stepCode="{{widget.step}}" units="{{widget.units}}"
              top="{{widget.top}}" right="{{widget.right}}" bottom="{{widget.bottom}}"
              left="{{widget.left}}" value="{{widget.default}}" variable="{{widget.variable}}" />
    """

  partials: {

    slider:
      """
      <label id="{{id}}" class="netlogo-widget netlogo-slider netlogo-input {{errorClass}} {{classes}}"
             style="{{ #widget.direction !== 'vertical' }}{{dims}}{{else}}{{>verticalDims}}{{/}}">
        <input
          type="range"
          max="{{widget.maxValue}}"
          min="{{widget.minValue}}"
          step="{{widget.stepValue}}"
          value="{{internalValue}}"
          on-change="widget-value-change"
          {{# isEditing }}disabled{{/}} />
        <div class="netlogo-slider-label">
          <span class="netlogo-label" on-click="['show-widget-errors', widget]">{{widget.display}}</span>
          <span class="netlogo-slider-value">
            <input
              type="number"
              on-change="reset-if-invalid"
              style="width: {{textWidth}}ch"
              min="{{widget.minValue}}"
              max="{{widget.maxValue}}"
              step="{{widget.stepValue}}"
              value="{{internalValue}}"
              {{# isEditing }}disabled{{/}} />
            {{#widget.units}}{{widget.units}}{{/}}
          </span>
        </div>
      </label>
      """

    verticalDims:
      """
      position: absolute;
      left: {{ left }}px; top: {{ top }}px;
      width: {{ bottom - top }}px; height: {{ right - left }}px;
      transform: translateY({{ bottom - top }}px) rotate(270deg);
      transform-origin: top left;
      """

  }

})
# coffeelint: enable=max_line_length

export default RactiveSlider
