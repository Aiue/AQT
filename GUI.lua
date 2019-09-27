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

--      print("GetVerticalScroll(): " .. tostring(gui.scrollFrame:GetVerticalScroll()) .. "; GetVerticalScrollRange(): " .. tostring(gui.scrollFrame:GetVerticalScrollRange())) -- So I've concluded it's definitely called too often. But it doesn't seem to do what it should when it should.
      -- Ok. It's called too frequently, but.. it would appear that it for some reason ends up being called BEFORE something is removed. Definitely not sure why this would be.
      if gui.scrollFrame:GetVerticalScroll() > gui.scrollFrame:GetVerticalScrollRange() then gui.scrollFrame:SetVerticalScroll(gui.scrollFrame:GetVerticalScrollRange()) end
   end


   gui.title = guiFunc.New(gui.scrollChild)
   gui.title.owner = {type = gui} -- Special hack.
   gui.title:SetPoint("TOPLEFT", gui.scrollChild, "TOPLEFT")
   gui.title:SetPoint("TOPRIGHT", gui.scrollChild, "TOPRIGHT")
--   gui.title.button.isClickButton = true
   gui:Redraw(false)
   gui.title.text:SetText("Quests")
--   gui.title.counter:SetText("|cff00ff000/" .. tostring(MAX_QUESTLOG_QUESTS) .. "|r")
   gui.title:Update()
end

function gui:Redraw(recurse)
   gui:ClearAllPoints()
   gui:SetPoint(st.cfg.anchorFrom, UIParent, st.cfg.anchorTo, st.cfg.posX, st.cfg.posY)

   gui.font:SetFont(LSM:Fetch("font", st.cfg.font.name), st.cfg.font.size, st.cfg.font.outline)
   gui.font:SetSpacing(st.cfg.font.spacing)

   gui.scrollFrame:SetPoint("TOPLEFT", gui, "TOPLEFT", st.cfg.padding, -st.cfg.padding)
   gui.scrollFrame:SetPoint("BOTTOMRIGHT", gui, "BOTTOMRIGHT", -st.cfg.padding, st.cfg.padding)

   local backdrop = {
      bgFile = LSM:Fetch("background", st.cfg.backdrop.background.name),
      edgeFile = LSM:Fetch("border", st.cfg.backdrop.border.name),
      tileSize = st.cfg.backdrop.tileSize,
      edgeSize = st.cfg.backdrop.edgeSize,
      tile = st.cfg.backdrop.tile,
      insets = {
	 left = st.cfg.backdrop.insets,
	 right = st.cfg.backdrop.insets,
	 top = st.cfg.backdrop.insets,
	 bottom = st.cfg.backdrop.insets,
      }
   }

   gui:SetBackdrop(backdrop)

   gui:SetWidth(st.cfg.maxWidth) --!!!RE!!!

   gui.scrollChild:UpdateSize()

   gui:RedrawColor(false)
end

function gui:RedrawColor()
   gui.font:SetTextColor(st.cfg.font.r, st.cfg.font.g, st.cfg.font.b, st.cfg.font.a)   
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

   for k,v in ipairs(parent.children) do -- This sometimes fails. Figure out why. (Parent should never be nil.)
      if self == v then tinsert(recycler, tremove(parent.children, k));found = true end
   end

   if not found then print("Could not find what we're trying to release..");print(self:GetParent().text:GetText() .. "/" .. self.text:GetText()) end

   self.owner = nil
   self.text:SetText("")
   self.counter:SetText("")
--   self.button.isClickButton = nil
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
--   object:ButtonCheck()
   tinsert(self.children, object)
   if self ~= gui.scrollChild then self:Update() end
   return object
end

function guiFunc:Update()
   self:Sort()
   if self:GetParent().Sort then self:GetParent():Sort() end
   self:ButtonCheck()
   self:UpdateText()
end

local function clickButton(self, button, down)
end

function guiFunc:ButtonCheck()
   if self == gui.title or self.owner.type == st.types.Header then
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
   elseif self.owner.type == st.types.Quest then
      if self.owner.complete then
	 if self.owner.complete < 0 then
	    self.button:SetNormalTexture([[Interface\RAIDFRAME\ReadyCheck-NotReady]])
	 elseif self.owner.complete > 0 then
	    self.button:SetNormalTexture([[Interface\RAIDFRAME\ReadyCheck-Ready]])
	 end
	 self.button:Show()
      else
	 self.button:Hide()
      end
   end
end

function guiFunc:Sort()
   tsort(self.children, function(a,b)
	    if not a.owner or not b.owner then return false
	    elseif a.owner.type ~= b.owner.type then return tostring(a.owner.type) > tostring(b.owner.type)
	    elseif not a.owner.sortFields then -- b.owner.sortFields should be the same in this case
	       return false
	    else
	       for i,v in ipairs(a.owner.sortFields) do
		  if a.owner[v.field] ~= b.owner[v.field] then
		     if v.descending then
			if not a.owner[v.field] then -- nil, so b is not
			   return false
			elseif not b.owner[v.field] then -- nil, so a is not
			   return true
			else return a.owner[v.field] > b.owner[v.field] end
		     else
			if not a.owner[v.field] then
			   return true
			elseif not b.owner[v.field] then
			   return false
			else return a.owner[v.field] < b.owner[v.field] end
		     end
		  end
	       end
	    end
	    return false -- some kind of default, just in case, shouldn't realistically ever get here, though
   end)
   self:RelinkChildren()
end

function guiFunc:UpdateSize(recurse) --!!!RE!!! Should use OnSizeChanged() for some of these things. Particularly useful for fontstrings. Which can't set that script, so uh. Still. Get back to this. Could solve some of my other issues. And FontStrings I can handle in UpdateText().
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

function guiFunc:UpdateText(recurse)
   local HSVorRGB = st.cfg.useHSVGradient and "hsv" or "rgb"

   local th,tw,ch,tw = self.text:GetStringHeight(),self.text:GetStringWidth(),self.counter:GetStringHeight(),self.counter:GetStringWidth()

   if self.owner.type == st.types.Header then
      self.text:SetText(self.owner.titleText)
      if st.cfg.showHeaderCount and self.owner.counterText then
	 local text
	 if st.cfg.useProgressColor then
	    text = "|cff" .. Prism:Gradient(HSVorRGB, st.cfg.progressColorMin.r, st.cfg.progressColorMax.r, st.cfg.progressColorMin.g, st.cfg.progressColorMax.g, st.cfg.progressColorMin.b, st.cfg.progressColorMax.b, (self.owner.progress or 1)) .. self.owner.counterText .. "|r"
	 else text = self.owner.counterText end
	 self.counter:SetText(text)
	 self.counter:Show()
      else
	 self.counter:SetText("")
	 self.counter:Hide()
      end
   elseif self.owner.type == st.types.Quest then
      local text
      if st.cfg.useDifficultyColor then
	 local c = GetQuestDifficultyColor(self.owner.level)
	 text = "|cff%02x%02x%02x%s|r"
	 text = text:format(c.r*255,c.g*255,c.b*255,self.owner.titleText)
      else
	 text = self.owner.titleText
      end
      self.text:SetText(text)
      self.text:Show()
   elseif self.owner.type == st.types.Objective then
      local titleText,counterText
      if st.cfg.useProgressColor then
	 local cString = "|cff" .. Prism:Gradient(HSVorRGB, st.cfg.progressColorMin.r, st.cfg.progressColorMax.r, st.cfg.progressColorMin.g, st.cfg.progressColorMax.g, st.cfg.progressColorMin.b, st.cfg.progressColorMax.b, (self.owner.progress or 1))
	 titleText = cString .. self.owner.titleText .. "|r"
	 if not self.owner.counterText or self.owner.counterText == "" then counterText = ""
	 else counterText = cString .. self.owner.counterText .. "|r" end
      else
	 titleText = self.owner.titleText
	 counterText = self.owner.counterText and self.owner.counterText or ""
      end
      self.text:SetText(titleText)
      self.counter:SetText(counterText)
      if counterText == "" then self.counter:Hide() else self.counter:Show() end
   elseif self == st.gui.title then
      print("Reminder to fix guiFunc:UpdateText() to set questlog count.")
   else
      print("Unknown type for " .. (self.GetName and self:GetName() or tostring(self)) .. ": " .. tostring(self.owner.type))
   end

   if th ~= self.text:GetStringHeight() or tw ~= self.text:GetStringWidth() or ch ~= self.counter:GetStringHeight() or tw ~= self.counter:GetStringWidth() then
      self:UpdateSize(true)
   end

   if recurse then
      for k,v in ipairs(self.children) do v:UpdateText(true) end
   end
end
