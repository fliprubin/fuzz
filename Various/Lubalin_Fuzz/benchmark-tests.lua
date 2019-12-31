-- test some lua features to see what I should optimized

function msg(m)
  return reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

-- test char comparison methods:


function compareStr(input)
  local charA = 'c' + input
  local charB = 'd'
  return charA == charB
end

function compareChar(input)
  local charA = 120 + input
  local charB = 76
  return charA == charB
end

local startTime, endTime = 0, 0
local result

msg('strings: ')
startTime = os.clock()
for i = 1, 10000000 do
  result = compareStr(i)
end
endTime = os.clock()
msg(endTime - startTime)

msg(' ')
msg('chars: ')
startTime = os.clock()
for i = 1, 10000000 do
  result = compareChar(i)
end
endTime = os.clock()
msg(endTime - startTime)