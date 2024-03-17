import RactiveMiniAgentCard from "./mini-agent-card.js"
import RactiveInspectionWindow from "./inspection-window.js"
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

# Given an agent, returns the keypath with respect to the 'inspectedAgents' data to the array where that agent would go
# if it were inspected.
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
    viewController: undefined # ViewController; from which this inspection window is taking its ViewWindow
    checkIsReporter: undefined # (string) -> boolean
    parentEditor: null # GalapagosEditor | null

    # State

    dragToSelectEnabled: false # boolean
    unsubscribeDragSelector: -> # (Unit) -> Unit

    updateTargetedAgentsInHistory: true # boolean; whether scrolling through history will also change what
    # agents are selected

    # type InspectedAgents = {
    #   turtles: Object<string, Array[Turtle]>,
    #   patches: Array[Patch],
    #   links: Object<string, Array[Link]>,
    # }
    # The `turtles` and `links` properties map breed names to lists of agents.
    inspectedAgents: { 'turtles': {}, 'patches': [], 'links': {} } # InspectedAgents

    ###
    type Selections = {
      selectedPaths: Array[CategoryPath] # should at least have the root path (`[]`) if none other is selected
      selectedAgents: Array[Agent] | null # null means to consider the categories as the main selections, not the agents
    }
    ###
    selections: { selectedPaths: [[]], selectedAgents: null }

    commandPlaceholderText: "" # string

    detailedAgents: [] # Array[Agent]; agents for which there is an opened detail window
    # can be shared with inspection windows

    # Consts

    # Returns whether to display a category as being "selected" based on its selection state.
    # ('exact' | 'partial' | 'inherit' | 'none') -> boolean
    getDisplayAsSelected: (categoryPath) ->
      switch calcPathMatchMultiple(@get('selections.selectedPaths'), categoryPath)
        when 'exact', 'partial' then true
        else false

    # (Agent) -> boolean
    getAgentSelectionState: (agent) ->
      selectedAgents = @get('selections.selectedAgents')
      selectedAgents? and selectedAgents.includes(agent)

    # (Array[string]) -> Array[Agent]
    getAgentsInPath: (path) ->
      flattenObject(@get(['inspectedAgents'].concat(path).join('.')), Array.isArray)

    # (Unit) -> Array[Agent]
    getAgentsInSelectedPaths: ->
      @get("selections.selectedPaths")?.flatMap(@get('getAgentsInPath')) ? []

    # Returns a 2D array where each row represents the children of the
    # (most-recently) selected category of the previous row; if nothing is
    # selected then the major categories ('turtles', 'patches', 'links') are
    # shown. Doesn't show leaves (i.e. `Agent`s) in the 'inspectedAgents' tree.
    # (Unit) -> Array[Array[CategoryPath]]
    getCategoryRows: ->
      # First get the paths that will make up the backbone of the grid.
      paths = calcPartialPaths(@get('selections.selectedPaths').at(-1) ? [])

      # Each category path will correspond to a row
      rootLevel = [[]] # a list of just one path, the root path
      nonRootLevels = for path in paths
        # Get this category's contents.
        contents = @get(['inspectedAgents'].concat(path).join('.'))
        # Don't display leaves or deeper
        if Array.isArray(contents)
          # This is the penultimate layer; `contents` must only have leaves.
          break
        # Get this category's direct children's keys.
        childrenKeys = Object.keys(contents)
        # Return the path to these children.
        childrenKeys.map((key) -> path.concat([key]))
      [rootLevel, nonRootLevels...]

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
          ((isShiftOrCtrlDrag) => if not isShiftOrCtrlDrag then @setInspect({ type: 'clear-all' })),
          (agents) =>
            @setInspect({ type: 'add', agents })
            return
        ))
      else
        @get('unsubscribeDragSelector')()
  }

  components: {
    miniAgentCard: RactiveMiniAgentCard,
    inspectionWindow: RactiveInspectionWindow,
    commandInput: RactiveCommandInput
  }

  on: {
    'clicked-category-card': (context, categoryPath) ->
      ctrl = context.event.ctrlKey
      @selectCategory({ mode: (if ctrl then 'toggle' else 'replace'), categoryPath })
    'miniAgentCard.clicked-agent-card': (context, agent) ->
      ctrl = context.event.ctrlKey
      @selectAgents(if ctrl then { mode: 'toggle', agent } else { mode: 'replace', agents: [agent] })
    'miniAgentCard.dblclicked-agent-card': (context, agent) ->
      # The conditional is so that when the user clicks and then ctrl-clicks the category card, it does not open.
      if not context.event.ctrlKey
        @toggleAgentDetails(agent)
    'miniAgentCard.closed-agent-card': (_, agent) ->
      @setInspect({ type: 'remove', agents: [agent] })
      false
    'inspectionWindow.closed-inspection-window': (_, agent) ->
      @set(
        'detailedAgents',
        @get('detailedAgents').filter((a) -> a != agent),
        { shuffle: true }
      )
    'commandInput.command-input-tabbed': -> false # ignore and block event
    unrender: ->
      @get('viewController').setHighlightedAgents([])
  }

  ### type SetInspectAction =
    { type: 'add-focus', agent: Agent }
    | { type: 'add' | 'remove' | 'replace', agents: Array[Agent] }
    | { type: 'clear-all', 'clear-dead' }
  ###
  # (SetInspectAction) -> Unit
  setInspect: (action) ->
    switch action.type
      when 'add-focus'
        { agent } = action
        keypath = getKeypathFor(agent)
        keypathStr = "inspectedAgents.#{keypath.join('.')}"
        array = @get(keypathStr)
        if not array? or not array.includes(agent)
          @push(keypathStr, agent)
        @toggleAgentDetails(agent)
      when 'add'
        inspectedAgents = @get('inspectedAgents')
        for agent in action.agents
          array = traverseKeypath(inspectedAgents, getKeypathFor(agent), [])
          if not array.includes(agent)
            array.push(agent)
        @update('inspectedAgents')
      when 'remove'
        inspectedAgents = @get('inspectedAgents')
        for agent in action.agents
          keypath = getKeypathFor(agent)
          arr = traverseKeypath(inspectedAgents, keypath, [])
          index = arr.indexOf(agent) ? -1
          if index isnt -1
            arr.splice(index, 1)
        @unselectAgents(action.agents)
        @update('inspectedAgents')
      when 'clear-all'
        pruneTree(
          @get('inspectedAgents'),
          (obj) -> if isAgent(obj) then false else null
        )
        @set('selections.selectedAgents', null)
        @update('inspectedAgents')
      when 'clear-dead'
        pruneTree(
          @get('inspectedAgents'),
          (obj) -> if isAgent(obj) then not obj.isDead() else null
        )
        @set('selections.selectedAgents', null)
        @update('inspectedAgents')

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

  # Opens or closes a details pane showing detailed information and a mini view of the specified agent.
  # (Agent) -> Unit
  toggleAgentDetails: (agent) ->
    # use `ractive.unshift` and `ractive.splice` methods instead of the existing
    # `togglePresence` and `ractive.update` because the former two are smarter
    # about recognizing when elements have shifted rather than simply changed
    index = @get('detailedAgents').indexOf(agent)
    if index == -1
      @unshift('detailedAgents', agent)
    else
      @splice('detailedAgents', index, 1)

  # (Array[Agent]) -> Unit
  unselectAgents: (agentsToUnselect) ->
    filtered = @get('selections.selectedAgents')?.filter((selected) -> not agentsToUnselect.includes(selected))
    @set('selections.selectedAgents', filtered)

  template: """
    <div class='netlogo-tab-content netlogo-inspection-pane'>
      <button class="netlogo-ugly-button" on-click="@.toggle('dragToSelectEnabled')">
        DRAG SELECT ({{#if dragToSelectEnabled}}on{{else}}off{{/if}})
      </button>
      <br/>
      {{#with selections}}
        {{#if dragToSelectEnabled}}
          Click or drag in the view to select agents.
        {{else}}
          To monitor change, inspect properties, and execute commands to one or multiple agents during simulation,
          turn on drag select to activate inspection mode.
        {{/if}}
        <h3>inspected agents</h3>
        {{>categoriesScreen}}
        <br/>
        {{>agentsScreen}}
        <div>
          <button class="netlogo-ugly-button" on-click="@.toggle('updateTargetedAgentsInHistory')">
            Update targeted agents in history: ({{#if updateTargetedAgentsInHistory}}on{{else}}off{{/if}})
          </button>
          <br/>
          <commandInput
            isReadOnly={{isEditing}}
            source="inspection-pane"
            checkIsReporter={{checkIsReporter}}
            targetedAgentObj={{targetedAgentObj}}
            placeholderText={{commandPlaceholderText}}
            parentEditor={{parentEditor}}
          />
        </div>
        <h3>inspection windows</h3>
        {{>detailsScreen}}
      {{/with}}
    </div>
  """

  partials: {
    'categoriesScreen': """
      {{#each getCategoryRows() as categoryRow}}
        <div style="display: flex;">
          {{#each categoryRow as categoryPath}}
            {{>categoryCard}}<br/>
          {{/each}}
        </div>
      {{/each}}
    """

    'categoryCard': """
      {{#with calcCategoryPathDetails(this) }}
        <div
          style="width: 150px; height: 15px; overflow: clip; {{#if getDisplayAsSelected(path)}}background-color: lightblue;{{/if}}"
          on-click="['clicked-category-card', path]"
          title="{{display}} ({{getAgentsInPath(path).length}})"
        >
            {{display}} ({{getAgentsInPath(path).length}})
        </div>
      {{/with}}
    """

    'agentsScreen': """
      <div style="display: flex; flex-wrap: wrap; width: 90%; min-height: 50px; border: 1px solid black;">
        {{#each getAgentsInSelectedPaths() as agent}}
          <miniAgentCard agent={{agent}} selected={{getAgentSelectionState(agent)}}/>
        {{/each}}
      </div>
    """

    'detailsScreen': """
      {{#each detailedAgents as agent}}
        <inspectionWindow
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
