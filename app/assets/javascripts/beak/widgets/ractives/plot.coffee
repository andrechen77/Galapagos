import { hexStringToNetlogoColor, netlogoColorToRGB } from "/colors.js"

import EditForm                         from "./edit-form.js"
import { RactiveEditFormCheckbox }      from "./subcomponent/checkbox.js"
import { RactiveTwoWayCheckbox }        from "./subcomponent/checkbox.js"
import RactiveEditFormCode              from "./subcomponent/edit-form-code-input.js"
import RactiveColorInput                from "./subcomponent/color-input.js"
import { RactiveEditFormLabeledInput }  from "./subcomponent/labeled-input.js"
import RactiveEditFormSpacer            from "./subcomponent/spacer.js"
import RactiveWidget                    from "./widget.js"
{ all } = tortoise_require('brazier/array')

PlotEditForm = {}

# (Number|(Number, Number, Number)|(Number, Number, Number, Number)) => Number
nlToAWT = (nlc) ->
  [r, g, b] = netlogoColorToRGB(nlc)
  (-1 << 24) + (r << 16) + (g << 8) + b

PenForm = Ractive.extend({

  data: -> {
    color:              undefined # Number
  , display:            undefined # String
  , index:              undefined # Number
  , interval:           undefined # Number
  , isExpanded:         false
  , modeIndex:          undefined # Number
  , setupCode:          undefined # String
  , shouldShowInLegend: undefined # Boolean
  , updateCode:         undefined # String
  , parentEditor:       null # GalapagosEditor | null
  , setupCodeErrors: [] # Array[RuntimeError]
  , updateCodeErrors: [] # Array[RuntimeError]

    # (string) -> Unit
  , syncSetupCode: (code) ->
      @set('setupCode', code)

    # (string) -> Unit
  , syncUpdateCode: (code) ->
      @set('updateCode', code)
  }

  components: {
    colorInput:   RactiveColorInput
  , formCheckbox: RactiveTwoWayCheckbox
  , formCode:     RactiveEditFormCode
  , labeledInput: RactiveEditFormLabeledInput
  , spacer:       RactiveEditFormSpacer
  }

  computed: {

    id: -> "#{@parent.get('id')}-pen-#{@get('index')}"

    mode: {
      get: -> ['Line', 'Bar', 'Point'][@get('modeIndex')]
      set: (x) -> @set('modeIndex', ['Line', 'Bar', 'Point'].indexOf(x))
    }

    # You'd think that we would already have a NetLogo color here.  You would be wrong.
    # Instead, we have a Java AWT bitmasked color, which needs to be split into its
    # RGB components, and then converted into a NetLogo color. --Jason B. (4/7/21)
    nlColor: {

      get: ->

        # Converts component to hex --Jason B. (3/29/22)
        f = (comp) -> Number(comp).toString(16).padStart(2, '0')

        c = @get('color')

        r = (c & 0xFF0000) >> 16
        g = (c & 0x00FF00) >>  8
        b = (c & 0x0000FF)

        hexStringToNetlogoColor("##{f(r)}#{f(g)}#{f(b)}")

      set: (nlc) ->
        @set('color', nlToAWT(nlc))
        return

    }

  }

  on: {
    'remove-pen': ->
      @parent.fire('remove-child-pen', @get('index'))
      false

    # (Context) => Boolean
    'validate-name': ({ ractive }) ->

      node     = @getTitleElem()
      myName   = node.value.toUpperCase()
      penForms = ractive.parent.findAllComponents("formPen")

      pred = (pf) -> pf.get("display").toUpperCase() is myName and pf isnt ractive

      validityStr =
        if penForms.some(pred)
          "There is already a pen with the name '#{node.value}'"
        else
          ""

      node.setCustomValidity(validityStr)

      false

    'new-compilation-result': (_, result) ->
      newData = { setupCodeErrors: [], updateCodeErrors: [] }
      regex = RegExp("^pen '#{@get('display')}' - pen.(\\w+):(?: (.*))?$")
      for message in result.messages
        [_, fieldName, messageContent] = message.match(regex) ? []
        [errorArray, source] = switch fieldName
          when "setup" then [newData.setupCodeErrors, @get('setupCode')]
          when "update" then [newData.updateCodeErrors, @get('updateCode')]
          else
            console.error("Failed to interpret Tortoise error message: %s", message)
            [[], ""] # return dummy values that won't affect anything
        errorArray.push({ message: messageContent, start: 0, end: source.length })
      @set(newData)
      false

  }

  # () => HTMLInputElement
  getTitleElem: ->
    @find("##{@get("id")}-name")

  # coffeelint: disable=max_line_length
  template:
    """
    <div class="flex-column plot-pen-row{{#isExpanded}} open{{/}}">
      <div class="flex-row">
        <label for="{{id}}-is-expanded" class="expander widget-edit-checkbox-wrapper">
          <input id="{{id}}-is-expanded" class="widget-edit-checkbox"
                 style="display: none;" type="checkbox"
                 checked="{{isExpanded}}" twoway="true" />
          <span class="widget-edit-input-label expander-label">&#9654;</span>
        </label>
        <colorInput id="{{id}}-color" name="color" value="{{nlColor}}" style="min-height: 33px; min-width: 33px;" />
        <input id="{{id}}-name" name="name" type="text" placeholder="(Required)"
               class="widget-edit-text widget-edit-input widget-edit-inputbox"
               style="border-radius: 4px; margin: auto 10px;" value="{{display}}"
               on-input="validate-name" required />
        <input class="plot-pen-delete" type="button" on-click="remove-pen" value="Delete" />
      </div>
      {{# isExpanded }}
        <spacer height="10px" />
        <div class="flex-row" style="justify-content: space-between;">
          <select id="{{id}}-mode" name="mode" class="widget-edit-dropdown" style="margin-left: 0; width: 80px;" value="{{mode}}">
            <option value="Line" >Line </option>
            <option value="Bar"  >Bar  </option>
            <option value="Point">Point</option>
          </select>
          <div>
            <label for="{{id}}-interval" class="widget-edit-input-label" style="margin-right: 5px;">Interval:</label>
            <input id="{{id}}-interval" name="interval" class="widget-edit-text widget-edit-input widget-edit-inputbox"
                   style="margin: 0 10px 0 0; width: 70px;" min="0" max="10000" type="number" step="any" value="{{interval}}">
          </div>
          <formCheckbox id="{{id}}-in-legend?" isChecked={{shouldShowInLegend}} labelText="In legend?" name="legend" />
        </div>
        <spacer height="10px" />
        <formCode
          id="{{id}}-setup-code"
          name="setupCode"
          codeContainerType="embedded"
          onchange={{syncSetupCode}}
          value="{{setupCode}}"
          label="Pen setup commands"
          parentEditor={{parentEditor}}
          compilerErrors={{setupCodeErrors}}
        />
        <spacer height="10px" />
        <formCode
          id="{{id}}-update-code"
          name="updateCode"
          codeContainerType="embedded"
          onchange={{syncUpdateCode}}
          value="{{updateCode}}"
          label="Pen update commands"
          parentEditor={{parentEditor}}
          compilerErrors={{updateCodeErrors}}
        />
        <spacer height="10px" />
      {{/}}
    </div>
    """
  # coffeelint: enable=max_line_length

})

PlotEditForm = EditForm.extend({

  data: -> {
    autoPlotOn: undefined # Boolean
  , display:    undefined # String
  , guiPens:    undefined # Array[Pen]
  , legendOn:   undefined # Boolean
  , pens:       undefined # Array[Pen]
  , setupCode:  undefined # String
  , updateCode: undefined # String
  , xLabel:     undefined # String
  , xMax:       undefined # Number
  , xMin:       undefined # Number
  , yLabel:     undefined # String
  , yMax:       undefined # Number
  , yMin:       undefined # Number
  , parentEditor: null # GalapagosEditor | null
  , setupCodeErrors: [] # Array[RuntimeError]
  , updateCodeErrors: [] # Array[RuntimeError]
  }

  components: {
    formCheckbox: RactiveEditFormCheckbox
  , formCode:     RactiveEditFormCode
  , formPen:      PenForm
  , labeledInput: RactiveEditFormLabeledInput
  , spacer:       RactiveEditFormSpacer
  }

  twoway: false

  _oldName:     undefined # String
  _trackedPens: undefined # Array[{ name :: String, pen :: Pen }]

  # (Array[Pen]) => Array[Pen]
  _clonePens: (pens) ->
    clone = window.structuredClone ? (x) -> JSON.parse(JSON.stringify(x))
    clone(pens)

  # () => String
  getOldName: ->
    @_oldName

  # () => Object[String]
  getRenamings: ->
    f =
      (acc, { name, pen: { display } }) ->
        if name isnt display
          acc[name] = display
        acc
    @_trackedPens.reduce(f, {})

  genProps: (form) ->

    getCode =
      (ractive) -> (elemID) ->
        ractive.findAllComponents('formCode').
          find((x) -> x.get('id') is elemID).
          get('code')

    name = if form.name.length? then form.name[0].value else form.name.value

    extras = { recompileForPlot: @get('amProvingMyself') }

    guiPens = @get('guiPens')

    pens = @_clonePens(guiPens)

    replaceIfEmpty = (str, replace) -> if str is '' then replace else str

    {  autoPlotOn: form.autoPlotOn.checked
    ,     display: name
    ,    legendOn: form.legendOn.checked
    ,        pens
    ,   setupCode: getCode(this)("#{@get('id')}-setup-code" )
    ,  updateCode: getCode(this)("#{@get('id')}-update-code")
    ,       xAxis: replaceIfEmpty(form.xLabel.value, null)
    ,        xmax: form.xMax.valueAsNumber
    ,        xmin: form.xMin.valueAsNumber
    ,       yAxis: replaceIfEmpty(form.yLabel.value, null)
    ,        ymax: form.yMax.valueAsNumber
    ,        ymin: form.yMin.valueAsNumber
    ,    __extras: extras
    }

  on: {

    'add-new': ->

      baseColors =
        for n in [0..13]
          5 + 10 * n

      oldColors  = @findAllComponents('formPen').map((form) -> form.get('nlColor'))
      usedColors = new Set(oldColors)

      nlColor = baseColors.find((c) -> not usedColors.has(c)) ? 0
      color   = nlToAWT(nlColor)

      number = @get('guiPens').length + 1

      freshPen =
        { color, display: "Pen #{number}", inLegend: true, interval: 1
        , mode: 0, setupCode: '', type: "pen", updateCode: ''
        }

      @get('guiPens').push(freshPen)

      @update('guiPens')

      forms = @findAllComponents('formPen')

      newForm = forms[forms.length - 1]
      newForm.set('isExpanded', true)
      newForm.fire('validate-name')

      false

    'cancel-edit': ->
      @set('guiPens', [])
      true

    init: ->
      @_oldName     = ""
      @_trackedPens = []
      if not @get('pens')?
        @set('pens', [])
      @set('guiPens', [])
      @set('validateTitle', @validateTitle)

    'remove-child-pen': (_, index) ->
      @splice('guiPens', index, 1)
      false

    'show-yourself': ->
      @_oldName     = @get('display')
      cloned        = @_clonePens(@get('pens'))
      @_trackedPens = cloned.map((pen) -> { name: pen.display, pen })
      @set('guiPens', cloned)
      true

    'new-compilation-result': (_, widgetObj) ->
      newData = { setupCodeErrors: [], updateCodeErrors: [] }
      regex = RegExp("^plot '#{@get('display')}' - plot.(\\w+):(?: (.*))?$")
      for message in widgetObj.compilation.messages
        [_, fieldName, messageContent] = message.match(regex) ? []
        [errorArray, source] = switch fieldName
          when "setup" then [newData.setupCodeErrors, @get('setupCode')]
          when "update" then [newData.updateCodeErrors, @get('updateCode')]
          else
            console.error("Failed to interpret Tortoise error message: %s", message)
            [[], ""] # return dummy values that won't affect anything
        errorArray.push({ message: messageContent, start: 0, end: source.length })
      @set(newData)

      for penForm, index in @findAllComponents('formPen')
        penForm.fire("new-compilation-result", {}, widgetObj.compiledPens[index].compilation)

      false

  }

  # (Context) => Boolean
  validateTitle: (context) ->

    { node, ractive } = context

    myName = node.value.toUpperCase()

    myWidget = ractive.parent.parent.get("widget")
    widgets  = Object.values(ractive.parent.parent.parent.get("widgetObj"))
    plots    = widgets.filter((w) -> w.type is "plot")

    validityStr =
      if plots.some((p) -> p.display.toUpperCase() is myName and p isnt myWidget)
        "There is already a plot with the name '#{node.value}'"
      else
        ""

    node.setCustomValidity(validityStr)

    false

  partials: {

    title: "Plot"

    # coffeelint: disable=max_line_length
    widgetFields:
      """
      <spacer height="15px" />
      <div class="flex-column plot-editor" style="align-items: center;">
        <labeledInput id="{{id}}-name" labelStr="Name:" name="name" type="text"
                      class="widget-edit-inputbox" placeholder="(Required)"
                      value="{{display}}" onInput="{{validateTitle}}"
                      attrs="required" />
        <spacer height="10px" />
        <div class="flex-row" style="justify-content: space-evenly;">
          <div class="flex-column">
            <div class="flex-row">
              <label for="{{id}}-x-label" class="widget-edit-input-label" style="margin-right: 0px; min-width: 70px;">X label:</label>
              <input id="{{id}}-x-label" name="xLabel" class="widget-edit-text widget-edit-input widget-edit-inputbox" type="text" value="{{xLabel}}">
            </div>
            <spacer height="5px" />
            <div class="flex-row">
              <label for="{{id}}-x-min" class="widget-edit-input-label" style="margin-right: 0px; min-width: 70px;">X min:</label>
              <input id="{{id}}-x-min" name="xMin" class="widget-edit-text widget-edit-input widget-edit-inputbox" type="number" value="{{xMin}}" step="any">
            </div>
            <spacer height="5px" />
            <div class="flex-row">
              <label for="{{id}}-x-max" class="widget-edit-input-label" style="margin-right: 0px; min-width: 70px;">X max:</label>
              <input id="{{id}}-x-max" name="xMax" class="widget-edit-text widget-edit-input widget-edit-inputbox" type="number" value="{{xMax}}" step="any">
            </div>
          </div>
          <spacer width="20px" />
          <div class="flex-column">
            <div class="flex-row">
              <label for="{{id}}-y-label" class="widget-edit-input-label" style="margin-right: 0px; min-width: 70px;">Y label:</label>
              <input id="{{id}}-y-label" name="yLabel" class="widget-edit-text widget-edit-input widget-edit-inputbox" type="text" value="{{yLabel}}">
            </div>
            <spacer height="5px" />
            <div class="flex-row">
              <label for="{{id}}-y-min" class="widget-edit-input-label" style="margin-right: 0px; min-width: 70px;">Y min:</label>
              <input id="{{id}}-y-min" name="yMin" class="widget-edit-text widget-edit-input widget-edit-inputbox" type="number" value="{{yMin}}" step="any">
            </div>
            <spacer height="5px" />
            <div class="flex-row">
              <label for="{{id}}-y-max" class="widget-edit-input-label" style="margin-right: 0px; min-width: 70px;">Y max:</label>
              <input id="{{id}}-y-max" name="yMax" class="widget-edit-text widget-edit-input widget-edit-inputbox" type="number" value="{{yMax}}" step="any">
            </div>
          </div>
        </div>
        <spacer height="10px" />
        <div class="flex-row" style="justify-content: space-evenly; width: 100%;">
          <formCheckbox id="{{id}}-auto-scale"  isChecked={{autoPlotOn}} labelText="Auto scale?"     name="autoPlotOn" />
          <formCheckbox id="{{id}}-show-legend" isChecked={{legendOn}}   labelText="Display legend?" name="legendOn"   />
        </div>
        <spacer height="10px" />
        <div class="flex-column" style="justify-content: left; width: 100%;">
          <formCode id="{{id}}-setup-code" isCollapsible="true" isExpanded="false"
                    codeContainerType="embedded"
                    value="{{setupCode}}" label="Plot setup commands"
                    style="width: 100%;"
                    parentEditor={{parentEditor}}
                    compilerErrors={{setupCodeErrors}}/>
        </div>
        <spacer height="10px" />
        <div class="flex-column" style="justify-content: left; width: 100%;">
          <formCode id="{{id}}-update-code" isCollapsible="true" isExpanded="false"
                    codeContainerType="embedded"
                    value="{{updateCode}}" label="Plot update commands"
                    style="width: 100%;"
                    parentEditor={{parentEditor}}
                    compilerErrors={{updateCodeErrors}}/>
        </div>
        <spacer height="10px" />
        <div class="flex-column" style="justify-content: left; margin-left: 18px; width: 100%;">Plot pens</div>
        <div style="border: 2px solid black; overflow-y: auto; width: 95%;">
          {{#each guiPens: index}}
            <formPen color="{{color}}" display="{{display}}" index="{{index}}"
                     interval="{{interval}}" modeIndex="{{mode}}" setupCode="{{setupCode}}"
                     shouldShowInLegend="{{inLegend}}" updateCode="{{updateCode}}"
                     parentEditor={{parentEditor}}/>
          {{/each}}
          <input type="button" on-click="@this.fire('add-new')" style="height: 26px; margin: 8px 0 8px 6px;" value="Add Pen" />
        </div>
      </div>
      <spacer height="10px" />
      """
    # coffeelint: enable=max_line_length

  }

})

RactivePlot = RactiveWidget.extend({

  data: -> {
    menuIsOpen:     false
  , resizeCallback: ((x, y) ->)
  , parentEditor:   null # GalapagosEditor | null
  }

  components: {
    editForm: PlotEditForm
  }

  eventTriggers: ->
    { autoPlotOn: [@_weg.recompileForPlot]
    ,    display: [@_weg.recompileForPlot]
    ,   legendOn: [@_weg.recompileForPlot]
    ,       pens: [@_weg.recompileForPlot]
    ,  setupCode: [@_weg.recompileForPlot]
    , updateCode: [@_weg.recompileForPlot]
    ,      xAxis: [@_weg.recompileForPlot]
    ,       xmax: [@_weg.recompileForPlot]
    ,       xmin: [@_weg.recompileForPlot]
    ,      yAxis: [@_weg.recompileForPlot]
    ,       ymax: [@_weg.recompileForPlot]
    ,       ymin: [@_weg.recompileForPlot]
    }

  observe: {
    'left right top bottom': ->
      @get('resizeCallback')(@get('right') - @get('left'), @get('bottom') - @get('top'))
      return
  }

  on: {

    render: ->

      ractive          = this
      topLevel         = document.querySelector("##{@get('id')}")
      topLevelObserver = new MutationObserver(
        (mutations) -> mutations.forEach(
          ({ addedNodes }) ->
            container = Array.from(addedNodes).find((elem) -> elem.classList.contains("highcharts-container"))
            if container?
              topLevelObserver.disconnect()
              containerObserver = new MutationObserver(
                (mutties) -> mutties.forEach(
                  ({ addedNodes: addedNodies }) ->
                    menu = Array.from(addedNodies).find((elem) -> elem.classList.contains("highcharts-contextmenu"))
                    if menu?
                      ractive.set('menuIsOpen', true)
                      containerObserver.disconnect()
                      menuObserver = new MutationObserver(-> ractive.set('menuIsOpen', menu.style.display isnt "none"))
                      menuObserver.observe(menu, { attributes: true })
                )
              )
              containerObserver.observe(container, { childList: true })
        )
      )
      topLevelObserver.observe(topLevel, { childList: true })

  }

  # (Widget) => Array[Any]
  getExtraNotificationArgs: () ->
    widget = @get('widget')
    [widget.display]

   # () => boolean
  getCompilationSuccess: ->
    widgetObj = @get('widget')
    widgetObj.compilation.success and all((pen) -> pen.compilation.success)(widgetObj.compiledPens)

  minWidth:  100
  minHeight: 85

  # coffeelint: disable=max_line_length
  template:
    """
    {{>editorOverlay}}
    <div id="{{id}}" class="netlogo-widget netlogo-plot {{classes}}"
         style="{{dims}}{{#menuIsOpen}}z-index: 10;{{/}}"></div>
    <editForm autoPlotOn={{widget.autoPlotOn}} display="{{widget.display}}" idBasis="{{id}}"
              legendOn={{widget.legendOn}} pens="{{widget.pens}}"
              setupCode="{{widget.setupCode}}" updateCode="{{widget.updateCode}}"
              xLabel="{{widget.xAxis}}" xMin="{{widget.xmin}}" xMax="{{widget.xmax}}"
              yLabel="{{widget.yAxis}}" yMin="{{widget.ymin}}" yMax="{{widget.ymax}}"
              parentEditor={{parentEditor}}/>
    """
  # coffeelint: enable=max_line_length

})

export default RactivePlot
