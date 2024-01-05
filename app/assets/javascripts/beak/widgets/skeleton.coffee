import RactiveLabel from "./ractives/label.js"
import RactiveInput from "./ractives/input.js"
import RactiveButton from "./ractives/button.js"
import RactiveView from "./ractives/view.js"
import RactiveSlider from "./ractives/slider.js"
import RactiveChooser from "./ractives/chooser.js"
import RactiveMonitor from "./ractives/monitor.js"
import RactiveCodePane from "./ractives/code-pane.js"
import RactiveSwitch from "./ractives/switch.js"
import RactiveHelpDialog from "./ractives/help-dialog.js"
import RactiveConsoleWidget from "./ractives/console.js"
import RactiveInspectionPane from "./ractives/inspection-pane.js"
import RactiveOutputArea from "./ractives/output.js"
import RactiveInfoTabWidget from "./ractives/info.js"
import RactiveModelTitle from "./ractives/title.js"
import RactiveStatusPopup from "./ractives/status-popup.js"
import RactivePlot from "./ractives/plot.js"
import RactiveResizer from "./ractives/resizer.js"
import RactiveAsyncUserDialog from "./ractives/async-user-dialog.js"
import RactiveContextMenu from "./ractives/context-menu.js"
import RactiveDragSelectionBox from "./ractives/drag-selection-box.js"
import RactiveEditFormSpacer from "./ractives/subcomponent/spacer.js"
import RactiveTickCounter from "./ractives/subcomponent/tick-counter.js"

# (Element, Array[Widget], String, String,
#   Boolean, NlogoSource, String, Boolean, String, (String) => Boolean, ViewController) => Ractive
generateRactiveSkeleton = (container, widgets, code, info,
  isReadOnly, source, workInProgressState, checkIsReporter, viewController) ->

  model = {
    checkIsReporter
    initialCode:          code
    consoleOutput:        ''
    exportForm:           false
    hasFocus:             false
    workInProgressState
    height:               0
    info
    isEditing:            false
    isHelpVisible:        false
    isOverlayUp:          false
    isReadOnly
    isResizerVisible:     true
    isStale:              false
    isVertical:           true
    showInspectionPane:   false
    lastCompiledCode:     code
    lastCompileFailed:    false
    lastDragX:            undefined
    lastDragY:            undefined
    modelTitle:           source.getModelTitle()
    outputWidgetOutput:   ''
    primaryView:          undefined
    someDialogIsOpen:     false
    someEditFormIsOpen:   false
    source
    viewQuality:          undefined
    speed:                0.0
    ticks:                "" # Remember, ticks initialize to nothing, not 0
    ticksStarted:         false
    widgetObj:            widgets.reduce(((acc, widget, index) -> acc[index] = widget; acc), {})
    widgetVarNames:       undefined # Array[String]
    viewController:       viewController # ViewController
    width:                0
    parentEditor:         null
    receiveParentEditor:  (editor) ->
      # `this` is intended to bind to the skeleton Ractive, not the Ractive
      # that happens to run this function. I'm not sure why this works since
      # we never bind this function but it does.
      @set('parentEditor', editor)
  }

  animateWithClass = (klass) ->
    (t, params) ->
      params = t.processParams(params)

      eventNames = ['animationend', 'webkitAnimationEnd', 'oAnimationEnd', 'msAnimationEnd']

      listener = (l) -> (e) ->
        e.target.classList.remove(klass)
        for event in eventNames
          e.target.removeEventListener(event, l)
        t.complete()

      for event in eventNames
        t.node.addEventListener(event, listener(listener))
      t.node.classList.add(klass)

  Ractive.transitions.grow   = animateWithClass('growing')
  Ractive.transitions.shrink = animateWithClass('shrinking')

  new Ractive({

    el:       container,
    template: template,
    partials: partials,

    # Required so that event propagation is properly stopped when events come from iterative sections. In particular,
    # the `contextmenu` event should sometimes be caught and handled by the widgets, instead of bubbling up to this
    # ractive instance.
    delegate: false,

    components: {

      asyncDialog:   RactiveAsyncUserDialog
    , console:       RactiveConsoleWidget
    , inspection:    RactiveInspectionPane
    , contextMenu:   RactiveContextMenu
    , dragSelectionBox: RactiveDragSelectionBox
    , editableTitle: RactiveModelTitle
    , codePane:      RactiveCodePane
    , helpDialog:    RactiveHelpDialog
    , infotab:       RactiveInfoTabWidget
    , statusPopup:   RactiveStatusPopup
    , resizer:       RactiveResizer

    , tickCounter:   RactiveTickCounter

    , labelWidget:   RactiveLabel
    , switchWidget:  RactiveSwitch
    , buttonWidget:  RactiveButton
    , sliderWidget:  RactiveSlider
    , chooserWidget: RactiveChooser
    , monitorWidget: RactiveMonitor
    , inputWidget:   RactiveInput
    , outputWidget:  RactiveOutputArea
    , plotWidget:    RactivePlot
    , viewWidget:    RactiveView

    , spacer:        RactiveEditFormSpacer

    },

    computed: {
      stateName: ->
        if @get('isEditing')
          if @get('someEditFormIsOpen')
            'authoring - editing widget'
          else
            'authoring - plain'
        else
          'interactive'

      isRevertable: ->
        not @get('isEditing') and @get('hasWorkInProgress')

      disableWorkInProgress: ->
        @get('workInProgressState') is 'disabled'

      hasWorkInProgress: ->
        @get('workInProgressState') is 'enabled-with-wip'

      hasRevertedWork: ->
        @get('workInProgressState') is 'enabled-with-reversion'

      code: {
        get: ->
          @findComponent('codePane').get('code')
        set: (code) ->
          @findComponent('codePane').set('code', code)
      }
    },

    getContextMenuOptions: (x, y) ->
      if @get('isEditing')
        widgetCreationOptions
      else
        []

    # (SetInspectAction) -> Unit
    setInspect: (action) ->
      @set('showInspectionPane', true)
      @findComponent('inspection').setInspect(action)

    # (Unit) -> Unit
    recalculateWidgetVarNames: ->
      @set('widgetVarNames', convertWidgetsToVarNames(@get('widgetObj')))

    on: {
      'world-might-change': (context) ->
        @findAllComponents().forEach((component) -> component.fire(context.name, context))
      'compiler-error': (_, source, errors) ->
        switch source
          when 'recompile', 'compile-recoverable'
            @findComponent('codePane').set('compilerErrors', errors)
          when 'console', 'inspection-pane'
            ; # do nothing
          else
            console.error("received compiler error from unknown source: %s", source)
        false
      'runtime-error': (_, source, exception, code) ->
        message = exception.stackTraceMessage
        codePaneErrors = for stackTraceItem in exception.stackTrace
          switch stackTraceItem.type
            when 'command', 'reporter'
              {
                message
                start: stackTraceItem.location.start,
                end: stackTraceItem.location.end
              }
            else
              continue # don't display
        if source isnt 'console'
          @findComponent('codePane').set('runtimeErrors', codePaneErrors)
        false
      render: ->
        @recalculateWidgetVarNames()
    }

    observe: {
      'showInspectionPane': {
        handler: (newValue) ->
          @fire('inspection-pane-toggled', {}, newValue)
        init: false
      },
      'viewQuality': {
        handler: (newQuality) ->
          @get('viewController').setQuality(newQuality)
        init: false
      }
    }

    data: -> model
  })

# coffeelint: disable=max_line_length
template =
  """
  <statusPopup
    hasWorkInProgress={{hasWorkInProgress}}
    isSessionLoopRunning={{isSessionLoopRunning}}
    sourceType={{source.type}}
    />

  <div class="netlogo-model netlogo-display-{{# isVertical }}vertical{{ else }}horizontal{{/}}" style="min-width: {{width}}px;"
       tabindex="1" on-keydown="@this.fire('check-action-keys', @event)"
       on-focus="@this.fire('track-focus', @node)"
       on-blur="@this.fire('track-focus', @node)">
    <div id="modal-overlay" class="modal-overlay" style="{{# !isOverlayUp }}display: none;{{/}}" on-click="drop-overlay"></div>

    <div class="netlogo-display-vertical">

      <div class="netlogo-header">
        <div class="netlogo-subheader">
          <div class="netlogo-powered-by">
            <a href="http://ccl.northwestern.edu/netlogo/">
              <img style="vertical-align: middle;" alt="NetLogo" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAIGNIUk0AAHolAACAgwAA+f8AAIDpAAB1MAAA6mAAADqYAAAXb5JfxUYAAANcSURBVHjarJRdaFxFFMd/M/dj7252uxubKms+bGprVyIVbNMWWqkQqtLUSpQWfSiV+oVFTcE3DeiDgvoiUSiCYLH2oVoLtQ+iaaIWWtE2FKGkkSrkq5svN+sm7ma/7p3x4W42lEbjQw8MM8yc87/nzPnNFVprbqWJXyMyXuMqx1Ni6N3ny3cX8tOHNLoBUMvESoFI2Xbs4zeO1lzREpSrMSNS1zkBDv6uo1/noz1H7mpvS4SjprAl2AZYEqzKbEowBAgBAkjPKX2599JjT7R0bj412D0JYNplPSBD1G2SmR/e6u1ikEHG2vYiGxoJmxAyIGSCI8GpCItKimtvl2JtfGujDNkX6epuAhCjNeAZxM1ocPy2Qh4toGQ5DLU+ysiuA2S3P0KgJkjAgEAlQylAA64CG/jlUk6//ng4cNWmLK0yOPNMnG99Rs9LQINVKrD+wmke7upg55PrWP3eYcwrlykpKCkoelDy/HVegQhoABNAepbACwjOt72gZkJhypX70YDWEEklue+rbnYc2MiGp1upPfYReiJJUUG58gFXu4udch1wHcjFIgy0HyIjb2yvBpT2F6t+6+f+D15lW8c9JDo7iPSdgVIRLUqL2AyHDQAOf9hfbqxvMF98eT3RuTS1avHyl+Stcphe2chP9+4k/t3RbXVl3W+Ws17FY56/w3VcbO/koS/eZLoAqrQMxADZMTYOfwpwoWjL4+bCYcgssMqGOzPD6CIkZ/3SxTJ0ayFIN6/BnBrZb2XdE1JUgkJWkfrUNRJnPyc16zsbgPyXIUJBpvc+y89nk/S8/4nek3NPGeBWMwzGvhUPnP6RubRLwfODlqqx3LSCyee2MnlwMwA2RwgO5qouVcHmksUdJweYyi8hZkrUjgT5t/ejNq0jBsSqNWsKyT9uFtxw7Bs585d3g46KOeT2bWHmtd14KyP+5mzqpsYU3OyioACMhGiqPTMocsrHId9cy9BLDzKxq8X3ctMwlV6yKSHL4fr4dd0DeQBTBUgUkvpE1kVPbqkX117ZzuSaFf4zyfz5n9A4lk0yNU7vyb7jTy1kmFGipejKvh6h9n0W995ZPTu227hqmCz33xXgFV1v9NzI96NfjndWt7XWCB/7BSICFWL+j3lAofpCtfYFb6X9MwCJZ07mUsXRGwAAAABJRU5ErkJggg=="/>
              <span style="font-size: 16px;">powered by NetLogo</span>
            </a>
          </div>
        </div>
        <editableTitle
          title="{{modelTitle}}"
          isEditing="{{isEditing}}"
          hasWorkInProgress="{{hasWorkInProgress}}"
          />
        {{# !isReadOnly }}
          <div class="flex-column" style="align-items: flex-end; user-select: none;">
            <div class="netlogo-export-wrapper">
              <span style="margin-right: 4px;">File:</span>
              <button class="netlogo-ugly-button" on-click="open-new-file"{{#isEditing}} disabled{{/}}>New</button>
              {{#!disableWorkInProgress}}
                {{#!hasRevertedWork}}
                  <button class="netlogo-ugly-button" on-click="revert-wip"{{#!isRevertable}} disabled{{/}}>Revert to Original</button>
                {{else}}
                  <button class="netlogo-ugly-button" on-click="undo-revert"{{#isEditing}} disabled{{/}}>Undo Revert</button>
                {{/}}
              {{/}}
            </div>
            <div class="netlogo-export-wrapper">
              <span style="margin-right: 4px;">Export:</span>
              <button class="netlogo-ugly-button" on-click="export-nlogo"{{#isEditing}} disabled{{/}}>NetLogo</button>
              <button class="netlogo-ugly-button" on-click="export-html"{{#isEditing}} disabled{{/}}>HTML</button>
            </div>
          </div>
        {{/}}
      </div>

      <div class="netlogo-display-horizontal">

        <div id="authoring-lock" class="netlogo-toggle-container{{#!someDialogIsOpen}} enabled{{/}}" on-click="toggle-interface-lock">
          <div class="netlogo-interface-unlocker {{#isEditing}}interface-unlocked{{/}}"></div>
          <spacer width="5px" />
          <span class="netlogo-toggle-text">Mode: {{#isEditing}}Authoring{{else}}Interactive{{/}}</span>
        </div>

        <div id="tabs-position" class="netlogo-toggle-container{{#!someDialogIsOpen}} enabled{{/}}" on-click="toggle-orientation">
          <div class="netlogo-model-orientation {{#isVertical}}vertical-display{{/}}"></div>
          <spacer width="5px" />
          <span class="netlogo-toggle-text">Commands and Code: {{#isVertical}}Bottom{{else}}Right Side{{/}}</span>
        </div>

      </div>

      <asyncDialog wareaHeight="{{height}}" wareaWidth="{{width}}"></asyncDialog>
      <helpDialog isOverlayUp="{{isOverlayUp}}" isVisible="{{isHelpVisible}}" stateName="{{stateName}}" wareaHeight="{{height}}" wareaWidth="{{width}}"></helpDialog>
      <contextMenu></contextMenu>
      <dragSelectionBox/>

      <label class="netlogo-speed-slider{{#isEditing}} interface-unlocked{{/}}">
        <span class="netlogo-label">model speed</span>
        <input type="range" min=-1 max=1 step=0.01 value="{{speed}}"{{#isEditing}} disabled{{/}} on-change="['speed-slider-changed', speed]" />
        <tickCounter isVisible="{{primaryView.showTickCounter}}"
                     label="{{primaryView.tickCounterLabel}}" value="{{ticks}}" />
      </label>

      <div style="position: relative; width: {{width}}px; height: {{height}}px"
           class="netlogo-widget-container{{#isEditing}} interface-unlocked{{/}}"
           on-contextmenu="show-context-menu"
           on-click="@this.fire('deselect-widgets', @event)" on-dragover="mosaic-killer-killer">
        <resizer isEnabled="{{isEditing}}" isVisible="{{isResizerVisible}}" />
        {{#widgetObj:key}}
          {{# type === 'view'     }} <viewWidget    id="{{>widgetID}}" isEditing="{{isEditing}}" left="{{left}}" right="{{right}}" top="{{top}}" bottom="{{bottom}}" widget={{this}} ticks="{{ticks}}" viewController="{{viewController}}" setInspect="{{@this.setInspect.bind(@this)}}" /> {{/}}
          {{# type === 'textBox'  }} <labelWidget   id="{{>widgetID}}" isEditing="{{isEditing}}" left="{{left}}" right="{{right}}" top="{{top}}" bottom="{{bottom}}" widget={{this}} /> {{/}}
          {{# type === 'switch'   }} <switchWidget  id="{{>widgetID}}" isEditing="{{isEditing}}" left="{{left}}" right="{{right}}" top="{{top}}" bottom="{{bottom}}" widget={{this}} /> {{/}}
          {{# type === 'button'   }} <buttonWidget  id="{{>widgetID}}" isEditing="{{isEditing}}" left="{{left}}" right="{{right}}" top="{{top}}" bottom="{{bottom}}" widget={{this}} parentEditor={{parentEditor}} errorClass="{{>errorClass}}" ticksStarted="{{ticksStarted}}"/> {{/}}
          {{# type === 'slider'   }} <sliderWidget  id="{{>widgetID}}" isEditing="{{isEditing}}" left="{{left}}" right="{{right}}" top="{{top}}" bottom="{{bottom}}" widget={{this}} parentEditor={{parentEditor}} errorClass="{{>errorClass}}" /> {{/}}
          {{# type === 'chooser'  }} <chooserWidget id="{{>widgetID}}" isEditing="{{isEditing}}" left="{{left}}" right="{{right}}" top="{{top}}" bottom="{{bottom}}" widget={{this}} parentEditor={{parentEditor}}/> {{/}}
          {{# type === 'monitor'  }} <monitorWidget id="{{>widgetID}}" isEditing="{{isEditing}}" left="{{left}}" right="{{right}}" top="{{top}}" bottom="{{bottom}}" widget={{this}} parentEditor={{parentEditor}} errorClass="{{>errorClass}}" /> {{/}}
          {{# type === 'inputBox' }} <inputWidget   id="{{>widgetID}}" isEditing="{{isEditing}}" left="{{left}}" right="{{right}}" top="{{top}}" bottom="{{bottom}}" widget={{this}} parentEditor={{parentEditor}}/> {{/}}
          {{# type === 'plot'     }} <plotWidget    id="{{>widgetID}}" isEditing="{{isEditing}}" left="{{left}}" right="{{right}}" top="{{top}}" bottom="{{bottom}}" widget={{this}} parentEditor={{parentEditor}}/> {{/}}
          {{# type === 'output'   }} <outputWidget  id="{{>widgetID}}" isEditing="{{isEditing}}" left="{{left}}" right="{{right}}" top="{{top}}" bottom="{{bottom}}" widget={{this}} text="{{outputWidgetOutput}}" /> {{/}}
        {{/}}
      </div>

    </div>

    <div class="netlogo-tab-area" style="min-width: {{Math.min(width, 500)}}px; max-width: {{Math.max(width, 500)}}px">
      <label class="netlogo-tab{{#showInspectionPane}} netlogo-active{{/}}">
        <input id="inspection-pane-toggle" type="checkbox" checked="{{ showInspectionPane }}"/>
        <span class="netlogo-tab-text">Agent Inspection</span>
      </label>
      <div style="{{#!showInspectionPane}}display: none;{{/}}">
        <inspection
          isEditing={{isEditing}}
          viewController={{viewController}}
          checkIsReporter={{checkIsReporter}}
          parentEditor={{parentEditor}}
        />
      </div>
      {{# !isReadOnly }}
      <label class="netlogo-tab{{#showConsole}} netlogo-active{{/}}">
        <input id="console-toggle" type="checkbox" checked="{{ showConsole }}" on-change="['command-center-toggled', showConsole]"/>
        <span class="netlogo-tab-text">Command Center</span>
      </label>
      {{#showConsole}}
        <console output="{{consoleOutput}}" isEditing="{{isEditing}}" checkIsReporter="{{checkIsReporter}}" parentEditor={{parentEditor}}/>
      {{/}}
      {{/}}
      <label class="netlogo-tab{{#showCode}} netlogo-active{{/}}">
        <input id="code-tab-toggle" type="checkbox" checked="{{ showCode }}" on-change="['model-code-toggled', showCode]" />
        <span class="netlogo-tab-text{{#lastCompileFailed}} netlogo-widget-error{{/}}">NetLogo Code</span>
      </label>
      <div style="{{#!showCode}}display: none;{{/}}">
        <codePane
          initialCode={{initialCode}}
          lastCompiledCode={{lastCompiledCode}}
          lastCompileFailed={{lastCompileFailed}}
          isReadOnly={{isReadOnly}}
          setAsParent={{receiveParentEditor}}
          widgetVarNames={{widgetVarNames}}
        />
      </div>
      <label class="netlogo-tab{{#showInfo}} netlogo-active{{/}}">
        <input id="info-toggle" type="checkbox" checked="{{ showInfo }}" on-change="['model-info-toggled', showInfo]" />
        <span class="netlogo-tab-text">Model Info</span>
      </label>
      {{#showInfo}}
        <infotab rawText='{{info}}' isEditing='{{isEditing}}' />
      {{/}}
    </div>

    <input id="general-file-input" type="file" name="general-file" style="display: none;" />

  </div>
  """

partials = {

  errorClass:
    """
    {{# !compilation.success}}netlogo-widget-error{{/}}
    """

  widgetID:
    """
    netlogo-{{type}}-{{key}}
    """

}
# coffeelint: enable=max_line_length

genWidgetCreator = (name, widgetType, isEnabled = true, enabler = (-> false)) ->
  { text: "Create #{name}", enabler, isEnabled
  , action: (context, mouseX, mouseY) -> context.fire('create-widget', widgetType, mouseX, mouseY)
  }

alreadyHasA = (componentName) -> (ractive) ->
  if ractive.parent?
    alreadyHasA(componentName)(ractive.parent)
  else
    not ractive.findComponent(componentName)?

widgetCreationOptions = [
  ["Button",  "button"],
  ["Chooser", "chooser"],
  ["Input",   "inputBox"],
  ["Note",    "textBox"],
  ["Monitor", "monitor"],
  ["Output",  "output", false, alreadyHasA('outputWidget')],
  ["Plot",    "plot"],
  ["Slider",  "slider"],
  ["Switch",  "switch"],
].map((args) -> genWidgetCreator(args...))

# `widgetObj` is just the type of the skeleton's 'widgetObj' data.
convertWidgetsToVarNames = (widgetObj) ->
  Object.values(widgetObj).map((widget) -> widget.variable).filter((x) -> x?)

export default generateRactiveSkeleton
