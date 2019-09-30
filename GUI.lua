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
   gui.container = gui.scrollChild -- Hack to support new relational structure. Will make this the only reference after going through the code to make sure nothing else references it.
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
   gui.children = {}

   function gui:UpdateSize()
      local h = gui.title:GetHeight() + (gui.title.container:IsShown() and gui.title.container:GetHeight() or 0)
      gui.scrollChild:SetHeight(h)

      gui:SetHeight((h + st.cfg.padding*2) > st.cfg.maxHeight and st.cfg.maxHeight or (h + st.cfg.padding*2))

--      print("GetVerticalScroll(): " .. tostring(gui.scrollFrame:GetVerticalScroll()) .. "; GetVerticalScrollRange(): " .. tostring(gui.scrollFrame:GetVerticalScrollRange())) -- So I've concluded it's definitely called too often. But it doesn't seem to do what it should when it should.
      -- Ok. It's called too frequently, but.. it would appear that it for some reason ends up being called BEFORE something is removed. Definitely not sure why this would be.
      if gui.scrollFrame:GetVerticalScroll() > gui.scrollFrame:GetVerticalScrollRange() then gui.scrollFrame:SetVerticalScroll(gui.scrollFrame:GetVerticalScrollRange()) end
   end


   gui.title = guiFunc.New(gui, st.types.Title)
   gui.title:SetPoint("TOPLEFT", gui.scrollChild, "TOPLEFT")
   gui.title:SetPoint("TOPRIGHT", gui.scrollChild, "TOPRIGHT")
   gui:Redraw(false)
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

   gui:UpdateSize()

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

function guiFunc:GetWidth(textWidth, counterWidth)
   textWidth = (self.text:GetStringWidth() > textWidth) and self.text:GetStringWidth() or textWidth
   counterWidth = (self.counter:GetStringWidth() > counterWidth) and self.counter:GetStringWidth() or counterWidth

   for k,v in ipairs(self.children) do
      local childTextWidth,childCounterWidth = v:GetWidth(textWidth, counterWidth)
      textWidth = (childTextWidth > textWidth) and childTextWidth or textWidth
      counterWidth = (childCounterWidth > counterWidth) and childCounterWidth or counterWidth
   end

   return textWidth, counterWidth
end

function guiFunc:Release(recursed)
   local parent = self:Parent()
   while #self.children > 0 do
      self.children[1]:SetPoint("TOPLEFT", nil)
      self.children[1]:Release(true)
   end

   local found

   for k,v in ipairs(parent.children) do -- This sometimes fails. Figure out why. (Parent should never be nil.)
      if self == v then tinsert(recycler, tremove(parent.children, k));found = true end
   end

   if not found then print("Could not find what we're trying to release..");print(self:Parent().text:GetText() .. "/" .. self.text:GetText()) end

   self.owner.uiObject = nil
   self.owner = nil
   self.text:SetText("")
   self.counter:SetText("")
--   self.button.isClickButton = nil
   self.button:Hide()
   self.container:Show()
   self:SetParent(nil)
   self.button:SetScript("OnClick", nil)

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

function guiFunc:New(owner)
   if not self.container then error(self:GetName() .. " missing container") end
   if #recycler > 0 then
      object = tremove(recycler)
      object.container:Show()
      object:SetParent(self.container)
   else
      object = CreateFrame("Frame", getAvailableName("AQTRow"), self.container)
      object.button = CreateFrame("Button", getAvailableName("AQTButton"), object)
      object.button:SetPoint("TOPLEFT", object)
      object.button:SetSize(12,12) -- Might want to use font size, which means this shouldn't be here.
      object.text = object:CreateFontString(getAvailableName("AQTText"), object)
      object.text:SetFontObject(gui.font)
      object.text:SetJustifyH("LEFT")
      object.text:SetPoint("TOPLEFT", object.button, "TOPRIGHT", -10)
      object.text:SetWordWrap(st.cfg.font.wrap)
      object.counter = object:CreateFontString(getAvailableName("AQTCounter"), object)
      object.counter:SetFontObject(gui.font)
      object.counter:SetJustifyH("RIGHT")
      object.counter:SetPoint("TOPRIGHT", object)
      object.counter:SetWordWrap(st.cfg.font.wrap)
      object.text:SetPoint("TOPRIGHT", object.counter, "TOPLEFT", -10)
      object.container = CreateFrame("Frame", getAvailableName("AQTContainer"), object)
      object.container:SetPoint("TOPLEFT", object, "BOTTOMLEFT")
      object.container:SetPoint("TOPRIGHT", object, "BOTTOMRIGHT")
      object.children = {}
      setmetatable(object, mt)
   end
--   object:ButtonCheck()
   tinsert(self.children, object)
   object.owner = owner
   if self ~= gui then self:Update() end
   return object
end

function guiFunc:Update()
   self:Sort()
   if self:Parent().Sort then self:Parent():Sort() end
   self:ButtonCheck()
   self:UpdateText()
end

local function clickButton(self, button, down)
   if button == "LeftButton" then -- Right now this is the only button registered for clicks, but in case we want to add more later.
      if self:GetParent().container:IsShown() then
	 self:GetParent().container:Hide()
      else
	 self:GetParent().container:Show()
      end

      self:GetParent():ButtonCheck()
      self:GetParent():UpdateSize(true)
   end
end

function guiFunc:ButtonCheck() -- May want to rewrite this later and simply use a texture for the unclickable ones. Unless I can figure out a way to disable mouse interaction completely for buttons.
   if self == gui.title or self.owner.type == st.types.Header then
      if #self.children > 0 then
	 if self.container:IsShown() then
	    self.button:SetNormalTexture([[Interface\BUTTONS\UI-MinusButton-Up]])
	    self.button:SetHighlightTexture([[Interface\BUTTONS\UI-PlusButton-Hilight]])
	    self.button:SetPushedTexture([[Interface\BUTTONS\UI-MinusButton-Down]])
	 else
	    self.button:SetNormalTexture([[Interface\BUTTONS\UI-PlusButton-Up]])
	    self.button:SetHighlightTexture([[Interface\BUTTONS\UI-PlusButton-Hilight]])
	    self.button:SetPushedTexture([[Interface\BUTTONS\UI-PlusButton-Down]])
	 end
	 self.button:Show()
	 self.button:SetScript("OnClick", clickButton)
      else
	 self.button:Hide()
	 self.button:SetScript("OnClick", nil)
      end
   elseif self.owner.type == st.types.Quest then
      if self.owner.complete then
	 if self.owner.complete < 0 then
	    self.button:SetNormalTexture([[Interface\RAIDFRAME\ReadyCheck-NotReady]])
	    self.button:SetHighlightTexture(nil)
	    self.button:SetPushedTexture(nil)
	 elseif self.owner.complete > 0 then
	    self.button:SetNormalTexture([[Interface\RAIDFRAME\ReadyCheck-Ready]])
	    self.button:SetHighlightTexture(nil)
	    self.button:SetPushedTextured(nil)
	 end
	 self.button:Show()
      else
	 self.button:Hide()
      end
   end
end

function guiFunc:Parent()
   local parent = self:GetParent()
   if not self:GetParent() then return parent end
   parent = parent:GetParent()
   if parent == gui.scrollFrame then return parent:GetParent() else return parent end
--   return self:GetParent():GetParent()
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

   self.container:SetHeight(self.container:IsShown() and (h > 0 and h or .1) or .1) -- Need to make sure height is > 0 or it won't serve as an anchor.

   local th,ch = self.text:GetStringHeight(),self.counter:GetStringHeight()
   self:SetHeight(th > ch and th or ch)

   if recurse then self:Parent():UpdateSize(true) end -- gui will have its own function, so no need for a base case
end

function guiFunc:UpdateText(recurse)
   local th,tw,ch,tw = self.text:GetStringHeight(),self.text:GetStringWidth(),self.counter:GetStringHeight(),self.counter:GetStringWidth()
   local titleText,counterText

   if type(self.owner.TitleText) == "function" then
      titleText = self.owner:TitleText()
   else
      titleText = self.owner.TitleText
   end

   if type(self.owner.CounterText) == "function" then
      counterText = self.owner:CounterText()
   else
      counterText = self.owner.CounterText
   end

   self.text:SetText(titleText)
   self.counter:SetText(counterText)
   if counterText == "" then self.counter:Hide()
   else self.counter:Show() end

   if th ~= self.text:GetStringHeight() or tw ~= self.text:GetStringWidth() or ch ~= self.counter:GetStringHeight() or tw ~= self.counter:GetStringWidth() then
      self:UpdateSize(true)
   end

   if recurse then
      for k,v in ipairs(self.children) do v:UpdateText(true) end
   end
end
