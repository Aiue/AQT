for k,v in ipairs({...}) do
   if v:match("^--include=") then
      if not file_list then file_list = {} end
      local file = v:gsub("--include=", "")
      table.insert(file_list, file)
   else
      error("Unknown command: '" .. v .. "'.")
   end
end

if not file_list then file_list = {"Core.lua", "Config.lua", "GUI.lua"} end

Cache = {}

new = 0

dofile("LocaleCache")

for k,v in ipairs(file_list) do
   local file,err = io.open(v)

   if not file then error(err) end

   for line in file:lines() do
      for key in line:gmatch("L%.([%a%d_]+)") do
	 if not L[key] then new = new + 1 end
	 Cache[key] = true
      end
      for key in line:gmatch("L%[\"(.-)\"%]") do
	 if not L[key] then new = new + 1 end
	 Cache[key] = true
      end
   end
end

sorted = {}

for k,v in pairs(Cache) do table.insert(sorted, k) end

table.sort(sorted, function(a, b) return a < b end)

local output,err = io.open("L.lua", "w")

for k,v in ipairs(sorted) do output:write("L[\"" .. v .. "\"] = true\n") end
print(new)
