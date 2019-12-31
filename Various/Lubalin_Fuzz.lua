--[[
@description Fuzz - A fuzzy search command palette for Reaper
@author Lubalin
@version 0.1.0
@provides
  [main] Lubalin_Fuzz/Fuzz.lua
  [main] Lubalin_Fuzz/Fuzz - tracks.lua
  [main] Lubalin_Fuzz/Fuzz - plugins.lua
  [main] Lubalin_Fuzz/Fuzz - markers.lua
  [main] Lubalin_Fuzz/Fuzz - settings.lua
  [nomain] Lubalin_Fuzz/fuzzysort.lua
  [nomain] Lubalin_Fuzz/benchmark.lua
@metapackage true
@about
  # Fuzz

  _A fuzzy search command palette for Reaper (inspired by the VS Code command palette)_

  Still in Beta!

  Lets you quickly search through:

  - Actions (currently only actions in the Main section)
  - FX chains
  - Markers
  - Tracks

  ### How It Works

  By default, Fuzz searches Reaper actions. Pressing enter will run the currently selected action.

  By using special characters (which you can change using the "Fuzz - settings" script), you can search different things. For example, by default, typing "\$" as the first character will allow you to search your FX chains. Pressing enter will load that chain into the first selected track.

  In marker mode, pressing enter will jump to the selected marker. In track mode, pressing enter will select the track and put it into view in the MCP and the TCP.

  In order to save time, there are also scripts which will run Fuzz with those special characters pre-typed for you.

  ### Default Charaters

  - "" --> Actions (main)
  - "\$" --> FX chains
  - "@" --> Markers
  - ">" --> Tracks

  ### Suggested Shortcuts

  I personally have Fuzz mapped to a single key (F). Then I have the different modes mapped to F + _some modifier_. So Shift + F opens Fuzz with "\$" pre-typed.

  Another idea would be to map each mode to the actual character you have set for it. Like having the markers script mapped to "@" (Shift + 2).

  ### How Results Are Sorted

  The search algorithm is pretty much a stripped down re-write of https://github.com/farzher/fuzzysort/ in lua.

  In order for a result to appear in the list, it must have the same characters as the search query, in the same _order_ that they appear in the query.

  Results are sorted by a score. Adjecent letters and the first letters of words score higher. After that, score is based on proximity of the letters, and length of the query vs the target.

  ### Contributing

  I'm open to contributions, but I may be a bit particular about the what and how of it. Please create an issue or check in with me before doing any work. Thanks!
]]