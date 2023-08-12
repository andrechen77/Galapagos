import RactiveMiniAgentCard from "./mini-agent-card.js"
import RactiveInspectionWindow from "./inspection-window.js"

{ arrayEquals } = tortoise_require('brazier/equals')
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

RactiveBreadcrumbs = Ractive.extend({
  data: -> {
    # Props
    path: undefined, # CategoryPath
    goToPath: undefined, # (CategoryPath) -> Unit
    optionalLeaf: null # string | null

    # Consts

    calcPartialPaths,
    calcCategoryPathDetails
  }

  template: """
    <div>
      {{#each calcPartialPaths(path) as partialPath}}
        <span on-click="goToPath(partialPath)">
          {{calcCategoryPathDetails(partialPath).display}}
        </span>
        {{#unless @index == path.length}}{{>separator}}{{/unless}}
      {{/each}}
      {{#if optionalLeaf}}
        {{>separator}}
        {{optionalLeaf}}
      {{/if}}
    </div>
  """

  partials: {
    'separator': """
      <span>&nbsp/&nbsp</span>
    """
  }
})

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

# Given an agent, returns the keypath with respect to the skeleton ractive to the array where that agent would go if it
# were inspected.
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

    viewController: undefined # ViewController; from which this inspection window is taking its ViewWindow
    checkIsReporter: undefined # (string) -> boolean

    # State

    # type InspectedAgents = {
    #   turtles: Object<string, Array[Turtle]>,
    #   patches: Array[Patch],
    #   links: Object<string, Array[Link]>,
    # }
    # The `turtles` and `links` properties map breed names to lists of agents.
    inspectedAgents: { 'turtles': {}, 'patches': [], 'links': {} } # InspectedAgents

    ###
    The `selection` describes the layout of the inspection pane.
    Possible values of the `currentScreen` property:
     * 'categories': the inspection pane shows a navigation screen to select agents by their type/breed.
     * 'agents': the inspection pane shows a specific set of agents (selected from the categories screen)
     * 'details': the inspection pane shows a full window with details about a specific agent.
    type = {
      currentScreen: 'categories',
      selectedPaths: Array[CategoryPath]
    } | {
      currentScreen: 'agents',
      currentPath: CategoryPath,
      selectedAgents: Array[Agent]
    } | {
      currentScreen: 'details',
      currentPath: CategoryPath,
      currentAgent: Agent
    }
    where CategoryPath: Array[string] e.g. ["turtles"], ["turtles", "TURTLEBREEDNAME"], ["patches"]
    ###
    selection: { currentScreen: 'categories', selectedPaths: [[]] }

    # Consts

    # Returns whether, in its current state, the inspection pane should show a command input.
    # (Unit) -> Unit
    hasCommandInput: ->
      switch @get('selection.currentScreen')
        when 'agents', 'details' then true
        when 'categories' then false

    # Returns whether to display a category as being "selected" based on its selection state.
    # ('exact' | 'partial' | 'inherit' | 'none') -> boolean
    getDisplayAsSelected: (categoryPath) ->
      switch calcPathMatchMultiple(@get('selection.selectedPaths'), categoryPath)
        when 'exact', 'partial' then true
        else false

    # Only makes sense if 'selection.currentScreen' is 'agents'.
    # (Agent) -> boolean
    getAgentSelectionState: (agent) -> @get('selection.selectedAgents').includes(agent)

    # (Array[string]) -> Array[Agent]
    getAgentsInPath: (path) ->
      flattenObject(@get(['inspectedAgents'].concat(path).join('.')), Array.isArray)

    # (CategoryPath) -> Unit
    goToPath: (categoryPath) ->
      @selectCategory({ mode: 'replace', categoryPath })

    # Only makes sense of 'selection.currentScreen' is 'categories'.
    # Returns a 2D array where each row represents the children of the (most-recently) selected
    # category of the previous row; if nothing is selected then the major categories ('turtles',
    # 'patches', 'links') are shown. Doesn't show leaves (i.e. `Agent`s) in the 'inspectedAgents' tree.
    # (Unit) -> Array[Array[CategoryPath]]
    getCategoryRows: ->
      # First get the paths that will make up the backbone of the grid.
      paths = calcPartialPaths(@get('selection.selectedPaths').at(-1) ? [])

      # Each category path will correspond to a row
      for path in paths
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

    calcCategoryPathDetails
  }

  computed: {
    targetedAgents: ->
      selection = @get('selection')
      switch selection.currentScreen
        when 'categories'
          selection.selectedPaths.flatMap(@get('getAgentsInPath'))
        when 'agents'
          inspected = @get('getAgentsInPath')(selection.currentPath)
          selected = selection.selectedAgents
          # For the second branch, we use `inspected` with `selected` as a filter instead of just `selected` directly
          # because agents that stopped being inspected can still show up as selected if the user doesn't
          # deselect them before `stop-inspecting` them. If/when this is no longer the case, we can iterate over
          # `selected` directly.
          if selected.length is 0 then inspected else inspected.filter((agent) -> selected.includes(agent))
        when 'details'
          [selection.currentAgent]
  }

  observe: {
    targetedAgents: (newValue) ->
      @get('viewController').setHighlightedAgents(newValue)
  }

  components: {
    breadcrumbs: RactiveBreadcrumbs,
    miniAgentCard: RactiveMiniAgentCard,
    inspectionWindow: RactiveInspectionWindow
  }

  onrender: ->
    # This function should only be run when 'selection.currentScreen' is either 'agents' or 'details'.
    run = (input) =>
      if input.trim().length > 0
        if @get('checkIsReporter')(input)
          input = "show #{input}"
        agentSetReporter = @getTargetedAgentsReporter()
        input = "ask #{agentSetReporter} [ #{input} ]"

        @fire('run', {}, 'console', input)
        @fire('command-center-run', input)


    editor = new GalapagosEditor(@find('.netlogo-command-center-editor'), {
      Wrapping: true,
      OneLine: true,
      OnKeyUp: (event, editor) ->
        switch event.key
          when "Enter"
            run(editor.GetCode())
            editor.SetCode("")
    })

  on: {
    'clicked-category-card': (context, categoryPath) ->
      ctrl = context.event.ctrlKey
      @selectCategory({ mode: (if ctrl then 'toggle' else 'replace'), categoryPath })
    'dblclicked-category-card': (context, categoryPath) ->
      # The conditional is so that when the user clicks and then ctrl-clicks the category card, it does not open.
      if not context.event.ctrlKey
        @openCategory(categoryPath)
    'miniAgentCard.clicked-agent-card': (context, agent) ->
      ctrl = context.event.ctrlKey
      @selectAgent({ mode: (if ctrl then 'toggle' else 'replace'), agent })
    'miniAgentCard.dblclicked-agent-card': (context, agent) ->
      # The conditional is so that when the user clicks and then ctrl-clicks the category card, it does not open.
      if not context.event.ctrlKey
        @openAgent(agent)
    'world-might-change': (context) ->
        @findAllComponents().forEach((component) -> component.fire(context.name, context))
  }

  ### type SetInspectAction =
    { action: 'add-focus', agent: Agent }
    | { action: 'add' | 'remove', agents: Array[Agent] }
    | { action: 'clear-dead' }
  ###
  # (SetInspectAction) -> Unit
  setInspect: (action) ->
    switch action.type
      when 'add-focus'
        { agent } = action
        keypath = getKeypathFor(agent)
        @push("inspectedAgents.#{keypath.join('.')}", agent)
        @openCategory(keypath)
        @openAgent(agent)
      when 'add'
        inspectedAgents = @get('inspectedAgents')
        for agent in action.agents
          traverseKeypath(inspectedAgents, getKeypathFor(agent), []).push(agent)
        @update('inspectedAgents')
      when 'remove'
        inspectedAgents = @get('inspectedAgents')
        for agent in action.agents
          keypath = getKeypathFor(agent)
          arr = traverseKeypath(inspectedAgents, keypath, [])
          index = arr.indexOf(agent) ? -1
          if index isnt -1
            arr.splice(index, 1)
        @update('inspectedAgents')
      when 'clear-dead'
        pruneTree(
          @get('inspectedAgents'),
          (obj) -> if isAgent(obj) then not obj.isDead() else null
        )
        @update('inspectedAgents')

  # Selects the specified category, entering the 'categories' screen if not already in it.
  # 'replace' mode removes all other selected categories (single-clicking an item), while 'toggle' mode toggles whether
  # the item is selected (ctrl-clicking an item). 'toggle' mode requires that the we already be in the 'categories'
  # screen.
  # ({ mode: 'replace' | 'toggle', categoryPath: CategoryPath }) -> Unit
  selectCategory: ({ mode, categoryPath }) ->
    selectedPaths = switch mode
      when 'replace'
        [categoryPath]
      when 'toggle'
        paths = togglePresence(@get('selection.selectedPaths'), categoryPath, arrayEquals)[0]
        if paths.length is 0 then paths.push([])
        paths
    @set('selection', {
      currentScreen: 'categories',
      selectedPaths
    })

  # Enters 'agents' screen mode, displaying the set of agents in the specified category.
  # (CategoryPath) -> Unit
  openCategory: (categoryPath) ->
    @set('selection', { currentScreen: 'agents', currentPath: categoryPath, selectedAgents: [] })

  # Only makes sense if 'selection.currentScreen' is 'agents'.
  # Selects the specified agent.
  # 'replace' mode removes all other selected agents (single-clicking an item), while 'toggle' mode toggles whether
  # the item is selected (ctrl-clicking an item).
  # ({ mode: 'replace' | 'toggle', agent: Agent }) -> Unit
  selectAgent: ({ mode, agent }) ->
    selectedAgents = switch mode
      when 'replace'
        [agent]
      when 'toggle'
        togglePresence(@get('selection.selectedAgents'), agent, (a) -> (b) -> a is b)[0]
    @set('selection.selectedAgents', selectedAgents)

  # Precondition: 'selection.currentScreen' is 'agents' and `selection.currentPath` is contains the specified agent.
  # Enters 'details' screen mode, displaying detailed information and a mini view of the specified agent.
  # (Agent) -> Unit
  openAgent: (agent) ->
    @set('selection', { currentScreen: 'details', currentAgent: agent }, { deep: true })

  # This method should only be run when 'selection.currentScreen' is either 'agents' or 'details'.
  # Returns a string of interpretable NetLogo code with all the agents for which a command should be run.
  # If on the 'agents' screen, this is all inspected and selected agents, or if there are none, all inspected agents.
  # If on the 'details' screen, this is simply the inspected agent.
  # (Unit) -> string
  getTargetedAgentsReporter: ->
    currentPath = @get('selection.currentPath')

    # (Array[Agent]) -> string
    getAgentSetReporter = switch currentPath[0]
      when 'turtles' then getTurtleSetReporter
      when 'patches' then getPatchSetReporter
      when 'links' then getLinkSetReporter
      else throw new Error("Couldn't turn the current path into a valid agent set reporter.") # should never happen

    getAgentSetReporter(@get('targetedAgents'))


  template: """
    <div class='netlogo-tab-content'>
      {{#with selection}}
        {{#if currentScreen == 'categories'}}
          {{>categoriesScreen}}
        {{elseif currentScreen == 'agents'}}
          {{>agentsScreen}}
        {{elseif currentScreen == 'details'}}
          {{>detailsScreen}}
        {{/if}}
        <div
          class="netlogo-command-center-editor"
          style="{{#if !hasCommandInput()}}display: none; {{/if}}width: 400px; height: 25px;"
        ></div>
      {{/with}}
    </div>
  """

  partials: {
    'categoriesScreen': """
      categories screen<br/>
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
          style="min-width: 150px; {{#if getDisplayAsSelected(path)}}background-color: lightblue;{{/if}}"
          on-click="['clicked-category-card', path]"
          on-dblclick="['dblclicked-category-card', path]"
        >
            {{display}} ({{getAgentsInPath(path).length}})
        </div>
      {{/with}}
    """

    'agentsScreen': """
      agents screen<br/>
      <breadcrumbs path="{{currentPath}}" goToPath="{{goToPath.bind(@this)}}"/>
      <div style="display: flex; flex-wrap: wrap; width: 100%;">
        {{#each getAgentsInPath(currentPath) as agent}}
          <miniAgentCard agent={{agent}} selected={{getAgentSelectionState(agent)}}/>
        {{/each}}
      </div>
    """

    'detailsScreen': """
      details screen<br/>
      <breadcrumbs
        path="{{currentPath}}"
        goToPath="{{goToPath.bind(@this)}}"
        optionalLeaf="{{currentAgent.getName()}}"
      />
      <inspectionWindow
        viewController={{viewController}}
        agent={{currentAgent}}
        setInspect="{{@this.setInspect.bind(@this)}}"
      />
    """
  }
})

export default RactiveInspectionPane
