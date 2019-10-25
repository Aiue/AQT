for k,v in ipairs({...}) do
   if v:match("^--include=") then
      if not file_list then file_list = {} end
      table.insert(file_list, v)
   else
      error("Unknown command: '" .. v .. "'.")
   end
end

if not file_list then file_list = {"Core.lua", "Config.lua", "GUI.lua"} end

L = {}

for k,v in ipairs(file_list) do
   local file,err = io.open(v)

   if not file then error(err) end

   for line in file:lines() do
      for key in line:gmatch("L%.([%ad_-]+)") do
	 L[key] = true
      end
      for key in line:gmatch("L%[\"([^\"%]]+)\"%]") do
	 L[key] = true
      end
   end
end

sorted = {}

for k,v in pairs(L) do table.insert(sorted, k) end

table.sort(sorted, function(a, b) return a < b end)

for k,v in ipairs(sorted) do print("L[\"" .. v .. "\"] = true") end