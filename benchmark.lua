benchmark = {
  benchList = {},
  bypass = false,
}

local function round(x)
  return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end

function benchmark.start(name)
  if benchmark.bypass then 
    return
  end

  benchmark.benchList[name] = os.clock()
end

function benchmark.stop(name)
  if benchmark.bypass then 
    return
  end

  local stopTime = os.clock()
  local time = stopTime - benchmark.benchList[name]
  local timeInMs = round(time * 1000)

  msg('BENCH --> ' .. timeInMs .. 'ms' .. '\t' .. name)
end