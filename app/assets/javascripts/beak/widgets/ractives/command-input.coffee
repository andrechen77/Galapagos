# The following "get agent set reporter" functions return a string of interpretable NetLogo code referring to each
# the agents passed in.

# (string, (Agent) -> string) -> (Array[Agent]) -> string
getAgentSetReporterCreator = (setName, getAgentReporter) -> (agents) ->
  "(#{setName} #{(for agent in agents then getAgentReporter(agent)).join(' ')})"
# (Array[Agent]) -> string
getTurtleSetReporter = getAgentSetReporterCreator(
  'turtle-set',
  (turtle) -> "turtle #{turtle.id}"
)
getPatchSetReporter = getAgentSetReporterCreator(
  'patch-set',
  (patch) -> "patch #{patch.pxcor} #{patch.pycor}"
)
getLinkSetReporter = getAgentSetReporterCreator(
  'link-set',
  (link) -> "#{link.getBreedNameSingular()} #{link.end1.id} #{link.end2.id}"
)

# (TargetedAgentObj, string) -> string
getCommand = (targetedAgentObj, input) ->
  { agentType, agents } = targetedAgentObj
  if agentType is 'observer'
    # Just send the command as-is.
    input
  else if agents?
    # Construct a specific agentset to send the command to.

    # (Array[Agent]) -> string
    getAgentSetReporter = switch agentType
      when 'turtles' then getTurtleSetReporter
      when 'patches' then getPatchSetReporter
      when 'links' then getLinkSetReporter
      else throw new Error("#{agentType} is not a valid agent type")

    agentSetReporter = getAgentSetReporter(agents)

    "ask #{agentSetReporter} [ #{input} ]"
  else
    # Send the command to all agents of the specified types
    "ask #{agentType} [ #{input} ]"

# type Entry = { targetedAgentObj: TargetedAgentObj, input: string }

# Returns whether the two entries have the same agent targeting and the same input
# (Entry, Entry) -> boolean
compareEntries = (a, b) ->
  { input: aInput, targetedAgentObj: { agentType: aAgentType, agents: aAgents } } = a
  { input: bInput, targetedAgentObj: { agentType: bAgentType, agents: bAgents } } = b
  if aInput isnt bInput then return false
  if aAgentType isnt bAgentType then return false
  if aAgents? isnt bAgents? then return false
  if not aAgents? then return true
  aAgents.every((el) -> bAgents.includes(el)) and bAgents.every((el) -> aAgents.includes(el))

RactiveCommandInput = Ractive.extend({
  # AgentType = 'observer' | 'turtles' | 'patches' | 'links'

  data: -> {
    # Props

    source: undefined # string; where the command came from, e.g. 'console'
    checkIsReporter: undefined # (string) -> boolean
    isReadOnly: undefined # boolean
    placeholderText: undefined # string

    # Shared State (both this component and the enclosing root component can read/write)

    # Modifications to this property should reassign it to a completely new object, instead
    # of mutating the existing object. This is because this object will be stored in the history.
    # The `agentType` property determines the type of agent that will be targeted by this
    # commands runs by this command input. If 'observer', then `agents` is ignored
    # and commands are sent to the observer. If either 'turtles', 'patches', or 'links',
    # then commands are sent to those agents in `agents` (which must be of the correct
    # type), unless `agents` is undefined in which case it is sent to all agents of
    # that type.
    # type TargetedAgentObj = { agentType: AgentType, agents?: Array[Agent] }
    targetedAgentObj: { agentType: 'observer' }

    history: [] # Array[Entry]; highest index is most recent
    historyIndex: 0 # keyof typeof @get('history') | @get('history').length
    workingEntry: {} # stores Entry when the user up-arrows

    # Private State
    editor: undefined # GalapagosEditor
    placeholderElement: document.createElement('span')
  }

  computed: {
    # Shareable State (downward only)

    # string
    input: {
      get: -> @get('editor').GetCode()
      set: (newValue) -> @get('editor').SetCode(newValue)
    }
  }

  observe: {
    isReadOnly: {
      handler: (isReadOnly) ->
        @get('editor').SetReadOnly(isReadOnly)
      init: false # automatically handled on render when the editor is constructed
    }

    placeholderText: (placeholderText) ->
      @get('placeholderElement').textContent = placeholderText
  }

  on: {
    render: ->
      run = =>
        input = @get('input')
        if input.trim().length > 0
          targetedAgentObj = @get('targetedAgentObj')
          if @get('checkIsReporter')(input)
            input = "show #{input}"

          history = @get('history')
          newEntry = { targetedAgentObj, input }
          if history.length is 0 or not compareEntries(history.at(-1), newEntry)
            history.push(newEntry)
          @set('historyIndex', history.length)

          cmd = getCommand(targetedAgentObj, input)
          @fire('run', {}, @get('source'), cmd, { targetedAgentObj, input })
          @fire('command-center-run', cmd)
        @set({ input: "", workingEntry: {} })

      moveInHistory = (delta) =>
        history = @get('history')
        currentIndex = @get('historyIndex')
        newIndex = Math.max(Math.min(currentIndex + delta, history.length), 0)
        if currentIndex is history.length
          # The current entry is not in history; save it before moving to history
          @set('workingEntry', { targetedAgentObj: @get('targetedAgentObj'), input: @get('input') })
        { targetedAgentObj, input } = if newIndex is history.length
          # Moving out of history to the working entry
          @get('workingEntry')
        else
          # Moving to some point in history
          history[newIndex]
        @set({ targetedAgentObj, input, historyIndex: newIndex })

      editor = new GalapagosEditor(@find('.netlogo-command-center-editor'), {
        ReadOnly: @get('isReadOnly')
        Language: 0, # TODO actually import the enum and use the constant EditorLanguage.NetLogo
        Placeholder: @get('placeholderElement'),
        ParseMode: 'Oneline' # TODO actually import the enum and use the constant ParseMode.Oneline
        OneLine: true,
        OnUpdate: (_documentChanged, _viewUpdate) =>
          @update('code')
          return
        OnKeyUp: (event) =>
          switch event.key
            when 'Enter' then run()
            when 'Tab'
              @set('input', @get('input').trim()) # kludge to get rid of tab character added (can be beginning or end)
              @fire('command-input-tabbed')
            when 'ArrowUp' then moveInHistory(-1)
            when 'ArrowDown' then moveInHistory(1)
      })
      @set('editor', editor)
  }

  # (Unit) -> Unit
  focus: ->
    @get('editor').Focus()
    return

  template: """
    <div class="netlogo-command-center-editor"></div>
  """
})

export default RactiveCommandInput
