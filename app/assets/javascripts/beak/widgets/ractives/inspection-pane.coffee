import RactiveMiniAgentCard from "./mini-agent-card.js"
import RactiveAgentMonitor from "./agent-monitor.js"
import RactiveCommandInput from "./command-input.js"
import { attachDragSelector } from "../drag-selector.js"

{ arrayEquals } = tortoise_require('brazier/equals')
{ unique } = tortoise_require('brazier/array')
Turtle = tortoise_require('engine/core/turtle')
Patch = tortoise_require('engine/core/patch')
Link = tortoise_require('engine/core/link')

# CategoryPath: Array[string] e.g. ["turtles"], ["turtles", "TURTLEBREEDNAME"], ["patches"]

# Returns all the "partial paths" leading up to the given path. For example, `['foo', 'bar', 'baz']` will return
# `[[], ['foo'], ['foo', 'bar'], ['foo', 'bar', 'baz']]`.
# (CategoryPath) -> Array[CategoryPath]
calcPartialPaths = (categoryPath) ->
  for i in [0..categoryPath.length]
    categoryPath[0...i]

# (CategoryPath) -> { path: CategoryPath, display: string }
calcCategoryPathDetails = (categoryPath) -> {
  path: categoryPath,
  display: switch categoryPath.length
    when 0 # We're at the root category.
      'Agents'
    when 1 # We're at one of the major agent types.
      switch categoryPath[0]
        when 'turtles' then 'Turtles'
        when 'patches' then 'Patches'
        when 'links' then 'Links'
        else categoryPath[0] # This theoretically should never happen.
    when 2 # We're at some agent breed.
      world.breedManager.get(categoryPath[1]).name
    else # 3-deep category paths should theoretically never happen; there is no classification deeper than breed.
      categoryPath.at(-1)
}

# Given an object, returns an array of all the leaves in the object (viewing the object as a rooted tree). A value is
# considered a leaf it is the direct child of an object for which `isPenultimateLayer` returns true.
# (any, (any) -> boolean) -> Array
flattenObject = (obj, isPenultimateLayer) ->
  if isPenultimateLayer(obj)
    obj
  else
    Object.values(obj).flatMap((obj) -> flattenObject(obj, isPenultimateLayer))

# Returns "how selected" a specified test category path with respect to an exactly-selected path.
# The given test path can have one of the following states:
# * is 'exact'-ly selected (if the path matches exactly)
# * is 'partial'-ly selected (if one of is descendents is exactly selected)
# * 'inherit's selection from one of its ancestors
# * 'none' of the above
# (CategoryPath, CategoryPath) -> 'exact' | 'partial' | 'inherit' | 'none'
calcPathMatch = (selectedPath, testPath) ->
  for i in [0...selectedPath.length]
    if i is testPath.length
      # The test path matched perfectly so far but didn't go deep enough.
      return 'partial'
    if selectedPath[i] isnt testPath[i]
      return 'none'
  if selectedPath.length < testPath.length
    # The test path matched perfectly to the whole selected path and went even deeper.
    return 'inherit'
  else
    # The test path matched perfectly and went the same depth as the selected path.
    return 'exact'

# Returns "how selected" a specified test category path given an array of exactly-selected paths.
# Return values are explained in `calcPathMatch`.
# If multiple apply, the first applicable state in this order ('exact', 'partial', 'inherit', 'none') is returned.
# (CategoryPath) -> 'exact' | 'partial' | 'inherit' | 'none'
calcPathMatchMultiple = (selectedPaths, testPath) ->
  highestState = 'none' # the highest priority state encountered so far
  for selectedPath in selectedPaths
    switch calcPathMatch(selectedPath, testPath)
      when 'exact'
        return 'exact'
      when 'partial'
        highestState = 'partial'
      when 'inherit'
        if highestState isnt 'partial' then highestState = 'inherit'
      # when 'none', do nothing
  highestState

# Toggles whether a test item is present in an array. If it is, returns an array with all instances of the item removed;
# otherwise returns an array with the test item appended. Also returns whether a match was found.
# (Array[T], T, (T) -> (T) -> boolean) -> [Array[T], boolean]
togglePresence = (array, testItem, comparator) ->
  checkEqualToTest = comparator(testItem)
  matchFound = false
  filtered = array.filter((item) ->
    isEqual = checkEqualToTest(item)
    if isEqual then matchFound = true
    not isEqual
  )
  if not matchFound
    # Since we're toggling and `testItem` wasn't already present, add it.
    filtered.push(testItem)
  [filtered, matchFound]

# Given an agent, returns the keypath with respect to the 'stagedAgents' data to
# the array where that agent would go if it were staged.
# (Agent) -> string
getKeypathFor = (agent) ->
  switch
    when agent instanceof Turtle then ['turtles', agent.getBreedName()]
    when agent instanceof Patch then ['patches']
    when agent instanceof Link then ['links', agent.getBreedName()]

# Given an object and a array of keys, recursively accesses the object using those keys and returns the result.
# Consumes the array of keys up until continuing traversal is impossible. If a value along the path is undefined, and
# the default value is set, the value there will be set to the default value and then immediately returned.
# (any) -> any
traverseKeypath = (obj, keypath, defaultValue = undefined) ->
  x = obj
  while key = keypath.shift()
    if not x[key]? and defaultValue?
      x[key] = defaultValue
      return x[key]
    x = x[key]
  x

# (any) -> boolean
isAgent = (obj) -> obj instanceof Turtle or obj instanceof Patch or obj instanceof Link

# Treating an object as the root of a tree, prunes certain nodes of the tree (deleting an element of an
# array shifts the indices of the following elements, while deleting an element of an object simply removes the
# key-value pair). The provided tester function should return true if the node should be kept as-is (stopping deeper
# recursion), false if the node should be deleted, and null if the node should be recursively pruned. Returning null on
# a non-traversable value (i.e. a primitive) causes it to be deleted.
# (any, (any) -> boolean | null) -> Unit
pruneTree = (obj, tester) ->
  for key, value of obj
    switch tester(value)
      when false then delete obj[key]
      when null
        if not value? or typeof value isnt 'object'
          delete obj[key]
        else # we know it must be a traversible object at this point
          pruneTree(value, tester)
  if Array.isArray(obj)
    i = 0
    while i < obj.length
      if Object.hasOwn(obj, i)
        ++i
      else
        obj.splice(i, 1)
  return

RactiveInspectionPane = Ractive.extend({
  data: -> {
    # Props

    isEditing: undefined # boolean
    viewController: undefined # ViewController; from which the agent monitors take their ViewWindows
    checkIsReporter: undefined # (string) -> boolean
    parentEditor: null # GalapagosEditor | null

    # State

    dragToSelectEnabled: false # boolean
    unsubscribeDragSelector: -> # (Unit) -> Unit

    updateTargetedAgentsInHistory: true # boolean; whether scrolling through history will also change what
    # agents are selected

    # type StagedAgents = {
    #   turtles: Object<string, Array[Turtle]>,
    #   patches: Array[Patch],
    #   links: Object<string, Array[Link]>,
    # }
    # The `turtles` and `links` properties map breed names to lists of agents.
    stagedAgents: { 'turtles': {}, 'patches': [], 'links': {} } # StagedAgents

    ###
    type Selections = {
      selectedPaths: Array[CategoryPath] # should at least have the root path (`[]`) if none other is selected
      selectedAgents: Array[Agent] | null # null means to consider the categories as the main selections, not the agents
    }
    ###
    # represent everything in the staging area that are selected
    selections: { selectedPaths: [[]], selectedAgents: null }

    commandPlaceholderText: "" # string

    inspectedAgents: [] # Array[Agent]; agents for which there is an opened agent monitor
    # can be shared with agent monitor components

    # Consts

    # (Agent) -> boolean
    getAgentSelectionState: (agent) ->
      selectedAgents = @get('selections.selectedAgents')
      selectedAgents? and selectedAgents.includes(agent)

    # (Array[string]) -> Array[Agent]
    getAgentsInPath: (path) ->
      flattenObject(@get(['stagedAgents'].concat(path).join('.')), Array.isArray)

    # (Unit) -> Array[Agent]
    getAgentsInSelectedPaths: ->
      unique(@get("selections.selectedPaths")?.flatMap(@get('getAgentsInPath')) ? [])

    # Returns a 2D array where each row represents the children of the
    # (most-recently) selected category of the previous row; if nothing is
    # selected then the major categories ('turtles', 'patches', 'links') are
    # shown. Doesn't show leaves (i.e. `Agent`s) in the 'stagedAgents' tree.
    # `combineTopLevels` describes whether to put the root category at the
    # same level as the level-1 categories.
    # (boolean) -> Array[Array[CategoryPath]]
    getCategoryRows: (combineTopLevels) ->
      # First get the paths that will make up the backbone of the grid.
      paths = calcPartialPaths(@get('selections.selectedPaths').at(-1) ? [])

      # Each category path will correspond to a row
      rootPath = [] # the root path
      nonRootLevels = for path in paths
        # Get this category's contents.
        contents = @get(['stagedAgents'].concat(path).join('.'))
        # Don't display leaves or deeper
        if Array.isArray(contents)
          # This is the penultimate layer; `contents` must only have leaves.
          break
        # Get this category's direct children's keys.
        childrenKeys = Object.keys(contents)
        # Return the path to these children.
        childrenKeys.map((key) -> path.concat([key]))
      if combineTopLevels
        [
          [rootPath, nonRootLevels[0]...],
          nonRootLevels[1..]...
        ]
      else
        [
          [rootPath],
          nonRootLevels...
        ]

    calcPathMatchType: calcPathMatchMultiple

    calcCategoryPathDetails
  }

  computed: {
    # computing this value also the command placeholder text
    targetedAgentObj: {
      get: ->
        { selectedPaths, selectedAgents } = @get('selections')
        console.assert(selectedPaths.length > 0)

        [targetedAgents, quantifierText] = if selectedAgents?
          [selectedAgents, "selected"]
        else
          [@get('getAgentsInSelectedPaths')(), "all"]

        # check whether the selected paths are all of the same agent type
        # (i.e. turtles, patches, or links).
        selectedAgentTypes = unique(selectedPaths.map((path) -> path[0] ? 'root'))
        if selectedAgentTypes.length == 1 and selectedAgentTypes[0] != 'root'
          categoriesText = selectedPaths.map((path) -> calcCategoryPathDetails(path).display).join(", ")
          @set('commandPlaceholderText', "Input command for #{quantifierText} #{categoriesText}")
          { agentType: selectedAgentTypes[0], agents: targetedAgents }
        else
          # the agents are not of the same type (mix of turtles, patches, links)
          # so just send the commands to the observer
          @set('commandPlaceholderText', "Input command for OBSERVER")
          { agentType: 'observer', agents: targetedAgents }
      set: (targetedAgentObj) ->
        if not @get('updateTargetedAgentsInHistory')
          # ignore the set operation and force the targeted agent obj to remain the same
          return

        # While we can't set the targetedAgentObj directly, we can attempt to put the inspection pane into a state such
        # that the getter would return something equivalent to the value passed to this setter.

        { agentType, agents } = targetedAgentObj

        @selectAgents({ mode: 'replace', agents })
    }
  }

  observe: {
    'targetedAgentObj.agents': (newValue) ->
      @get('viewController').setHighlightedAgents(newValue)
    dragToSelectEnabled: (enabled) ->
      if enabled
        @set('unsubscribeDragSelector', attachDragSelector(
          @get('viewController'),
          @root.findComponent('dragSelectionBox'),
          ((isShiftOrCtrlDrag) => if not isShiftOrCtrlDrag then @setInspect({ type: 'unstage-all' })),
          (agents) =>
            @setInspect({ type: 'add', agents, monitor: false })
            return
        ))
      else
        @get('unsubscribeDragSelector')()
  }

  components: {
    miniAgentCard: RactiveMiniAgentCard,
    agentMonitor: RactiveAgentMonitor,
    commandInput: RactiveCommandInput
  }

  on: {
    'clicked-category-tab': (context, categoryPath) ->
      ctrl = context.event.ctrlKey
      @selectCategory({ mode: (if ctrl then 'toggle' else 'replace'), categoryPath })
      false
    'clicked-staging-help': (_) ->
      alert("To monitor change, inspect properties, and execute commands to one or multiple agents during simulation, turn on drag select to activate inspection mode. Then, click or drag in the view to select agents.")
      false
    'miniAgentCard.clicked-agent-card': (context, agent) ->
      ctrl = context.event.ctrlKey
      @selectAgents(if ctrl then { mode: 'toggle', agent } else { mode: 'replace', agents: [agent] })
      false
    'miniAgentCard.dblclicked-agent-card': (context, agent) ->
      # The conditional is so that when the user clicks and then ctrl-clicks the category card, it does not open.
      if not context.event.ctrlKey
        @toggleAgentMonitor(agent)
      false
    'miniAgentCard.closed-agent-card': (_, agent) ->
      @setInspect({ type: 'remove', agents: [agent], monitor: false })
      false
    'agentMonitor.closed-agent-monitor': (_, agent) ->
      @set(
        'inspectedAgents',
        @get('inspectedAgents').filter((a) -> a != agent),
        { shuffle: true }
      )
      false
    'commandInput.command-input-tabbed': -> false # ignore and block event
    unrender: ->
      @get('viewController').setHighlightedAgents([])
  }

  ### type SetInspectAction =
    { type: 'add' | 'remove', agents: Array[Agent], monitor: boolean }
    | { type: 'unstage-all', 'clear-dead' }
  ###
  # (SetInspectAction) -> Unit
  setInspect: (action) ->
    switch action.type
      when 'add'
        stagedAgents = @get('stagedAgents')
        for agent in action.agents
          array = traverseKeypath(stagedAgents, getKeypathFor(agent), [])
          if not array.includes(agent)
            array.push(agent)
          if action.monitor and not @get('inspectedAgents').includes(agent)
            @toggleAgentMonitor(agent)
        @update('stagedAgents')
      when 'remove'
        stagedAgents = @get('stagedAgents')
        for agent in action.agents
          keypath = getKeypathFor(agent)
          arr = traverseKeypath(stagedAgents, keypath, [])
          index = arr.indexOf(agent) ? -1
          if index isnt -1
            arr.splice(index, 1)
          if action.monitor and @get('inspectedAgents').includes(agent)
            @toggleAgentMonitor(agent)
        @unselectAgents(action.agents)
        @update('stagedAgents')
      when 'unstage-all'
        pruneTree(
          @get('stagedAgents'),
          (obj) -> if isAgent(obj) then false else null
        )
        @set('selections.selectedAgents', null)
        @update('stagedAgents')
      when 'clear-dead'
        pruneTree(
          @get('stagedAgents'),
          (obj) -> if isAgent(obj) then not obj.isDead() else null
        )
        @set('selections.selectedAgents', null)
        @update('stagedAgents')
        for agent in [@get('inspectedAgents')...]
          if agent.isDead()
            @toggleAgentMonitor(agent)

  # Selects the specified category. 'replace' mode removes all other selected
  # categories (single-clicking an item), while 'toggle' mode toggles whether
  # the item is selected (ctrl-clicking an item).
  # ({ mode: 'replace' | 'toggle', categoryPath: CategoryPath }) -> Unit
  selectCategory: ({ mode, categoryPath }) ->
    selectedPaths = switch mode
      when 'replace'
        [categoryPath]
      when 'toggle'
        [paths, _] = togglePresence(@get('selections.selectedPaths'), categoryPath, arrayEquals)
        if paths.length is 0 then paths.push([])
        paths
    ### @set('selection', { currentScreen: 'categories', selectedPaths }) ###
    # Ideally we'd want to use the concise code above instead of the kludgy bandaid below, but Ractive can't figure out
    # how to update the dependents of 'selection' in the correct order. If the inspection window is open, it will
    # complain that 'selection.currentAgent' is gone before it notices that, because 'selection.currentScreen' is
    # 'categories', it shouldn't even be rendered in the first place. So much for "Ractive runs updates based on
    # priority" (see https://ractive.js.org/concepts/#dependents), bunch of lying bastards. This complaining doesn't
    # cause any material issues, but it clogs up the console output. Therefore, we do a deep merge of the data, leaving
    # the keypath 'selection.currentAgent' valid even while 'selection.currentScreen' is 'categories'. However, the
    # option `deep: true` doesn't even work correctly either :P so we just manually do the deep merge.
    # --Andre C. (2023-08-23)
    # begin kludgy bandaid
    selections = @get('selections')
    selections.selectedPaths = selectedPaths
    selections.selectedAgents = null
    @update('selections')
    # end kludgy bandaid

  # Selects the specified agents. 'replace' mode removes all other selected
  # agents (single-clicking an item), while 'toggle' mode toggles whether the
  # item is selected (ctrl-clicking an item).
  # ({ mode: 'replace', agents: Array[Agent] } | { mode: 'toggle', agent: Agent}) -> Unit
  selectAgents: (arg) ->
    { selectedAgents: oldSelectedAgents } = @get('selections')

    newSelectedAgents = switch arg.mode
      when 'replace'
        arg.agents
      when 'toggle'
        if oldSelectedAgents?
          togglePresence(oldSelectedAgents, arg.agent, (a) -> (b) -> a is b)[0]
        else
          [arg.agent]

    # keep the selected paths the same. if this method is called by the user
    # clicking a mini agent card, then that means that the currently selected
    # categories must have included the agents in this call

    @set('selections.selectedAgents', newSelectedAgents)

  # Opens or closes an agent monitor showing detailed information and a mini
  # view of the specified agent.
  # (Agent) -> Unit
  toggleAgentMonitor: (agent) ->
    # use `ractive.unshift` and `ractive.splice` methods instead of the existing
    # `togglePresence` and `ractive.update` because the former two are smarter
    # about recognizing when elements have shifted rather than simply changed
    index = @get('inspectedAgents').indexOf(agent)
    if index == -1
      @unshift('inspectedAgents', agent)
    else
      @splice('inspectedAgents', index, 1)

  # (Array[Agent]) -> Unit
  unselectAgents: (agentsToUnselect) ->
    filtered = @get('selections.selectedAgents')?.filter((selected) -> not agentsToUnselect.includes(selected))
    @set('selections.selectedAgents', filtered)

  template: """
    <div class='netlogo-tab-content inspection__pane'>
      {{>stagingArea}}
      {{>commandCenter}}

      <h3>agent monitors</h3>
      {{>agentMonitorsScreen}}
    </div>
  """

  partials: {
    'stagingArea': """
      {{#with getCategoryRows(true) as categoryRows}}
        <div class="inspection__header-row">
          <div class="inspection__tab-selector-group">
            {{#each categoryRows[0] as categoryPath}}
              {{>categoryTab}}
            {{/each}}
          </div>
          <div class="inspection__button-tray">
            <div
              class="inspection__button {{#if dragToSelectEnabled}}selected{{/if}}"
              title="Toggle drag-to-select"
              on-click="@.toggle('dragToSelectEnabled')"
            >
              <img
                width=25
                src="https://cdn0.iconfinder.com/data/icons/controls-and-navigation-arrows-1/24/27-512.png"
              />
            </div>
            <div class="inspection__button" title="Help" on-click="clicked-staging-help">
              <img
                width=25
                src="https://static.thenounproject.com/png/61692-200.png"
              />
            </div>
          </div>
        </div>
        <div class="inspection__tab-content">
          {{#each categoryRows.slice(1) as categoryRow}}
            <div class="inspection__card-selector-group">
              {{#each categoryRow as categoryPath}}
                {{>categoryTab}}
              {{/each}}
            </div>
          {{/each}}
          <div class="inspection__agents-area">
            {{#each getAgentsInSelectedPaths() as agent}}
              <miniAgentCard
                agent={{agent}}
                selected={{getAgentSelectionState(agent)}}
                opened={{inspectedAgents.includes(agent)}}
              />
            {{/each}}
          </div>
        </div>
      {{/with}}
    """

    'categoryTab': """
      {{#with calcCategoryPathDetails(this) }}
      <div
        class="inspection__option {{#with calcPathMatchType(selections.selectedPaths, path) as matchType}}
          {{#if matchType === 'exact'}}
            selected
          {{elseif matchType === 'partial' && path.length > 0}}
            selected-partial
          {{/if}}
        {{/with}}"
        on-click="['clicked-category-tab', path]"
        title="{{display}} ({{getAgentsInPath(path).length}})"
      >
        <span class="category">{{display}}</span>
        <span class="count">{{getAgentsInPath(path).length}}</span>
      </div>
      {{/with}}
    """

    'commandCenter': """
      <div class="inspection__cmd-container">
        <div
          class="inspection__button {{#if updateTargetedAgentsInHistory}}selected{{/if}}"
          on-click="@.toggle('updateTargetedAgentsInHistory')"
          title="Update targeted agents in history: ({{#if updateTargetedAgentsInHistory}}on{{else}}off{{/if}})"
        >
          <img
            width=25
            src="https://static.thenounproject.com/png/84467-200.png"
          />
        </div>
        <commandInput
          isReadOnly={{isEditing}}
          source="inspection-pane"
          checkIsReporter={{checkIsReporter}}
          targetedAgentObj={{targetedAgentObj}}
          placeholderText={{commandPlaceholderText}}
          parentEditor={{parentEditor}}
        />
      </div>
    """

    'agentMonitorsScreen': """
      {{#each inspectedAgents as agent}}
        <agentMonitor
          viewController={{viewController}}
          agent={{agent}}
          isEditing={{isEditing}}
          checkIsReporter={{checkIsReporter}}
          parentEditor={{parentEditor}}
          setInspect="{{@this.setInspect.bind(@this)}}"
        />
      {{/each}}
    """
  }
})

export default RactiveInspectionPane
