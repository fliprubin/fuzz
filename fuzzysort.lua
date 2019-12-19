-- Heavily based on https://github.com/farzher/fuzzysort/

-- Print anything - including nested tables (from http://lua-users.org/wiki/TableSerialization)
function table_print(tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    for key, value in pairs(tt) do
      io.write(string.rep(" ", indent)) -- indent it
      if type(value) == "table" and not done[value] then
        done[value] = true
        io.write(string.format("[%s] => table\n", tostring(key)))
        io.write(string.rep(" ", indent + 4)) -- indent it
        io.write("(\n")
        table_print(value, indent + 7, done)
        io.write(string.rep(" ", indent + 4)) -- indent it
        io.write(")\n")
      else
        io.write(string.format("[%s] => %s\n", tostring(key), tostring(value)))
      end
    end
  else
    io.write(tt .. "\n")
  end
end

fuzzysort = {}

fuzzysort.matchesSimple = {}
fuzzysort.matchesStrict = {}

-- finds the indexes of the first letters of words
function fuzzysort.prepareBeginningIndexes(target)
  local beginningIndexes = {}
  local wasUpper, wasAlphanum = false, false

  for i = 1, #target do
    local targetCode = string.byte(target, i)
    local isUpper = targetCode >= 65 and targetCode <= 90
    local isAlphanum = isUpper or (targetCode >= 97 and targetCode <= 122) or (targetCode >= 48 and targetCode <= 57)
    local isBeginning = (isUpper and not wasUpper) or not wasAlphanum or not isAlphanum
    wasUpper = isUpper
    wasAlphanum = isAlphanum
    if isBeginning then
      beginningIndexes[#beginningIndexes + 1] = i
    end
  end

  return beginningIndexes
end

function fuzzysort.prepareNextBeginningIndexes(target)
  local beginningIndexes = fuzzysort.prepareBeginningIndexes(target)
  local nextBeginningIndexes = {}
  local lastIsBeginning = beginningIndexes[1]
  local lastIsBeginningIndex = 1
  for i = 1, #target do
    if (lastIsBeginning ~= nil) and lastIsBeginning > i then
      nextBeginningIndexes[i] = lastIsBeginning
    else
      -- TODO: check that these two lines shouldn't be swapped
      lastIsBeginningIndex = lastIsBeginningIndex + 1
      lastIsBeginning = beginningIndexes[lastIsBeginningIndex]

      -- TODO: check this 'ternary' executes properly...
      nextBeginningIndexes[i] = lastIsBeginning == nil and #target + 1 or lastIsBeginning
    end
  end

  return nextBeginningIndexes
end

function fuzzysort.prepare(target)
  return {
    target = target,
    targetLower = string.lower(target),
    _nextBeginningIndexes = nil,
    score = nil,
    indexes = nil,
    obj = nil
  }
end

local matchesSimpleLength = 0

function fuzzysort.algorithmNoTypo(search, prepared)
  matchesSimpleLength = 0

  local searchIndex, targetIndex = 1, 1
  local target = prepared.targetLower

  local searchChar = string.byte(search, searchIndex)

  -- check if all search chars appear in order in the target:

  -- (I'm translating this from manually optimized js so it may be
  -- a bit janky in terms of semantics)
  repeat
    local isMatch = searchChar == string.byte(target, targetIndex)
    if isMatch then
      -- store the match index for later
      fuzzysort.matchesSimple[matchesSimpleLength + 1] = targetIndex
      matchesSimpleLength = matchesSimpleLength + 1
      -- increment the search index
      searchIndex = searchIndex + 1
      -- exit the loop if we've reached the end of the search chars
      if searchIndex > #search then
        break
      end
      -- set the next search char
      searchChar = string.byte(search, searchIndex)
    end

    -- increment target index
    targetIndex = targetIndex + 1
    -- if we reach the end of target and haven't found all chars,
    -- exit the function, as we did not find a match:
    if (targetIndex > #target) then
      return nil
    end
  until 0 == 1

  searchIndex = 1
  local successStrict = false

  -- TODO: using a length var instead of # because in the js version, they use this to overwrite
  -- elements instead of deleting them (probably for efficiency) and I'm just tryna get the algo
  -- right... may make more semantic / optimal eventually
  local matchesStrictLength = 0

  if prepared._nextBeginningIndexes == nil then
    prepared._nextBeginningIndexes = fuzzysort.prepareNextBeginningIndexes(target)
  end
  local nextBeginningIndexes = prepared._nextBeginningIndexes

  targetIndex = fuzzysort.matchesSimple[1] == 1 and 1 or nextBeginningIndexes[fuzzysort.matchesSimple[1] - 1]
  local firstPossibleIndex = targetIndex

  -- if we got here, the target string successfully matched all chars in the search
  -- now we apply some tests to see if we should improve the score of this result

  -- check for consecutive or beginning characters:
  if targetIndex ~= #target + 1 then
    repeat
      if targetIndex ~= nil and targetIndex > #target then
        -- we searched the whole target and didn't find what we wanted,
        if searchIndex <= 1 then
          -- we went through all the search chars and didn't get what we wanted
          break
        end
        -- go back to previous search char and move it forward
        searchIndex = searchIndex - 1

        local lastMatch = fuzzysort.matchesStrict[matchesStrictLength]
        matchesStrictLength = matchesStrictLength - 1

        targetIndex = nextBeginningIndexes[lastMatch]
      else
        local isMatch = string.byte(search, searchIndex) == string.byte(target, targetIndex)
        if isMatch then
          fuzzysort.matchesStrict[matchesStrictLength + 1] = targetIndex
          matchesStrictLength = matchesStrictLength + 1
          searchIndex = searchIndex + 1

          if searchIndex > #search then
            successStrict = true
            break
          end

          targetIndex = targetIndex + 1
        else
          targetIndex = nextBeginningIndexes[targetIndex]
        end
      end
    until 0 == 1
  end

  local matchesBest
  local matchesBestLength

  if successStrict then
    matchesBest = fuzzysort.matchesStrict
    matchesBestLength = matchesStrictLength
  else
    matchesBest = fuzzysort.matchesSimple
    matchesBestLength = matchesSimpleLength
  end

  local score = 0
  local lastTargetIndex = 0

  for i = 1, #search do
    local targetIndex = matchesBest[i]
    -- score only goes down if they're not consecutive
    if targetIndex ~= nil and lastTargetIndex ~= targetIndex - 1 then
      score = score - (targetIndex - 1)
    end
    lastTargetIndex = targetIndex
  end

  if not successStrict then
    score = score * 1000
  end

  score = score - (#target - #search)

  prepared.score = score

  prepared.indexes = {}
  for i = matchesBestLength, 1, -1 do
    prepared.indexes[i] = matchesBest[i]
  end

  return prepared
end

function fuzzysort.go(search, targets, options)
  if search == nil or search == "" then
    return {}
  end

  local results = {}

  if options and options.key then
    local key = options.key
    for i, obj in ipairs(targets) do
      local target = obj[key]
      local prepared = fuzzysort.prepare(target)
      local result = fuzzysort.algorithmNoTypo(search, prepared)
      if result ~= nil then
        result = {
          target = result.target,
          score = result.score,
          _nextBeginningIndexes = nil,
          indexes = result.indexes,
          obj = obj
        }
        results[#results + 1] = result
      end
    end
  else
    for i, target in ipairs(targets) do
      local prepared = fuzzysort.prepare(target)
      local result = fuzzysort.algorithmNoTypo(search, prepared)
      if result ~= nil then
        results[#results + 1] = result
      end
    end
  end

  return results
end