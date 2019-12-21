modeName = "plugins"

local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
dofile(script_path .. "Fuzz.lua")
