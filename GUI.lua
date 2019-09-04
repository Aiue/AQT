local _,st = ...

local AQT = LibStub("AceAddon-3.0"):GetAddon("AQT")
local LSM = LibStub("LibSharedMedia-3.0")
local Prism = LibStub("LibPrism-1.0")

local tinsert,tremove,tsort = table.insert,table.remove,table.sort

local recycler = {}

local function getAvailableName(name)
   if not _G[name] then return name else
      local count = string.match(name, "%d+")
      if not count then count = 0 end
      count = count + 1
      return getAvailableName(string.sub(name, string.find(name, "%a+")) .. tostring(count))
   end
end

local gui = CreateFrame("Frame", getAvailableName("AQTParent"), UIParent)
st.gui = gui
gui.content = {} --???

local guiFunc = {}

function gui:OnEnable()
   gui:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -250)

   local padding = 2 --or whatever the config says

   gui.scrollFrame = CreateFrame("ScrollFrame", getAvailableName("AQTScrollFrame"), gui)
   gui.scrollFrame:SetPoint("TOPLEFT", gui, "TOPLEFT", padding, -padding)
   gui.scrollFrame:SetPoint("BOTTOMRIGHT", gui, "BOTTOMRIGHT", -padding, padding)

   gui.scrollChild = CreateFrame("Frame", getAvailableName("AQTScrollChild"), gui.scrollFrame)
   gui.scrollChild:SetPoint("TOPLEFT", gui.scrollFrame)
   gui.scrollChild:SetPoint("TOPRIGHT", gui.scrollFrame)
   gui.scrollFrame:SetScrollChild(gui.scrollChild)

   local backdrop = {
      bgFile = LSM:Fetch("background", st.cfg.backdrop.background.name),
      edgeFile = LSM:Fetch("border", st.cfg.backdrop.border.name),
      tileSize = st.cfg.backdrop.tileSize,
      edgeSize = st.cfg.backdrop.edgeSize,
      insets = {
	 left = st.cfg.backdrop.insets.l,
	 right = st.cfg.backdrop.insets.r,
	 top = st.cfg.backdrop.insets.t,
	 bottom = st.cfg.backdrop.insets.b
      }
   }

   gui:SetBackdrop(backdrop)
   gui:SetBackdropColor(st.cfg.backdrop.background.r, st.cfg.backdrop.background.g, st.cfg.backdrop.background.b, st.cfg.backdrop.background.a)
   gui:SetBackdropBorderColor(st.cfg.backdrop.border.r, st.cfg.backdrop.border.g, st.cfg.backdrop.border.b, st.cfg.backdrop.border.a)
end

--function f:newAnchor(name)
--   anchor:UpdateBackdrop()
--   anchor:SetWidth(st.cfg.profile.frames[name].minWidth)
--   anchor:SetHeight(padding*2)
--   anchor.scrollFrame:GetScrollChild():SetHeight(0) -- not sure if this will be proper or naeh
--end

local mt = {
   __index = function(t, k)
      return guiFunc[k]
   end
}

function guiFunc:Release(recursed)
   local parent = self:GetParent()
   for k,v in ipairs(self.children) do
      v:SetPoint("TOPLEFT", nil)
      v:Release(true)
   end

   if not recursed then
      parent:RelinkChildren()
   end

   self.text:SetText("")
   self.counter:SetText("")
   self.container:SetHeight(0)

   for k,v in ipairs(parent.children) do
      if self == v then tinsert(recycler, tremove(parent.children, k)) end
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
      if k == 1 then v:SetPoint("TOPLEFT", self.container, "TOPLEFT")
      else v:SetPoint("TOPLEFT", self.children[k-1], "BOTTOMLEFT") end
   end
end

function guiFunc:New()
   if #recycler > 0 then
      object = tremove(recycler)
      object.container:Show()
   else
      object = CreateFrame("Frame", getAvailableName("AQTRow"))
      object.button = CreateFrame("Button", getAvailableName("AQTButton"), object)
      object.button:SetPoint("TOPLEFT", object)
      object.button:SetSize(16,16)
      object.text = CreateFontString(getAvailableName("AQTText"), object)
      object.text = SetJustifyH("LEFT")
      object.text:SetPoint("TOPLEFT", object.button, "TOPRIGHT")
      object.counter = CreateFontString(getAvailableName("AQTCounter"), object)
      object.counter:SetJustifyH("RIGHT")
      object.counter:SetPoint("TOPRIGHT", object)
      object.text:SetPoint("TOPRIGHT", object.counter, "TOPLEFT")
      object.container = CreateFrame("Frame", getAvailableName("AQTContainer"), object) -- Optionally only create this when actually needed.
      object.children = {}
      setmetatable(object, mt)
   end
   object:SetParent(self)
   object:ButtonCheck()
   tinsert(self.children, object)
   self:Update()
   return object
end

function guiFunc:Update()
   self:Sort()
   self:ButtonCheck()
   self:UpdateSize()
end

function guiFunc:ButtonCheck()
   if #self.children > 0 then
      if self.container:IsShown() then
	 self.button:SetNormalTexture([[Interface\BUTTONS\UI-HideButton-Up]])
      else
	 self.button:SetNormalTexture([[Interface\BUTTONS\UI-PlusButton-Up]])
      end
      self.button:Show()
      --also enable scripts? ..although hiding it should be enough
   else
      self.button:Hide()
      --also disable scripts?
   end
   -- Interface\\BUTTONS\\UI-HideButton-[Disabled|Down|Up]
   -- Interface\\BUTTONS\\UI-PlusButton-[Disabled|Down|Hilight|Up]
end

function guiFunc:Sort()
   --sortfunc, followed by
   self:RelinkChildren()
end

function guiFunc:UpdateSize()
   local h,w = 0,0 -- Do I need width? ...possibly
   for k,v in ipairs(self.children) do
      local th,ch = v.text:GetHeight(),v.counter:GetHeight()
      h = h + (th > ch and th or ch) + v.container:GetHeight()
   end

   self.container:SetHeight(h)
   
   if self:GetParent() ~= UIParent then self:GetParent():UpdateSize() end --change this, eventually "gui" is going to be the parent, and that will be the base case.
end
