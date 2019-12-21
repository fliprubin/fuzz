function msg(m)
  return reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

function get_script_path()
  local info = debug.getinfo(1, "S")
  local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
  return script_path
end

local script_path = get_script_path()
package.path = package.path .. ";" .. script_path .. "?.lua"

require "fuzzysort"
require "benchmark"
benchmark.bypass = true

-- Script generated by Lokasenna's GUI Builder

local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
  reaper.MB(
    "Couldn't load the Lokasenna_GUI library. Please install 'Lokasenna's GUI library v2 for Lua', available on ReaPack, then run the 'Set Lokasenna_GUI v2 library path.lua' script in your Action List.",
    "Whoops!",
    0
  )
  return
end
loadfile(lib_path .. "Core.lua")()

GUI.req("Classes/Class - Listbox.lua")()
GUI.req("Classes/Class - Textbox.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then
  return 0
end

-- HiDPI Scaling
local retval, layoutValue = reaper.ThemeLayout_GetLayout("mcp", -3)
local guiScale = layoutValue / 256
local elementWidth = math.floor(1133 * guiScale)
local textHeight = math.floor(23 * guiScale)
local listboxHeight = math.floor(550 * guiScale)
local padding = math.floor(33 * guiScale)

GUI.name = "Fuzz"
GUI.x, GUI.y = 0, 0
GUI.w = padding + elementWidth + padding
GUI.h = math.floor(padding + textHeight + (padding / 2) + listboxHeight + padding)
GUI.anchor, GUI.corner = "screen", "C"

local monoFont
local osName = reaper.GetOS()
if osName:match("Win") then
  monoFont = "Consolas"
elseif osName:match("OSX") then
  monoFont = "Andale Mono"
else
  monoFont = "DejaVuSansMono"
end

GUI.fonts[3] = {monoFont, textHeight}

GUI.New(
  "results",
  "Listbox",
  {
    z = 11,
    x = padding,
    y = math.floor(padding + textHeight + (padding / 2)),
    w = elementWidth,
    h = listboxHeight,
    list = {},
    multi = false,
    caption = "",
    font_a = 3,
    font_b = 3,
    color = "txt",
    col_fill = "elm_fill",
    bg = "elm_bg",
    cap_bg = "wnd_bg",
    shadow = false,
    pad = 4
  }
)

GUI.New(
  "input",
  "Textbox",
  {
    z = 11,
    x = padding,
    y = padding,
    w = elementWidth,
    h = textHeight,
    caption = "",
    cap_pos = "left",
    color = "txt",
    bg = "wnd_bg",
    shadow = false,
    font_a = 3,
    font_b = 3,
    pad = 4,
    undo_limit = 20
  }
)
-- pre-set focus on textbox
GUI.elms.input.focus = true

-- patch this Textbox's draw function to fix drawing bug when it is focused
function GUI.elms.input:draw()
  -- Some values can't be set in :init() because the window isn't
  -- open yet - measurements won't work.
  if not self.wnd_w then
    self:wnd_recalc()
  end

  if self.caption and self.caption ~= "" then
    self:drawcaption()
  end

  -- Blit the textbox frame, and make it brighter if focused.
  gfx.blit(
    self.buff,
    1,
    0,
    -- (self.focus and self.w or 0),
    (self.focus and 0 or 0), -- here's the bugfix
    0,
    self.w,
    self.h,
    self.x,
    self.y
  )

  if self.retval ~= "" then
    self:drawtext()
  end

  if self.focus then
    if self.sel_s then
      self:drawselection()
    end
    if self.show_caret then
      self:drawcaret()
    end
  end

  self:drawgradient()
end

-- Modify this instance of Textbox to ignore Up and Down arrow keys:
GUI.elms.input.keys[GUI.chars.UP] = function()
end
GUI.elms.input.keys[GUI.chars.DOWN] = function()
end

-- This function iterates over a fuzzysort results table, sorted by score
function sortedResults(t)
  local clonedTable = {}
  for n in pairs(t) do
    table.insert(clonedTable, n)
  end

  function sortFunction(a, b)
    return t[a].score > t[b].score
  end

  table.sort(clonedTable, sortFunction)
  local i = 0
  local iter = function()
    i = i + 1
    if clonedTable[i] == nil then
      return nil
    else
      return clonedTable[i], t[clonedTable[i]]
    end
  end
  return iter
end

function resultsForListbox(results)
  local retval = {}
  for i, result in ipairs(results) do
    table.insert(retval, result.target)
  end
  return retval
end

-- key is the key for the target strings
function preCacheTargets(table, key)
  local startTime = os.clock()
  local elapsedTime = 0
  local slow = true

  for i, target in ipairs(table) do
    fuzzysort.getPrepared(target[key], slow)

    -- yield every 50 ms
    elapsedTime = os.clock() - startTime
    if elapsedTime > 0.05 then
      startTime = os.clock()
      coroutine.yield()
    end
  end
end

-- Enumerate actions to search through
function buildActionsTable()
  local ret = 1
  local actionIndex = 0
  local actionsTable = {}
  local theOtherString = ""

  while ret > 0 do
    local string = ""
    ret, string = reaper.CF_EnumerateActions(0, actionIndex, theOtherString)
    table.insert(actionsTable, {code = ret, name = string})
    actionIndex = actionIndex + 1
  end

  return actionsTable
end
benchmark.start("build actions table")
local actionsTable = buildActionsTable()
benchmark.stop("build actions table")

-- Make list of plugin chain files
function buildPluginsTable()
  local pluginsPath = reaper.GetResourcePath() .. "/FXChains/"
  local pluginsTable = {}

  function scanDirectory(path)
    local directoryIndex = 0
    while true do
      local subPath = reaper.EnumerateSubdirectories(path, directoryIndex)
      directoryIndex = directoryIndex + 1
      if subPath == nil then
        break
      end
      scanDirectory(path .. subPath)
    end

    local fileIndex = 0
    while true do
      local file = reaper.EnumerateFiles(path, fileIndex)
      fileIndex = fileIndex + 1
      if file == nil then
        break
      end
      local subDirectories = string.sub(path, #pluginsPath + 1, #path) .. "/"
      local filePlusSub = subDirectories .. string.sub(file, 1, #file - 9)
      pluginsTable[#pluginsTable + 1] = {name = filePlusSub}
    end
  end

  scanDirectory(pluginsPath)

  return pluginsTable
end
benchmark.start("build plugin table")
local pluginsTable = buildPluginsTable()
benchmark.stop("build plugin table")

function buildMarkersTable()
  local markersTable = {}
  local i = 0

  while true do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    if retval == 0 then
      break
    end

    markersTable[#markersTable + 1] = {
      index = markrgnindexnumber,
      name = name
    }

    i = i + 1
  end

  return markersTable
end
local markersTable = buildMarkersTable()

function buildTracksTable()
  local tracksTable = {}
  local numTracks = reaper.GetNumTracks()

  for i = 0, numTracks - 1 do
    local track = reaper.GetTrack(0, i)
    local retVal, trackName = reaper.GetTrackName(track)
    tracksTable[#tracksTable + 1] = {
      index = i,
      name = trackName
    }
  end
  return tracksTable
end
local tracksTable = buildTracksTable()

local preCacheCoroutine =
  coroutine.create(
  function()
    benchmark.start("pre-cache actions")
    preCacheTargets(actionsTable, "name")
    benchmark.stop("pre-cache actions")

    benchmark.start("pre-cache plugins")
    preCacheTargets(pluginsTable, "name")
    benchmark.stop("pre-cache plugins")

    preCacheTargets(markersTable, "name")
  end
)
coroutine.resume(preCacheCoroutine)

local inputString = ""
local searchString = ""

local selectedIndex = 1
local resultsList = {}
local mode = "actions"
local searchCoroutine = nil

-- This is the function that runs in the main loop:
function listen()
  if GUI.char == GUI.chars.UP then
    selectedIndex = selectedIndex - 1
    selectedIndex = selectedIndex >= 1 and selectedIndex or 1
    updateResultsBox()
  end

  if GUI.char == GUI.chars.DOWN then
    selectedIndex = selectedIndex + 1
    selectedIndex = selectedIndex <= #resultsList and selectedIndex or #resultsList
    updateResultsBox()
  end

  if GUI.char == GUI.chars.RETURN then
    if #resultsList == 0 then
      gfx.quit()
      return
    end

    local selectedObj = resultsList[selectedIndex].obj

    if mode == "actions" then
      local commandID = selectedObj.code
      reaper.Main_OnCommand(commandID, 0)
    elseif mode == "plugins" then
      -- open plugin
      local selectedTrack = reaper.GetSelectedTrack2(0, 0, true)
      if selectedTrack ~= nil then
        local fxName = selectedObj.name .. ".RfxChain"
        local effectIndex = reaper.TrackFX_AddByName(selectedTrack, fxName, false, -1)
        reaper.TrackFX_SetOpen(selectedTrack, effectIndex, true)
      else
        msg("Error: No track selected")
      end
    elseif mode == "markers" then
      reaper.GoToMarker(0, selectedObj.index, false)
    elseif mode == "tracks" then
      local track = reaper.GetTrack(0, selectedObj.index)
      reaper.SetOnlyTrackSelected(track)
      reaper.Main_OnCommand(40913, -1) -- Track: vertical scroll selected tracks into view
      reaper.SetMixerScroll(track) -- scroll mixer to view the track
    end
    gfx.quit()
  end

  local prevSearchStringLength = #searchString
  local searchTableComplete = false

  if GUI.Val("input") ~= inputString then
    inputString = GUI.Val("input")
    local firstChar = string.sub(inputString, 1, 1)

    if firstChar == "$" then
      mode = "plugins"
      searchString = string.sub(inputString, 2)
    elseif firstChar == "@" then
      mode = "markers"
      searchString = string.sub(inputString, 2)
    elseif firstChar == ">" then
      mode = "tracks"
      searchString = string.sub(inputString, 2)
    else
      mode = "actions"
      searchString = inputString
    end

    local searchTable = {}
    if searchTableComplete and #searchString > 1 and #searchString > prevSearchStringLength then
      -- only search within current results for efficiency
      for _, result in pairs(resultsList) do
        searchTable[#searchTable + 1] = result.obj
      end
    else
      if mode == "actions" then
        searchTable = actionsTable
      elseif mode == "plugins" then
        searchTable = pluginsTable
      elseif mode == "markers" then
        searchTable = markersTable
      elseif mode == "tracks" then
        searchTable = tracksTable
      end
    end

    local results = {}
    searchCoroutine =
      coroutine.create(
      function()
        searchTableComplete = false
        benchmark.start("fuzzysort")
        results = fuzzysort.go(searchString, searchTable, {key = "name"})
        benchmark.stop("fuzzysort")

        benchmark.start("results list")

        resultsList = {}
        for i, result in sortedResults(results) do
          resultsList[#resultsList + 1] = result
        end

        benchmark.stop("results list")

        -- Now that resultsList might be shorter, make sure our selectedIndex is still within bounds
        selectedIndex = selectedIndex <= #resultsList and selectedIndex or #resultsList
        selectedIndex = selectedIndex == 0 and 1 or selectedIndex

        benchmark.start("udpate results")

        GUI.elms.results.list = resultsForListbox(resultsList)
        updateResultsBox()

        benchmark.stop("udpate results")
        searchTableComplete = true
      end
    )

    coroutine.resume(searchCoroutine)
  end

  if searchCoroutine ~= nil and coroutine.status(searchCoroutine) == "suspended" then
    coroutine.resume(searchCoroutine)
  end

  if coroutine.status(preCacheCoroutine) == "suspended" then
    -- Only continue pre-cache if there's no search running
    if not (searchCoroutine and coroutine.status(searchCoroutine) == "suspended") then
      coroutine.resume(preCacheCoroutine)
    end
  end
end

function updateResultsBox()
  GUI.Val("results", selectedIndex)
  GUI.redraw_z[0] = true
end

GUI.Init()
GUI.freq = 0
GUI.func = listen
GUI.Main()
