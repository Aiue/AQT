local _,st = ...

local AQT = LibStub("AceAddon-3.0"):GetAddon("AQT")
--local LSM = LibStub("LibSharedMedia-3.0")
local Prism = LibStub("LibPrism-1.0")

local tinsert,tremove,tsort = table.insert,table.remove,table.sort

local recycler = {}

local gui = CreateFrame("Frame", nil, UIParent)
gui.content = {}

local function getAvailableName(name)
   if not _G[name] then return name else
      local count = string.match(name, "%d+")
      if not count then count = 0 end
      count = count + 1
      return getAvailableName(string.sub(name, string.find(name, "%a+")) .. tostring(count))
   end
end

local guiFunc = {}

function guiFunc:Release(recursed)
   local parent = self:GetParent()
   for k,v in ipairs(self.children) do
      v:SetPoint("TOPLEFT", nil)
      v:Release(true)
   end

   if not recursed then
      parent:RelinkChildren()
      for k,v in ipairs(parent.children) do
	 if self == v then tinsert(recycler, tremove(parent.children, k)) end
      end
   end
end

function guiFunc:UnlinkChildren()
   for k,v in ipairs(self.children) do
      self:SetPoint("TOPLEFT", nil)
   end
end

function guiFunc:RelinkChildren()
   self:UnlinkChildren() -- While we shouldn't get any circular links, play it safe and unlink everything first
   for k,v in ipairs(self.children) do
      if k == 1 then v:SetPoint("TOPLEFT", self, "TOPLEFT")
      else v:SetPoint("TOPLEFT", self.children[k-1], "BOTTOMLEFT") end
   end
end

function guiFunc:ButtonCheck()
   if #self.children > 0 then
      self.button:Show()
      --also enable scripts
   else
      self.button:Hide()
      --also disable scripts
   end
end

local mt = {
   __index = function(t, k)
      return guiFunc[k]
   end
}

function gui:New()
   if #recycler > 0 then
      object = tremove(recycler)
   else
      object = CreateFrame("Frame", getAvailableName("AQTRow"))
      object.button = CreateFrame("Button", getAvailableName("AQTButton"), object)
      object.button:SetPoint("TOPLEFT", object)
      object.button:SetSize(16,16)
      -- Interface\\BUTTONS\\UI-HideButton-[Disabled|Down|Up]
      -- Interface\\BUTTONS\\UI-PlusButton-[Disabled|Down|Hilight|Up]
      object.text = CreateFontString(getAvailableName("AQTText"), object)
      object.text = SetJustifyH("LEFT")
      object.text:SetPoint("TOPLEFT", object.button, "TOPRIGHT")
      object.counter = CreateFontString(getAvailableName("AQTCounter"), object)
      object.counter:SetJustifyH("RIGHT")
      object.counter:SetPoint("TOPRIGHT", object)
      object.text:SetPoint("TOPRIGHT", object.counter, "TOPLEFT")
   end
   object.children = {}
   object.text:SetText("")
   object.counter:SetText("")
   setmetatable(object, mt)
   return object
end

function gui:Update()
end
