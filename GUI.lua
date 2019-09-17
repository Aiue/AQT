local _,st = ...

local AQT = LibStub("AceAddon-3.0"):GetAddon("AQT")
local LSM = LibStub("LibSharedMedia-3.0")
local Prism = LibStub("LibPrism-1.0")

local tinsert,tremove,tsort = table.insert,table.remove,table.sort

local recycler = {}

local function getAvailableName(name) -- Version for debug purposes.
   if not _G[name] then return name else
      local count = string.match(name, "%d+")
      if not count then count = 0 end
      count = count + 1
      return getAvailableName(string.sub(name, string.find(name, "%a+")) .. tostring(count))
   end
end

--local function getAvailableName(name) return nil end

local gui = CreateFrame("Frame", getAvailableName("AQTParent"), UIParent)
st.gui = gui
gui.content = {} --???

local guiFunc = {}

function gui:OnEnable()
   gui.font = CreateFont(getAvailableName("AQTFont"))
   gui.font:SetJustifyV("TOP")

   gui.scrollFrame = CreateFrame("ScrollFrame", getAvailableName("AQTScrollFrame"), gui)
   gui.scrollChild = CreateFrame("Frame", getAvailableName("AQTScrollChild"), gui.scrollFrame)
   gui.scrollFrame:SetScrollChild(gui.scrollChild)
   gui.scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
				self:GetScrollChild():SetWidth(width)
   end)
   gui.scrollFrame:EnableMouseWheel(true)
   gui.scrollFrame:SetScript("OnMOuseWheel", function(self, delta)
				local pos = self:GetVerticalScroll()
				local setpos
				if pos-delta < 0 then setpos = 0
				elseif pos-delta > self:GetVerticalScrollRange() then setpos = self:GetVerticalScrollRange()
				else setpos = pos-delta end
				self:SetVerticalScroll(setpos)
   end)
   gui.scrollChild.children = {}

   function gui.scrollChild:UpdateSize()
      local h = gui.title:GetHeight() + (gui.title.container:IsShown() and gui.title.container:GetHeight() or 0)
      gui.scrollChild:SetHeight(h)

      gui:SetHeight((h + st.cfg.padding*2) > st.cfg.maxHeight and st.cfg.maxHeight or (h + st.cfg.padding*2))
   end


   gui.title = guiFunc.New(gui.scrollChild)
   gui.title:SetPoint("TOPLEFT", gui.scrollChild, "TOPLEFT")
   gui.title:SetPoint("TOPRIGHT", gui.scrollChild, "TOPRIGHT")
   gui.title.button.isClickButton = true
   gui:Redraw(false)
   gui.title.text:SetText("Quests")
   gui.title.counter:SetText("|cff00ff000/" .. tostring(MAX_QUESTLOG_QUESTS) .. "|r")
   gui.title:Update()

end

function gui:Redraw(recurse)
   gui:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", st.cfg.posX, st.cfg.posY)

   gui.font:SetFont(LSM:Fetch("font", st.cfg.font.name), st.cfg.font.size)
   gui.font:SetTextColor(st.cfg.font.r, st.cfg.font.g, st.cfg.font.b, st.cfg.font.a)
   gui.font:SetShadowOffset(st.cfg.font.shadow.x, st.cfg.font.shadow.y)
   gui.font:SetSpacing(st.cfg.font.spacing)

   gui.scrollFrame:SetPoint("TOPLEFT", gui, "TOPLEFT", st.cfg.padding, -st.cfg.padding)
   gui.scrollFrame:SetPoint("BOTTOMRIGHT", gui, "BOTTOMRIGHT", -st.cfg.padding, st.cfg.padding)

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

   gui:SetWidth(st.cfg.maxWidth) --!!!RE!!!

   gui:RedrawColor()
end

function gui:RedrawColor()
   gui.font:SetTextColor(st.cfg.font.r, st.cfg.font.g, st.cfg.font.b, st.cfg.font.a)   
   gui.font:SetShadowColor(st.cfg.font.shadow.r, st.cfg.font.shadow.g, st.cfg.font.shadow.b, st.cfg.font.shadow.a)
   gui:SetBackdropColor(st.cfg.backdrop.background.r, st.cfg.backdrop.background.g, st.cfg.backdrop.background.b, st.cfg.backdrop.background.a)
   gui:SetBackdropBorderColor(st.cfg.backdrop.border.r, st.cfg.backdrop.border.g, st.cfg.backdrop.border.b, st.cfg.backdrop.border.a)
end

local mt = {
   __index = function(t, k)
      if guiFunc[k] then return guiFunc[k] else return getmetatable(gui).__index[k] end --!!!RE!!!
   end
}

function guiFunc:Release(recursed)
   local parent = self:GetParent()
   while #self.children > 0 do
      self.children[1]:SetPoint("TOPLEFT", nil)
      self.children[1]:Release(true)
   end

   local found

   for k,v in ipairs(parent.children) do
      if self == v then tinsert(recycler, tremove(parent.children, k));found = true end
   end

   if not found then print("Could not find what we're trying to release..");print(self:GetParent().text:GetText() .. "/" .. self.text:GetText()) end

   self.text:SetText("")
   self.counter:SetText("")
   self.button.isClickButton = nil
   self.button:Hide()
   self.container:Show()
   self:SetParent(nil)

   if not recursed then
      parent:RelinkChildren()
      parent:UpdateSize(true)
   end
end

function guiFunc:UnlinkChildren()
   for k,v in ipairs(self.children) do
      v:SetPoint("TOPLEFT", nil)
      v:SetPoint("TOPRIGHT", nil)
   end
end

function guiFunc:RelinkChildren()
   self:UnlinkChildren() -- While we shouldn't get any circular links, play it safe and unlink everything first
   for k,v in ipairs(self.children) do
      if k == 1 then
	 v:SetPoint("TOPLEFT", self.container, "TOPLEFT")
	 v:SetPoint("TOPRIGHT", self.container, "TOPRIGHT")
      else
	 v:SetPoint("TOPLEFT", self.children[k-1].container, "BOTTOMLEFT") 
	 v:SetPoint("TOPRIGHT", self.children[k-1].container, "BOTTOMRIGHT")
      end
   end
end

function guiFunc:New()
   if #recycler > 0 then
      object = tremove(recycler)
      object.container:Show()
      object:SetParent(self)
   else
      object = CreateFrame("Frame", getAvailableName("AQTRow"), self)
      object.button = CreateFrame("Button", getAvailableName("AQTButton"), object)
      object.button:SetPoint("TOPLEFT", object)
      object.button:SetSize(12,12)
      object.text = object:CreateFontString(getAvailableName("AQTText"), object)
      object.text:SetFontObject(gui.font)
      object.text:SetJustifyH("LEFT")
      object.text:SetPoint("TOPLEFT", object.button, "TOPRIGHT", -10)
      object.text:SetWordWrap(true)
      object.counter = object:CreateFontString(getAvailableName("AQTCounter"), object)
      object.counter:SetFontObject(gui.font)
      object.counter:SetJustifyH("RIGHT")
      object.counter:SetPoint("TOPRIGHT", object)
      object.container = CreateFrame("Frame", getAvailableName("AQTContainer"), object)
      object.container:SetPoint("TOPLEFT", object, "BOTTOMLEFT")
      object.container:SetPoint("TOPRIGHT", object, "BOTTOMRIGHT")
      object.children = {}
      setmetatable(object, mt)
   end
   object:ButtonCheck()
   tinsert(self.children, object)
   if self ~= gui.scrollChild then self:Update() end
   return object
end

function guiFunc:Update()
   self:Sort()
   self:ButtonCheck()
   self:UpdateSize(true) --!!!RE!!! Might want to NOT call this always. Only most of the time. Probably best to break it out and only call it when we actually need to.
end

local function clickButton(self, button, down)
end

function guiFunc:ButtonCheck()
   if self.button.isClickButton then
      if #self.children > 0 then
	 if self.container:IsShown() then
	    self.button:SetNormalTexture([[Interface\BUTTONS\UI-MinusButton-Up]])
	 else
	    self.button:SetNormalTexture([[Interface\BUTTONS\UI-PlusButton-Up]])
	 end
	 self.button:Show()
	 --also enable scripts? ..although hiding it should be enough
      else
	 self.button:Hide()
	 --also disable scripts?
      end
   end
   -- Interface\\BUTTONS\\UI-HideButton-[Disabled|Down|Up]
   -- Interface\\BUTTONS\\UI-PlusButton-[Disabled|Down|Hilight|Up]
end

function guiFunc:Sort()
   tsort(self.children, function(a,b)
	    return (a.text:GetText() and a.text:GetText() or "") < (b.text:GetText() and b.text:GetText() or "")
   end)
   --sortfunc, followed by
   self:RelinkChildren()
end

function guiFunc:UpdateSize(recurse) --!!!RE!!! Should use OnSizeChanged() for some of these things. Particularly useful for fontstrings.
   local h,w = 0,0 -- Do I need width? ...possibly
   for k,v in ipairs(self.children) do
--      local th,ch = v.text:GetHeight(),v.counter:GetHeight()
--      h = h + (th > ch and th or ch) + (v.container:IsShown() and v.container:GetHeight() or 0)
      h = h + v:GetHeight() + (v.container:IsShown() and v.container:GetHeight() or 0)
   end

   self.container:SetHeight(self.container:IsShown() and (h > 0 and h or .1)) -- Need to make sure height is > 0 or it won't serve as an anchor.

   local th,ch = self.text:GetHeight(),self.counter:GetHeight()
   self:SetHeight(th > ch and th or ch)

   if recurse then self:GetParent():UpdateSize(true) end -- gui.scrollChild will have its own function, so no need for a base case
end
