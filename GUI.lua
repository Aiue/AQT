local _,st = ...

local AQT = LibStub("AceAddon-3.0"):GetAddon("AQT")
local LSM = LibStub("LibSharedMedia-3.0")
local Prism = LibStub("LibPrism-1.0")

local tinsert,tremove,tsort = table.insert,table.remove,table.sort

local recycler = {}

local function getAvailableName(name)
   if not _G[name] then return name else
      local count = string.match(name, "%d+")
      if not count then count = 0 end -- !!!RE!!! Cache this to avoid lots of recursions when we already have a whole bunch of frames.
      count = count + 1
      return getAvailableName(string.sub(name, string.find(name, "%a+")) .. tostring(count))
   end
end

local gui = CreateFrame("Frame", getAvailableName("AQTParent"), UIParent)
st.gui = gui
gui.content = {} --???

local guiFunc = {}

function gui:OnEnable()
   gui:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", st.cfg.posX, st.cfg.posY)

   local padding = 2 --or whatever the config says

   gui.font = CreateFont(getAvailableName("AQTFont"))
   gui.font:SetJustifyV("TOP")
   gui.font:SetFont(LSM:Fetch("font", st.cfg.font.name), st.cfg.font.size)
   gui.font:SetShadowColor(st.cfg.font.shadow.r, st.cfg.font.shadow.g, st.cfg.font.shadow.b, st.cfg.font.shadow.a)
   gui.font:SetShadowOffset(st.cfg.font.shadow.x, st.cfg.font.shadow.y)
   gui.font:SetSpacing(st.cfg.font.spacing)
   gui.font:SetTextColor(st.cfg.font.r, st.cfg.font.g, st.cfg.font.b, st.cfg.font.a)

   gui.scrollFrame = CreateFrame("ScrollFrame", getAvailableName("AQTScrollFrame"), gui)
   gui.scrollFrame:SetPoint("TOPLEFT", gui, "TOPLEFT", st.cfg.padding, -st.cfg.padding)
   gui.scrollFrame:SetPoint("BOTTOMRIGHT", gui, "BOTTOMRIGHT", -st.cfg.padding, st.cfg.padding)

   gui.scrollChild = CreateFrame("Frame", getAvailableName("AQTScrollChild"), gui.scrollFrame)
   gui.scrollFrame:SetScrollChild(gui.scrollChild)
   gui.scrollChild:SetPoint("TOPLEFT", gui.scrollFrame)
   gui.scrollChild:SetPoint("TOPRIGHT", gui.scrollFrame)

   function gui.scrollChild:UpdateSize()
      local h = gui.title:GetHeight() + gui.title.container:GetHeight()
      gui.scrollChild:SetHeight(h)

      gui:SetHeight((h + st.cfg.padding*2) > st.cfg.maxHeight and st.cfg.maxHeight or (h + st.cfg.padding*2))
   end

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

   gui:SetWidth(st.cfg.maxWidth) --!!!RE!!!

   gui.title = guiFunc.New(gui.scrollChild)
   gui.title.text:SetText("AQT")
   gui.title.counter:SetText("|cff00ff000/20|r")
   gui.title:SetPoint("TOPLEFT", gui.scrollChild, "TOPLEFT")
   gui.title:SetPoint("TOPRIGHT", gui.scrollChild, "TOPRIGHT")
   gui.title:Update()
end

local mt = {
   __index = function(t, k)
      if guiFunc[k] then return guiFunc[k] else return getmetatable(gui).__index[k] end --!!!RE!!!
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
   self.container:Show()

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
      object = CreateFrame("Frame", getAvailableName("AQTRow"), self)
      object.button = CreateFrame("Button", getAvailableName("AQTButton"), object)
      object.button:SetPoint("TOPLEFT", object)
      object.button:SetSize(16,16)
      object.text = object:CreateFontString(getAvailableName("AQTText"), object)
      object.text:SetFontObject(gui.font)
      object.text:SetJustifyH("LEFT")
      object.text:SetPoint("TOPLEFT", object.button, "TOPRIGHT")
      object.counter = object:CreateFontString(getAvailableName("AQTCounter"), object)
      object.counter:SetFontObject(gui.font)
      object.counter:SetJustifyH("RIGHT")
      object.counter:SetPoint("TOPRIGHT", object)
      object.text:SetPoint("TOPRIGHT", object.counter, "TOPLEFT")
      object.container = CreateFrame("Frame", getAvailableName("AQTContainer"), object) -- Optionally only create this when actually needed.
      object.children = {}
      setmetatable(object, mt)
   end
   object:ButtonCheck()
   tinsert(object, self.children)
   if self ~= gui.scrollChild then self:Update() end
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

   local th,ch = self.text:GetHeight(),self.counter:GetHeight()
   self:SetHeight(th > ch and th or ch)

   self:GetParent():UpdateSize() -- gui.scrollChild will have its own function, so no need for a base case
end
