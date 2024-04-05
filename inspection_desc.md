(written in the style of the [NetLogo User Manual](https://ccl.northwestern.edu/netlogo/docs/codetab.html))

An experimental branch with this feature is live at https://experiments.netlogoweb.org/inspection-improvements/. Please provide feedback on any bugs or opportunities for improvement that you encounter!

# Inspection Tab Guide

The Inspection tab allows you to monitor specific agents, get/modify their variables, and run commands on their behalf.

## Inspecting Agents

There are three primary ways to inspect an agent:

- **inspect command:** Running the `inspect` command with the agent as an argument (e.g. `inspect patch 0 0`) will open an agent monitor (as well as add the agent to the staging area).

  ![inspect command](https://github.com/andrechen77/Galapagos/assets/101299705/6c067a9a-77f5-4549-9e78-4c7c15bc546e)

- **right-click:** Right-clicking the agent in a view (when outside model editing mode) will show a context menu including items to inspect the agents near[^1] or under the cursor. Selecting one of those items will open an agent monitor (as well as add the agent to the staging area).

  ![right-click inspection](https://github.com/andrechen77/Galapagos/assets/101299705/c9a12475-9815-488b-b962-603dbd080a5c)

- **drag-to-inspect:** The button labeled "DRAG SELECT" will toggle drag-to-inspect mode. When in drag-to-inspect mode, dragging over a view will cause all agents in the selection box in the staging area, from which agent monitors can be opened.
  - The default behavior is for drag-selections to *replace* the agents in the staging area. Holding Ctrl or Shift while dragging will instead *add* the selected agents to the staging area.
  - Drag-to-inspect mode blocks all mouse interaction with the views, e.g. mouse reporters such as `mouse-xcor` will act as if the mouse is not in the view.
  ![drag-to-select](https://github.com/andrechen77/Galapagos/assets/101299705/99896dab-2c94-4869-9e6b-1be8413dbb41)

### Staging Area

Agents can be added to the staging area for the purpose of in-view highlighting, sending commands as a group, or opening detailed agent monitors.

![staging area](https://github.com/andrechen77/Galapagos/assets/101299705/16943216-3354-4b8e-a863-8c6dda233e3b)

At the top is displayed the categories of staged agents. The selected category(s) determine the visibility of agents in the staging area. By default, the root category "Agents" is selected, meaning that all agents are visible. Selecting "Turtles" will show only turtles, and selecting a specific breed will only show agents of that breed. You can also select individual agents in the staging area by clicking on their corresponding card. Holding Ctrl or Shift while clicking categories/agents allows you to select multiple at once or unselect only certain items.

The staging area has a concept of a "targeted agent." If some agents are selected[^2], then those selected agents are simply the targeted agents, otherwise all agents in selected categories are considered targeted.

- Targeted agents are highlighted in the main view: turtles and links with a glow, and patches with an outline.

  ![targeted agemts are highlighted](https://github.com/andrechen77/Galapagos/assets/101299705/d18d49c5-e1f2-4da5-b4f7-93345b02d0da)

- Targeted agents are the recipient of commands sent to the staging area's command center, as if they were `ask`ed.

  - However, if it is impossible to send a command at once to all the agents, which happens when agents of different types (e.g. both patches and turtles) are selected, then the command will be sent to the observer instead. The placeholder text of the command input will indicate the recipient of the command.

  ![targeted agents are the recipient of commands](https://github.com/andrechen77/Galapagos/assets/101299705/401ef94d-f8da-4671-b52a-75737937aa7a)

To open an agent monitor for an agent in the staging area, double-click the agent's card. Double-clicking an agent that already has an open agent monitor will close that monitor. Whether an agent is staged is independent from whether it has an agent monitor.

An agent can be unstaged by clicking the X in the agent's card.

# Agent Monitors

Agent monitors are small windows that contain more details about a specific agent. They appear below the staging area of the inspection pane.

![agent monitor](https://github.com/andrechen77/Galapagos/assets/101299705/b6270402-d48b-441e-b6f1-a3a4af59c580)

An agent monitor contains a mini-view that is always centered on the agent. The slider beneath the mini-view can be used to zoom in or out[^3].

![agent monitor](https://github.com/andrechen77/Galapagos/assets/101299705/4d88d20c-6c5a-4a0a-a7de-98f57849ec4b)

The watch button watch the agent in the main view, as by `watch-me`. It acts as a toggle, so an already-watched agent will be unwatched.

An agent monitor lists all the variables that belong to the agent, as well as their values. These can be directly changed, as if by `set <variable> <newvalue>`, by editing the contents of the variable's field.

![agent monitor lists variables](https://github.com/andrechen77/Galapagos/assets/101299705/ffd1659d-2ab0-4970-b50b-be9181328826)

However, editing intrinsic identifying variables (i.e. a turtle's `who`, a patch's `pxcor` and `pycor`, and a link's `end1` and `end2`) triggers special behavior that makes the agent monitor switch focus to the agent with the specified identity, if it exists. Note that because of implementation-specific restrictions, although a link's `end1` and `end2` variables display as `(turtle <whonumber>)`, they must be edited to just `<whonumber>` to properly switch.

An agent monitor has a command center whose commands are sent only to that specific agent.

![image](https://github.com/andrechen77/Galapagos/assets/101299705/44b70897-b831-42f2-bebb-f1ede9764665)

An agent monitor can be closed by clicking the X in its top-right corner.

[^1]: For turtles/links, this roughly depends on agent size/thickness with a minimum for zero-sized agents, but is not yet parallel with desktop for square agents.

[^2]: This means whether the most recent selection was of an agent, as opposed to of a category. It is possible to create some selection of agents with exactly zero agents by selecting an agent and then unselecting it using Ctrl-/Shift-click; in this case all selected agents (i.e. nobody) will be targeted. If the intention is to target the whole category, simply select the desired category rather than unselecting all agents.

[^3]: The numeric zoom level represents how much of the mini-view is taken up by that agent. At the most zoomed-in level (1.0), the agent fills the entire screen. However, zoom-out is capped to display at most the entire world.
