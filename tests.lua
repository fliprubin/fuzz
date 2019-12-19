-- Just some basic ugly tests to check if I broke things
-- Maybe eventually I'll upgrade this to proper unit tests

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

local tests = {}

function tests.simple()
  local list = {"fleet", "for lack", "follower", "effortless", "goat", "fact"}
  local search = "fl"
  local results = fuzzysort.go(search, list)

  for i, result in ipairs(results) do
    msg(i .. " result: " .. result.target .. ", score: " .. result.score)
  end

  msg("1")
  msg(results[1].target == "fleet" and results[1].score == -3)
  msg("2")
  msg(results[2].target == "for lack" and results[2].score == -10)
  msg("3")
  msg(results[3].target == "follower" and results[3].score == -2006)
  msg("4")
  msg(results[4].target == "effortless" and results[4].score == -7008)
  msg("5")
  msg(results[5] == nil)
end

function tests.withKey()
  local list = {
    {thing = "fleet"},
    {thing = "for lack"},
    {thing = "follower"},
    {thing = "effortless"},
    {thing = "goat"},
    {thing = "fact"}
  }
  local search = "fl"
  local results = fuzzysort.go(search, list, {key = "thing"})

  for i, result in ipairs(results) do
    msg(i .. " result: " .. result.target .. ", score: " .. result.score)
  end

  msg("1")
  msg(results[1].target == "fleet" and results[1].score == -3)
  msg("2")
  msg(results[2].target == "for lack" and results[2].score == -10)
  msg("3")
  msg(results[3].target == "follower" and results[3].score == -2006)
  msg("4")
  msg(results[4].target == "effortless" and results[4].score == -7008)
  msg("5")
  msg(results[5] == nil)
end

msg('simple:')
tests.simple()
msg('with key:')
tests.withKey()
