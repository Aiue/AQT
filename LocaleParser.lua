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

L = {}
Cache = {}

new = 0

local infile,err = io.open("LocaleCache")

if not infile then error(err) end

for line in infile:lines() do
   for key in line:gmatch("L%[\"(.-)\"%]") do
      Cache[key] = true
   end
end

io.close(infile)

for k,v in ipairs(file_list) do
   local file,err = io.open(v)

   if not file then error(err) end

   for line in file:lines() do
      for key in line:gmatch("L%.([%a%d_]+)") do
	 if not Cache[key] then new = new + 1 end
	 L[key] = true
      end
      for key in line:gmatch("L%[\"(.-)\"%]") do
	 if not Cache[key] then new = new + 1;end
	 L[key] = true
      end
   end
end

sorted = {}

for k,v in pairs(L) do table.insert(sorted, k) end

table.sort(sorted, function(a, b) return a < b end)

local output,err = io.open("L.lua", "w")

for k,v in ipairs(sorted) do output:write("L[\"" .. v .. "\"] = true\n") end
print(new)
