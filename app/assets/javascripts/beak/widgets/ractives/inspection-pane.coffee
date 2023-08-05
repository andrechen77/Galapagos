import RactiveInspectionWindow from "./inspection-window.js"

{ arrayEquals } = tortoise_require('brazier/equals')

# CategoryPath: Array[string] e.g. ["turtles"], ["turtles", "TURTLEBREEDNAME"], ["patches"]

# Returns all the "partial paths" leading up to the given path. For example, `['foo', 'bar', 'baz']` will return
# `[[], ['foo'], ['foo', 'bar'], ['foo', 'bar', 'baz']]`.
# (CategoryPath) -> Array[CategoryPath]
calcPartialPaths = (categoryPath) ->
  for i in [0..categoryPath.length]
    categoryPath[0...i]

RactiveBreadcrumbs = Ractive.extend({
  data: -> {
    # Props
    path: undefined, # CategoryPath
    goToPath: undefined, # (CategoryPath) -> Unit

    # Consts

    calcPartialPaths
  }

  template: """
    <div>
      {{#each calcPartialPaths(path).slice(1) as partialPath}}
        <span on-click="goToPath(partialPath)">
          {{partialPath.at(-1)}}
        </span>
        {{#unless @index == path.length - 1}}/{{/unless}}
      {{/each}}
    </div>
  """
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

RactiveInspectionPane = Ractive.extend({
  data: -> {
    # Props

    inspectedAgents: undefined # InspectedAgents; (see "../skeleton.coffee")
    addToInspect: undefined # (Agent) -> Unit
    viewController: undefined # ViewController; from which this inspection window is taking its ViewWindow

    # State

    ###
    The `selection` describes the layout of the inspection pane.
    Possible values of the `currentScreen` property:
     * 'blank': the inspection pane shows nothing but the drag-to-select tool.
     * 'categories': the inspection pane shows a navigation screen to select agents by their type/breed.
     * 'agents': the inspection pane shows a specific set of agents (selected from the categories screen)
     * 'details': the inspection pane shows a full window with details about a specific agent.
    type = {
      currentScreen: 'blank'
    } | {
      currentScreen: 'categories',
      selectedPaths: Array[CategoryPath]
    } | {
      currentScreen: 'agents',
      selectedPath: CategoryPath,
      selectedAgents: Array[Agent]
    } | {
      currentScreen: 'details',
      selectedPath: CategoryPath,
      selectedAgent: Agent
    }
    where CategoryPath: Array[string] e.g. ["turtles"], ["turtles", "TURTLEBREEDNAME"], ["patches"]
    ###
    selection: { currentScreen: 'blank' }

    # Consts

    # (Turtle|Patch|Link|Observer) -> String
    printProperties: (agent) ->
      pairList = for varName in agent.varNames()
        "#{varName}: #{agent.getVariable(varName)}"
      pairList.join("<br/>")

    # (Turtle|Patch|Link|Observer) -> String
    getAgentName: (agent) -> agent.getName()

    # Only makes sense if 'selection.currentScreen' is 'categories'.
    # Returns "how selected" a specified category path is; see `calcPathMatchMultiple` for details.
    # (CategoryPath) -> 'exact' | 'partial' | 'inherit' | 'none'
    getSelectionState: (categoryPath) ->
      calcPathMatchMultiple(@get('selection.selectedPaths'), categoryPath)

    # Returns whether to display a category as being "selected" based on its selection state.
    # ('exact' | 'partial' | 'inherit' | 'none') -> boolean
    getDisplayAsSelected: (selectionState) ->
      switch selectionState
        when 'exact', 'partial' then true
        else false

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

    # (CategoryPath) -> { path: CategoryPath, display: string }
    calcCategoryPathDetails: (categoryPath) -> {
      path: categoryPath,
      display: switch categoryPath.length
        when 0 # We're at the root category. This theoretically should never happen.
          'Agent'
        when 1 # We're at one of the major agent types.
          switch categoryPath[0]
            when 'turtles' then 'Turtles'
            when 'patches' then 'Patches'
            when 'links' then 'Links'
            else categoryPath[0] # This theoretically should never happen.
        when 2 # We're at some agent breed.
          world.breedManager.get(categoryPath[1]).singular
        else # 3-deep category paths should theoretically never happen; there is no classification deeper than breed.
          categoryPath.at(-1)
    }
  }

  components: {
    breadcrumbs: RactiveBreadcrumbs,
    inspectionWindow: RactiveInspectionWindow
  }

  onrender: ->
    run = (input) =>
      if input.trim().length > 0
        agentSetReporter = 'turtle-set' # TODO: make it reflect the actual type of agents
        # TODO only send to the selected agents
        # for turtle in @get('inspectedAgents')
        #   agentSetReporter = agentSetReporter.concat(" turtle #{turtle.id}")
        input = "ask (#{agentSetReporter}) [ #{input} ]"
        # TODO consider using `show` if the command is a reporter
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
  }

  # Precondition: 'selection.currentScreen' is 'categories'.
  # Enters 'agent' screen mode, displaying the set of agents in the specified category.
  # (CategoryPath) -> Unit
  openCategory: (categoryPath) ->
    @set('selection', { currentScreen: 'agents', selectedPath: categoryPath })

  # Selects the specified category, entering the 'categories' screen if not already in it. If
  # 'replace' mode removes all other selected categories (single-clicking an item), while 'toggle' mode toggles whether
  # the item is selected (ctrl-clicking an item). 'toggle' mode requires that the we already be in the 'categories'
  # screen. 'blank' mode deselects every category.
  # ({ mode: 'replace' | 'toggle', categoryPath: CategoryPath } | { mode: 'blank' }) -> Unit
  selectCategory: ({ mode, categoryPath }) ->
    selectedPaths = switch mode
      when 'blank'
        []
      when 'replace'
        [categoryPath]
      when 'toggle'
        matchFound = false
        filtered = @get('selection.selectedPaths').filter((path) ->
          isEqual = arrayEquals(categoryPath)(path)
          if isEqual then matchFound = true
          not isEqual
        )
        if not matchFound
          # Since we're toggling and `categoryPath` wasn't already selected, select it.
          filtered.push(categoryPath)
        filtered
    @set('selection', {
      currentScreen: 'categories',
      selectedPaths
    })

  template: """
    <div class='netlogo-tab-content'>
      {{#with selection}}
        {{#if currentScreen == 'blank' }}
          {{>blankScreen}}
        {{elseif currentScreen == 'categories'}}
          {{>categoriesScreen}}
        {{elseif currentScreen == 'agents'}}
          {{>agentsScreen}}
        {{elseif currentScreen == 'details'}}
          {{>detailsScreen}}
        {{/if}}
      {{/with}}
      <br/>

      <div class="netlogo-command-center-editor" style="width: 400px; height: 25px"></div>
    </div>
  """

  partials: {
    'blankScreen': """
      blank screen<br/>
      <div on-click="@this.selectCategory({ mode: 'blank' })">click here to go to categories</div>
    """

    'categoriesScreen': """
      categories screen<br/>
      {{#each getCategoryRows() as categoryRow}}
        {{#each categoryRow as categoryPath}}
          {{>categoryCard}}<br/>
        {{/each}}
      {{/each}}
    """

    'categoryCard': """
      {{#with calcCategoryPathDetails(this) }}
        <div on-click="['clicked-category-card', path]" on-dblclick="['dblclicked-category-card', path]">
          {{#if getDisplayAsSelected(getSelectionState(path))}}
            [{{display}} ({{getAgentsInPath(path).length}})]
          {{else}}
            {{display}} ({{getAgentsInPath(path).length}})
          {{/if}}
        </div>
      {{/with}}
    """

    'agentsScreen': """
      agents screen<br/>
      <breadcrumbs path="{{selectedPath}}" goToPath="{{goToPath.bind(@this)}}"/>
      {{#each getAgentsInPath(selectedPath) as agent}}
        -----<br/>
        {{getAgentName(agent)}} <br/>
        {{{printProperties(agent)}}}
        -----<br/>
      {{/each}}
    """

    'detailsScreen': """
      details screen<br/>
      <breadcrumbs path="{{selectedPath}}" goToPath="{{goToPath.bind(@this)}}"/>
      <inspectionWindow
        viewController={{viewController}}
        agent={{inspectedAgents.at(-1)}}
        addToInspect="{{addToInspect}}"
      />
    """
  }
})

export default RactiveInspectionPane
