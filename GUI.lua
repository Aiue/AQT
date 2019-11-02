local _,st = ...

local AQT = LibStub("AceAddon-3.0"):GetAddon("AQT")
local LSM = LibStub("LibSharedMedia-3.0")
local Prism = LibStub("LibPrism-1.0")

local difftime,time = difftime,time
local tinsert,tremove,tsort = table.insert,table.remove,table.sort

local animations = {
   faders = {},
}

local recycler = {
   buttons = {},
   icons = {},
   statusbars = {},
}
local active_timers = {}
local active_objects = {}
local L = st.L

local function getAvailableName(name) -- JUST removed this, because a recursive function was really stupid for this purpose. Still. Fonts need names, and I need recursion, so to hell with it.
   if not _G[name] then return name else
      local count = string.match(name, "%d+")
      if not count then count = 0 end
      count = count + 1
      return getAvailableName(string.sub(name, string.find(name, "%a+")) .. tostring(count))
   end
end

local gui = CreateFrame("Frame", getAvailableName("AQTParent"), UIParent)
st.gui = gui

local guiFunc = {}
setmetatable(guiFunc, getmetatable(UIParent))
local mt = {__index = function(t, k) return guiFunc[k] end}

function gui:OnEnable() -- Might want to attach this one elsewhere.
   gui:SetFrameStrata("BACKGROUND")
   gui.artwork = gui:CreateTexture(nil)
   gui.artwork:SetDrawLayer("artwork")
   gui.highlight = gui:CreateTexture(nil)
   gui.highlight:SetDrawLayer("artwork")
   gui.zoneHighlight = gui:CreateTexture(nil) -- Put this here instead of reusinc the recycler each time.
   gui.zoneHighlight:SetDrawLayer("artwork") -- May want another layer, but use this for now.
   gui.menu = L_Create_UIDropDownMenu(getAvailableName("AQTMenu"), gui)

   gui.font = CreateFont(getAvailableName("AQTFont"))
   gui.font:SetJustifyV("TOP")
   gui.barFont = CreateFont(getAvailableName("AQTBarFont"))
   gui.barFont:SetJustifyV("CENTER")
   gui.barFont:SetJustifyH("CENTER")

   gui.scrollFrame = CreateFrame("ScrollFrame", nil, gui)
   gui.scrollChild = CreateFrame("Frame", nil, gui.scrollFrame)
   gui.container = gui.scrollChild -- Hack to support new relational structure. Will make this the only reference after going through the code to make sure nothing else references it.
   gui.scrollFrame:SetScrollChild(gui.scrollChild)
   gui.scrollFrame:SetScript("OnSizeChanged", function(s, width, height)
				s:GetScrollChild():SetWidth(width)
   end)
   gui.scrollFrame:EnableMouseWheel(st.cfg.mouse.scrollEnabled)
   gui.scrollFrame:SetScript("OnMOuseWheel", function(s, delta)
				local pos = s:GetVerticalScroll()
				local setpos
				if pos-(delta*st.cfg.mouse.scrollSpeed) < 0 then setpos = 0
				elseif pos-(delta*st.cfg.mouse.scrollSpeed) > s:GetVerticalScrollRange() then setpos = s:GetVerticalScrollRange()
				else setpos = pos-(delta*st.cfg.mouse.scrollSpeed) end
				s:SetVerticalScroll(setpos)
   end)
   gui.children = {}

   local function updateScroll() if gui.scrollFrame:GetVerticalScroll() > gui.scrollFrame:GetVerticalScrollRange() then gui.scrollFrame:SetVerticalScroll(gui.scrollFrame:GetVerticalScrollRange()) end end

   function gui.UpdateSize(s, doChildren)
      local width = s.title:CheckWidth()
      if width < st.cfg.minWidth then s:SetWidth(st.cfg.minWidth)
      elseif width > st.cfg.maxWidth then s:SetWidth(st.cfg.maxWidth)
      else s:SetWidth(width) end
      if doChildren then s.title:UpdateSize(false) end

      local h = gui.title:GetHeight() + (gui.title.container:IsShown() and gui.title.container:GetHeight() or 0)
      gui.scrollChild:SetHeight(h)

      gui:SetHeight((h + st.cfg.padding*2) > st.cfg.maxHeight and st.cfg.maxHeight or (h + st.cfg.padding*2))

      C_Timer.After(.05, updateScroll)
   end

   gui.title = guiFunc.New(gui, st.types.Title)
   gui.title:SetPoint("TOPLEFT", gui.scrollChild, "TOPLEFT")
   gui.title:SetPoint("TOPRIGHT", gui.scrollChild, "TOPRIGHT")
   gui.title.optionsButton = CreateFrame("Button", nil, gui.title)
   gui.title.optionsButton:SetNormalTexture([[Interface\GossipFrame\HealerGossipIcon]])
   gui.title.optionsButton:SetHighlightTexture([[Interface\Buttons\UI-CheckBox-Highlight]])
   gui.title.optionsButton:SetPoint("TOPRIGHT", gui.title.counter, "TOPLEFT")
   gui.title.optionsButton:SetSize(st.cfg.font.size, st.cfg.font.size)
   gui.title.text:SetPoint("TOPRIGHT", gui.title.optionsButton, "TOPLEFT") -- Not really needed, but do it anyway. Because reaons.
   gui.title.optionsButton:SetScript("OnClick", function(s, button, down)
					if button == "LeftButton" then AQT:ToggleConfig() end
   end)
   gui:UpdateConfigButton()
   gui:Redraw(false)
   gui.title:Update()
   gui:ToggleLock()
   gui:UpdateScripts()

--[[
   -- If tracker is off screen, bring it to the middle.
   local resolution = select(GetCurrentResolution(), GetScreenResolutions())
   local match = "^(%d+)x(%d+)$"
   local x,y = resolution:match(match)
   x = tonumber(x)
   y = tonumber(y)

   if gui:GetBottom() < -gui:GetHeight() or gui:GetBottom() > y or gui:GetLeft() < -gui:GetWidth() or gui:GetLeft() > x then
      st.cfg.anchorFrom = "RIGHT"
      st.cfg.anchorTo = "RIGHT"
      st.cfg.posX = 0
      st.cfg.posY = 0
      gui:Redraw()
   end
]]--
end

function gui:RecurseResort()
   st.gui.title:RecurseResort()
end

function gui:Redraw(recurse) -- So, I'm looking this over, and I see it has an argument for recursing.. yet it's never used. Damn, that's silly of me.
   gui:ClearAllPoints()
   gui:SetPoint(st.cfg.anchorFrom, UIParent, st.cfg.anchorTo, st.cfg.posX, st.cfg.posY)

   gui.font:SetFont(LSM:Fetch("font", st.cfg.font.name), st.cfg.font.size, st.cfg.font.outline)
   gui.font:SetSpacing(st.cfg.font.spacing)

   gui.barFont:SetFont(LSM:Fetch("font", st.cfg.barFont.name), st.cfg.barFont.size, st.cfg.barFont.outline)

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

   gui:UpdateSize(true)

   gui:RedrawColor(false)
   gui:SetAlpha(st.cfg.alpha)

   local c = st.cfg.highlightCurrentZoneBackgroundColor
   gui.zoneHighlight:SetColorTexture(c.r, c.g, c.b, c.a)
   if not st.cfg.zoneHighlightCurrentZoneBackground then
      gui.zoneHighlight:ClearAllPoints()
      gui.zoneHighlight:Hide()
   end

   if not st.cfg.artwork.texture and st.cfg.artwork.LSMTexture == "None" then
      gui.artwork:Hide()
   else
      if st.cfg.artwork.useLSMtexture then
	 gui.artwork:SetTexture(LSM:Fetch("background", st.cfg.artwork.LSMTexture))
      else
	 gui.artwork:SetTexture(st.cfg.artwork.texture)
      end

      gui.artwork:SetVertexColor(st.cfg.artwork.vertexColor.r, st.cfg.artwork.vertexColor.g, st.cfg.artwork.vertexColor.b, st.cfg.artwork.vertexColor.a)

      gui.artwork:ClearAllPoints()

      if st.cfg.artwork.stretching == 4 then
	 -- Would be nice to be able to simply use SetAllPoints() here, but we need to account for offset. So instead, set TOPLEFT and BOTTOMRIGHT, and invert offset for BOTTOMRIGHT.
	 gui.artwork:SetPoint("TOPLEFT", gui, "TOPLEFT", st.cfg.artwork.offsetX, -st.cfg.artwork.offsetY)
	 gui.artwork:SetPoint("BOTTOMRIGHT", gui, "BOTTOMRIGHT", -st.cfg.artwork.offsetX, st.cfg.artwork.offsetY)
      elseif st.cfg.artwork.stretching == 3 then
	 local l,r = "LEFT", "RIGHT"
	 if st.cfg.artwork.anchor ~= "CENTER" then
	    l = st.cfg.artwork.anchor .. l
	    r = st.cfg.artwork.anchor .. r
	 end

	 gui.artwork:SetPoint(l, gui, l, st.cfg.artwork.offsetX, -st.cfg.artwork.offsetY)
	 gui.artwork:SetPoint(r, gui, r, -st.cfg.artwork.offsetX, st.cfg.artwork.offsetY)
      elseif st.cfg.artwork.stretching == 2 then
	 local b,t = "BOTTOM", "TOP"
	 if st.cfg.artwork.anchor ~= "CENTER" then
	    b = b .. st.cfg.artwork.anchor
	    t = t .. st.cfg.artwork.anchor
	 end

	 gui.artwork:SetPoint(b, gui, b, st.cfg.artwork.offsetX, -st.cfg.artwork.offsetY)
	 gui.artwork:SetPoint(t, gui, t, -st.cfg.artwork.offsetX, st.cfg.artwork.offsetY)
      else
	 gui.artwork:SetPoint(st.cfg.artwork.anchor, gui, st.cfg.artwork.anchor, st.cfg.artwork.offsetX, st.cfg.artwork.offsetY) -- This should be enough.
      end

      if st.cfg.artwork.height then gui.artwork:SetHeight(st.cfg.artwork.height) end
      if st.cfg.artwork.width then gui.artwork:SetWidth(st.cfg.artwork.width) end
      if st.cfg.artwork.scale then gui.artwork:SetScale(st.cfg.artwork.scale) end

      if st.cfg.artwork.zoom then
	 local l,r,t,b
	 if st.cfg.artwork.symmetricZoom then
	    local zoom = st.cfg.artwork.symmetric/2
	    l = zoom
	    r = 1-zoom
	    t = zoom
	    b = 1-zoom
	 else
	    l = st.cfg.artwork.left
	    r = st.cfg.artwork.right
	    t = st.cfg.artwork.top
	    b = st.cfg.artwork.bottom
	 end

	 gui.artwork:SetTexCoord(l,r,t,b)
      else
	 gui.artwork:SetTexCoord(0,1,0,1)
      end
      gui.artwork:Show()
   end
end

function gui:RedrawColor()
   gui.font:SetTextColor(st.cfg.font.r, st.cfg.font.g, st.cfg.font.b, st.cfg.font.a)
   gui.barFont:SetTextColor(st.cfg.barFont.r, st.cfg.barFont.g, st.cfg.barFont.b, st.cfg.barFont.a)
   gui:SetBackdropColor(st.cfg.backdrop.background.r, st.cfg.backdrop.background.g, st.cfg.backdrop.background.b, st.cfg.backdrop.background.a)
   gui:SetBackdropBorderColor(st.cfg.backdrop.border.r, st.cfg.backdrop.border.g, st.cfg.backdrop.border.b, st.cfg.backdrop.border.a)
   for _,v in ipairs(active_timers) do v:GetParent():UpdateTimer() end
end

function gui:ToggleLock()
   if st.cfg.unlocked then
      self:EnableMouse(true)
      self:SetMovable(true)
      self:RegisterForDrag("LeftButton")
      self:SetScript("OnDragStart", function(s, button)
			if button == "LeftButton" then s:StartMoving() end
      end)
      self:SetScript("OnDragStop", function(s)
			self:StopMovingOrSizing()
--			local _,_,_,x,y = self:GetPoint(1) -- We should only have one point set.
			local resX,resY = UIParent:GetSize()
			local offsetX,offsetY

			if st.cfg.anchorFrom:match("LEFT$") then
			   offsetX = s:GetLeft()
			elseif st.cfg.anchorFrom:match("RIGHT$") then
			   offsetX = s:GetRight()
			else
			   offsetX = (s:GetLeft()+s:GetRight())/2
			end

			if st.cfg.anchorFrom:match("^TOP") then
			   offsetY = s:GetTop()
			elseif st.cfg.anchorFrom:match("^BOTTOM") then
			   offsetY = s:GetBottom()
			else
			   offsetY = (s:GetBottom()+s:GetTop())/2
			end

			if st.cfg.anchorTo:match("RIGHT$") then
			   offsetX = offsetX - resX
			elseif not st.cfg.anchorTo("LEFT$") then
			   offsetX = offsetX - (resX/2)
			end

			if st.cfg.anchorTo:match("^TOP") then
			   offsetY = offsetY - resY
			elseif not st.cfg.anchorTo:match("^BOTTOM") then
			   offsetY = offsetY - (resY/2)
			end

			st.cfg.posX = offsetX
			st.cfg.posY = offsetY
			s:SetPoint(st.cfg.anchorFrom, UIParent, st.cfg.anchorTo, st.cfg.posX, st.cfg.posY)
      end)
   else
      self:EnableMouse(false)
      self:SetMovable(false)
      self:SetScript("OnDragStart", nil)
      self:SetScript("OnDragStop", nil)
   end
end

function guiFunc:CheckWidth(width, level)
   width = width or 0
   if not level then level = 1 end
   -- May want to use GetTextWidth()
   local w = 20 + st.cfg.font.size + (st.cfg.indent*level) + (st.cfg.padding*2) + self.text:GetStringWidth() + self.counter:GetStringWidth()
   if w > width then width = w end
   if self.container:IsShown() then
      for _,v in ipairs(self.children) do
	 width = v:CheckWidth(width, level + 1)
      end
   end
   return width
end

function guiFunc:SetZoneHighlight()
   if st.cfg.highlightCurrentZoneBackground then
      gui.zoneHighlight:SetAllPoints(self)
      gui.zoneHighlight:Show()
   end
end

function guiFunc:Orphan()
   local parent = self:Parent()

   for k,v in ipairs(parent.children) do
      if self == v then
	 tremove(parent.children, k)
      end
   end

   self:SetParent(nil)
   self:ClearAllPoints()
end

function guiFunc:GetAdopted(parent)
   tinsert(parent.children, self)
   self:SetParent(parent.container)
end

function gui:UpdateConfigButton()
   if st.cfg.hideConfigButton then self.title.optionsButton:Hide() else self.title.optionsButton:Show() end
end

function guiFunc:RecurseResort()
   if #self.children > 0 then
      for _,v in ipairs(self.children) do
	 v:RecurseResort()
      end
      self:Sort()
   end
end

function guiFunc:Fade(fromAlpha, toAlpha, delay, target, onFinish)
   target = target or self
   target:StopAnimating()
   local fader
   for _,v in ipairs(animations.faders) do
      if not v:IsPlaying() then
	 fader = v
	 break
      end
   end

   if not fader then
      fader = gui:CreateAnimationGroup()
      fader.alpha = fader:CreateAnimation("Alpha")
      fader.alpha:SetOrder(1)
      fader.alpha:SetDuration(.5)
      tinsert(animations.faders, fader)
   end

   if fromAlpha > toAlpha then fader.alpha:SetSmoothing("OUT") else fader.alpha:SetSmoothing("IN") end

   fader.alpha:SetFromAlpha(fromAlpha)
   fader.alpha:SetToAlpha(toAlpha)
   fader.alpha:SetStartDelay(delay)
   fader.alpha:SetTarget(target or self)
   fader:SetScript("OnFinished", onFinish)
   fader:Play()
end

function guiFunc:Release(noFade)
   if self.releasing then return
   elseif noFade or st.cfg.disableAnimations then
      self:DelayedRelease()
      return
   end
   self.releasing = true

   local release = function(fader, requested)
      if not requested then self:DelayedRelease() end
   end

   self:Fade(1, 0, 0, self, release)
end

function guiFunc:DelayedRelease(recursed)
   local parent = self:Parent()

   self.releasing = nil

   while #self.children > 0 do
      self.children[1]:ClearAllPoints()
      self.children[1]:DelayedRelease(true)
   end

   local found

   for k,v in ipairs(parent.children) do
      if self == v then tinsert(recycler, tremove(parent.children, k));found = true end
   end

   local _,rel = gui.zoneHighlight:GetPoint(1)
   if rel == self then
      gui.zoneHighlight:ClearAllPoints()
      gui.zoneHighlight:Hide()
   end

   if not found then print("Could not find what we're trying to release..");print(self:Parent().text:GetText() .. "/" .. self.text:GetText()) end

   self.manual = nil
   self.owner.uiObject = nil
   self.owner = nil
   self.text:SetText("")
   self.counter:SetText("")

   for k in pairs(self.scripts) do self:SetScript(k) end

   for k,v in ipairs(active_objects) do
      if self == v then
	 tremove(active_objects, k)
	 break
      end
   end

   self:ReleaseButton()
   self:ReleaseIcon()
   self:ReleaseTimer()

   self.container:Show()
   self:SetParent(nil)
   self:StopAnimating()
   self.container:StopAnimating()
   self:SetAlpha(1)
   self:Hide()

   if parent == st.gui.title and #parent.children == 0 then AQTParent:Hide() end

   if not recursed then
      parent:RelinkChildren()
      parent:UpdateSize(true)
   end
end

function guiFunc:SetScript(script, func)
   self:RawSetScript(script, func)
   self.scripts[script] = func
end

guiFunc.RawSetScript = getmetatable(UIParent).__index.SetScript -- Hacky, but gets the job done.

function guiFunc:ReleaseButton()
   if self.button then
      self.button:ClearAllPoints()
      self.button:SetParent(nil)
      self.button:Hide()
      tinsert(recycler.buttons, self.button)
      self.button = nil
   end
end

function guiFunc:ReleaseIcon()
   if self.icon then
      self.icon:ClearAllPoints()
      self.icon:SetParent(UIParent)
      self.icon:Hide()
      tinsert(recycler.icons, self.icon)
      self.icon = nil
   end
end

function guiFunc:UnlinkChildren()
   if self.timer and self.timer.sb then self.timer:ClearAllPoints() end
   for _,v in ipairs(self.children) do v:ClearAllPoints() end
end

function guiFunc:RelinkChildren(recurse)
   self:UnlinkChildren() -- While we shouldn't get any circular links, play it safe and unlink everything first
   if self.timer and self.timer.sb then
      self.timer:SetPoint("TOPLEFT", self.container, "TOPLEFT", st.cfg.indent+st.cfg.font.size, -st.cfg.font.spacing)
      self.timer:SetPoint("TOPRIGHT", self.container, "TOPRIGHT")
   end
   for k,v in ipairs(self.children) do
      if k == 1 then
	 if self.timer and self.timer.sb then
	    v:SetPoint("TOPLEFT", self.timer, "BOTTOMLEFT", -(st.cfg.indent+st.cfg.font.size), -st.cfg.font.spacing)
	    v:SetPoint("TOPRIGHT", self.timer, "BOTTOMRIGHT")
	 else
	    v:SetPoint("TOPLEFT", self.container, "TOPLEFT", st.cfg.indent, -st.cfg.font.spacing)
	    v:SetPoint("TOPRIGHT", self.container, "TOPRIGHT")
	 end
      else
	 v:SetPoint("TOPLEFT", self.children[k-1].container, "BOTTOMLEFT", 0, -st.cfg.font.spacing)
	 v:SetPoint("TOPRIGHT", self.children[k-1].container, "BOTTOMRIGHT", 0, -st.cfg.font.spacing)
      end

      if recurse then v:RelinkChildren(true) end
   end
end

function guiFunc:OnEnter(mouseMoved)
   local r,g,b = self.text:GetTextColor()
   if st.cfg.highlightMouseText then self.text:SetText(Prism:AlterStringColor(self.text:GetText(), r, g, b, st.cfg.highlightMouseText, st.cfg.highlightMouseTextModifier, st.cfg.highlightMouseTextOperation)) end
   if st.cfg.highlightMouseBG then
      gui.highlight:SetAllPoints(self)
      gui.highlight:SetColorTexture(st.cfg.highlightMouseBGColor.r, st.cfg.highlightMouseBGColor.g, st.cfg.highlightMouseBGColor.b, st.cfg.highlightMouseBGColor.a)
      gui.highlight:Show()
   end
end

function guiFunc:OnLeave(mouseMoved)
   self:UpdateText()
   gui.highlight:ClearAllPoints()
   gui.highlight:Hide()
end

function guiFunc:New(owner, noFade)
   local object
   if not self.container then error(self:GetName() .. " missing container") end
   if #recycler > 0 then
      object = tremove(recycler)
      object.container:Show()
      object:SetParent(self.container)
   else
      object = CreateFrame("Frame", nil, self.container)
      object.text = object:CreateFontString(nil)
      object.text:SetFontObject(gui.font)
      object.text:SetJustifyH("LEFT")
      object.text:SetPoint("TOPLEFT", object, "TOPLEFT", st.cfg.font.size, 0)
      object.counter = object:CreateFontString(nil)
      object.counter:SetFontObject(gui.font)
      object.counter:SetJustifyH("RIGHT")
      object.counter:SetPoint("TOPRIGHT", object)
      object.text:SetPoint("RIGHT", object.counter, "LEFT", -10, 0)
      -- Create a container. May want to have these ones also be on-demand. It's a whole lot easier keeping it as is, though.
      object.container = CreateFrame("Frame", nil, object)
      object.container:SetPoint("TOPLEFT", object, "BOTTOMLEFT")
      object.container:SetPoint("TOPRIGHT", object, "BOTTOMRIGHT")
      object.children = {}
      object.scripts = {}

      object:SetScript("OnEnter", guiFunc.OnEnter)
      object:SetScript("OnLeave", guiFunc.OnLeave)

      setmetatable(object, mt)
   end
   tinsert(self.children, object)
   object.owner = owner
   object.owner.uiObject = object
   object.container:SetAlpha(1)
   object:UpdateScripts()
   object:Show()
   if self == st.gui.title then AQTParent:Show() end
   tinsert(active_objects, object)
   if self ~= gui then self:Update() end
   if not(noFade or st.cfg.disableAnimations) then object:Fade(0, 1, 0, object) end
   --object:Fade(0, 1, 0)
   return object
end

function guiFunc:CollapseHeader(manual)
   if not self.container then error("Missing container.")
   elseif self:IsCollapsed() then return
   elseif self.manual and not manual then return end

   if self.manual ~= nil then self.manual = manual end

   if st.cfg.disableAnimations then
      self.container:Hide()
      self:UpdateSize(true)
   else
      self.hiding = true
      self:Fade(1, 0, 0, self.container, function(fader, requested)
		   local target = fader.alpha:GetTarget()

		   target:Hide()
		   target = target:GetParent()
		   target.hiding = nil
		   target:UpdateSize(true)
      end)
   end
end

function guiFunc:ExpandHeader(manual)
   if not self.container then error("Missing container.")
   elseif not self:IsCollapsed() then return
   elseif self.manual and not manual then return end

   if manual ~= nil then self.manual = manual end

   self.hiding = nil

   self.container:Show()
   self:UpdateSize(true)
   if not st.cfg.disableAnimations then self:Fade(0, 1, 0, self.container, nil)
   else self.container:SetAlpha(1) end
end

function guiFunc:ToggleCollapsed(manual)
   if not self.container then error("Missing container.")
   elseif self:IsCollapsed() then self:ExpandHeader(manual)
   else self:CollapseHeader(manual) end
   self:ButtonCheck()
end

function guiFunc:IsCollapsed() return self.container and not self.container:IsShown() or self.hiding end -- Yes, I could just as well just check for this, but I want to create more abstraction. I'm breaking it enough as it is already.

local function clickButton(self, button, down)
   if button == "LeftButton" then self:GetParent():ToggleCollapsed(true) end -- Right now this is the only button registered for clicks, but in case we want to add more later.
end

function guiFunc:NewButton()
   local button
   if #recycler.buttons > 0 then
      button = tremove(recycler.buttons)
   else
      button = CreateFrame("Button", nil, self)
      button:SetScript("OnClick", clickButton)
   end

   self.button = button
   self.button:Show()
   self.button:SetSize(st.cfg.font.size, st.cfg.font.size)
   self.button:SetPoint("TOPLEFT", self)
   self.button:SetParent(self)
end

function guiFunc:NewIcon()
   local icon
   if #recycler.icons > 0 then
      icon = tremove(recycler.icons)
   else
      icon = self:CreateTexture(nil)
   end

   self.icon = icon
   self.icon:SetSize(st.cfg.font.size, st.cfg.font.size)
   self.icon:SetPoint("TOPLEFT", self)
   self.icon:SetParent(self)
   self.icon:Show()
end

function guiFunc:Update()
   self:Sort()
   if self:Parent().Sort then self:Parent():Sort() end
   self:ButtonCheck()
   self:UpdateText()
end

function guiFunc:ButtonCheck(recurse) -- May want to rewrite this later and simply use a texture for the unclickable ones. Unless I can figure out a way to disable mouse interaction completely for buttons.
   if self == gui.title or self.owner.type == st.types.Header then
      if #self.children > 0 and (st.cfg.showHeaderButton or self == gui.title) then
	 if not self.button then self:NewButton() end
	 if self.container:IsShown() and not self.hiding then
	    self.button:SetNormalTexture([[Interface\Buttons\UI-MinusButton-Up]])
	    self.button:SetHighlightTexture([[Interface\Buttons\UI-PlusButton-Hilight]])
	    self.button:SetPushedTexture([[Interface\Buttons\UI-MinusButton-Down]])
	 else
	    self.button:SetNormalTexture([[Interface\Buttons\UI-PlusButton-Up]])
	    self.button:SetHighlightTexture([[Interface\Buttons\UI-PlusButton-Hilight]])
	    self.button:SetPushedTexture([[Interface\Buttons\UI-PlusButton-Down]])
	 end
      else
	 self:ReleaseButton()
      end
   elseif self.owner.type == st.types.Quest then
      if self.owner.complete then
	 if not self.icon then self:NewIcon() end
	 if self.owner.complete < 0 then
	    self.icon:SetTexture([[Interface\RAIDFRAME\ReadyCheck-NotReady]])
	 elseif self.owner.complete > 0 then
	    self.icon:SetTexture([[Interface\RAIDFRAME\ReadyCheck-Ready]])
	 end
      else
	 self:ReleaseIcon()
      end
   end

   if recurse then for _,v in ipairs(self.children) do v:ButtonCheck(true) end end
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
	    if not a then
	       local text
	       if type(self.owner.TitleText) == "function" then
		  text = self.owner:TitleText()
	       else
		  text = self.owner.TitleText
	       end

	       print(text .. ": " .. L["nil entry when trying to sort, please report to Aiue."])
	       return false
	    end
	    if not b then
	       local text
	       if type(self.owner.TitleText) == "function" then
		  text = self.owner:TitleText()
	       else
		  text = self.owner.TitleText
	       end

	       print(text .. ": " .. L["nil entry when trying to sort, please report to Aiue."])
	       return true
	    end
	    if not a.owner or not b.owner then return false
	    elseif a.owner.type ~= b.owner.type then return tostring(a.owner.type) > tostring(b.owner.type)
	    elseif not st.cfg.sortFields[tostring(a.owner.type)] then -- b sortFields should be the same in this case
	       return false
	    else
	       for _,v in ipairs(st.cfg.sortFields[tostring(a.owner.type)]) do
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
		  elseif type(a.owner[v.field]) == "function" then -- If we're on this else, then a.owner[v.field] == b.owner[v.field]
		     if a.owner[v.field](a.owner) then return true
		     elseif b.owner[v.field](b.owner) then return false end
		  end
	       end
	    end
	    return false -- some kind of default, just in case, shouldn't realistically ever get here, though
   end)
   self:RelinkChildren()
end

function guiFunc:UpdateSize(recurse) --!!!RE!!! Should use OnSizeChanged() for some of these things. Particularly useful for fontstrings. Which can't set that script, so uh. Still. Get back to this. Could solve some of my other issues. And FontStrings I can handle in UpdateText().
   -- Yes, definitely need to rewrite all of this. I mean, it MOSTLY works. But.. not as well as I'd like. I kind of need an onsizechanged scripts alongside a "manual" updater.
   if recurse == false then
      for _,v in ipairs(self.children) do v:UpdateSize(false) end
   end

   local h = 0

   for _,v in ipairs(self.children) do
--      local th,ch = v.text:GetHeight(),v.counter:GetHeight()
--      h = h + (th > ch and th or ch) + (v.container:IsShown() and v.container:GetHeight() or 0)
      h = h + v:GetHeight() + (v.container:IsShown() and v.container:GetHeight() or 0)
   end

   h = h + st.cfg.font.spacing*(#self.children)

   if self.timer and self.timer.sb then
      self.timer:SetHeight(st.cfg.barFont.size*1.5) -- probably good?
      h = h + self.timer:GetHeight()
   end

   if self.button then self.button:SetSize(st.cfg.font.size, st.cfg.font.size) end
   if self.icon then self.icon:SetSize(st.cfg.font.size, st.cfg.font.size) end

   self.container:SetHeight(self.container:IsShown() and (h > 0 and h or .1) or .1) -- Need to make sure height is > 0 or it won't serve as an anchor.

   local th,ch = self.text:GetStringHeight(),self.counter:GetStringHeight()
   self:SetHeight(th > ch and th or ch)

   if recurse then self:Parent():UpdateSize(true) end -- gui will have its own function, so no need for a base case
end

function guiFunc:UpdateText(recurse)
   local th,tw,ch,cw = self.text:GetStringHeight(),self.text:GetStringWidth(),self.counter:GetStringHeight(),self.counter:GetStringWidth()
   local titleText,counterText

   self.text:SetWordWrap(st.cfg.font.wrap)
   self.text:SetNonSpaceWrap(st.cfg.font.wrap)
   self.counter:SetWordWrap(st.cfg.font.wrap)
   self.counter:SetNonSpaceWrap(st.cfg.font.wrap)

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

   if th ~= self.text:GetStringHeight() or tw ~= self.text:GetStringWidth() or ch ~= self.counter:GetStringHeight() or cw ~= self.counter:GetStringWidth() then
      self:UpdateSize(true)
   end

   if recurse then
      for _,v in ipairs(self.children) do v:UpdateText(true) end
   end
end

-- Timer functions.
local function timer_OnUpdate(self)
   local owner = self:GetParent().owner
   if not owner then error("timer missing data") end

   local remains = owner.timer.expires - owner.timer.started
   local duration = time() - owner.timer.started
   local progress = 1-(duration/remains)

   local cstring,r,g,b = Prism:Gradient(st.cfg.useHSVGradient and "hsv" or "rgb", st.cfg.progressColorMin.r, st.cfg.progressColorMax.r, st.cfg.progressColorMin.g, st.cfg.progressColorMax.g, st.cfg.progressColorMin.b, st.cfg.progressColorMax.b, progress)

   local timeleft = difftime(owner.timer.expires, time()) -- remaining time in seconds
   local timestring = ""
   if timeleft >= 86400 then -- Days. Shouldn't happen, and would make formatting by splitting with : slightly weird, and dhms would make more sense, but eeh, since it probably won't happen, let's just stick with that anyway.
      timestring = tostring(math.floor(timeleft/86400))
      timeleft = timeleft%86400
   end
   local fmt = ":%02d"
   if timeleft >= 3600 or timestring ~= "" then -- Hours
      local hours = math.floor(timeleft/3600)
      timeleft = timeleft%3600
      if timestring == "" then timestring = tostring(hours)
      else timestring = timestring .. fmt:format(hours) end
   end
   if timeleft > 60 or timestring ~= "" then -- Minutes
      local minutes = math.floor(timeleft/60)
      timeleft = timeleft%60
      if timestring == "" then timestring = tostring(minutes)
      else timestring = timestring .. fmt:format(minutes) end
   end
   if timestring == "" then timestring = tostring(timeleft)
   else timestring = timestring .. fmt:format(timeleft) end

   return cstring, timestring, r, g, b, progress
end

local function timer_FontString_OnUpdate(self)
   local cstring,text = timer_OnUpdate(self.timer)
   self.timer:SetText("|cff" .. cstring .. text .. "|r")
end

local function timer_StatusBar_OnUpdate(self)
   local _,text,r,g,b,progress = timer_OnUpdate(self)
   self.sb:SetValue(progress) -- !!!RE!!! return to this, want it inverted
   self.sb:SetStatusBarColor(r, g, b)
   self.sb.text:SetText(text)
end

local function getTimerType()
   local timerType
   if st.cfg.timerType == 1 then timerType = "Frame"
   elseif st.cfg.timerType == 2 then timerType = "FontString"
   else error("Unknown timer type configuration.") end
   return timerType
end

function guiFunc:UpdateTimer()
   if (not st.cfg.showTimers or not self.owner.timer or self.owner.timer.expires < time()) and self.timer then self:ReleaseTimer()
   elseif st.cfg.showTimers and self.owner.timer and self.owner.timer.expires >= time() then
      local timerType = getTimerType()
      if self.timer and not self.timer:IsObjectType(timerType) then self:ReleaseTimer() end
      if not self.timer then self.timer = self:NewTimer() end
      if self.timer:IsObjectType("fontstring") then timer_FontString_OnUpdate(self)
      elseif self.timer:IsObjectType("frame") then
	 self.timer.sb:SetMinMaxValues(0,1)
	 self.timer.sb:SetStatusBarTexture(LSM:Fetch("statusbar", st.cfg.barTexture))
	 local backdrop = {
	    bgFile = LSM:Fetch("background", st.cfg.barBackdrop.background.name),
	    edgeFile = LSM:Fetch("border", st.cfg.barBackdrop.border.name),
	    tileSize = st.cfg.barBackdrop.tileSize,
	    edgeSize = st.cfg.barBackdrop.edgeSize,
	    tile = st.cfg.barBackdrop.tile,
	    insets = {
	       left = st.cfg.barBackdrop.insets,
	       right = st.cfg.barBackdrop.insets,
	       top = st.cfg.barBackdrop.insets,
	       bottom = st.cfg.barBackdrop.insets,
	    }
	 }
	 self.timer:SetBackdrop(backdrop)
	 self.timer:SetBackdropColor(st.cfg.barBackdrop.background.r, st.cfg.barBackdrop.background.g, st.cfg.barBackdrop.background.b, st.cfg.barBackdrop.background.a)
	 self.timer:SetBackdropBorderColor(st.cfg.barBackdrop.border.r, st.cfg.barBackdrop.border.g, st.cfg.barBackdrop.border.b, st.cfg.barBackdrop.border.a)

	 self:RelinkChildren()
	 self:UpdateSize(true)
	 timer_StatusBar_OnUpdate(self.timer)
      else error("Unknown object type for timer.") end
   end
end

function guiFunc:NewTimer()
   local timer
   local timerType = getTimerType()
   -- yes, this is silly, but I'll just tell myself I'll thank myself later in case I want to add more types later
   if timerType == "FontString" then
      timer = self.counter
      self:SetScript("OnUpdate", timer_FontString_OnUpdate)
   else
      if #recycler.statusbars > 0 then
	 timer = tremove(recycler.statusbars)
	 timer:SetParent(self)
      else
	 timer = CreateFrame("Frame", nil, self)
	 timer.sb = CreateFrame("StatusBar", nil, timer)
	 timer.sb:SetPoint("TOPLEFT", st.cfg.barBackdrop.insets+1, -(st.cfg.barBackdrop.insets+1))
	 timer.sb:SetPoint("BOTTOMRIGHT", -(st.cfg.barBackdrop.insets+1), st.cfg.barBackdrop.insets+1)
	 timer.sb.text = timer.sb:CreateFontString(nil, "OVERLAY")
	 timer.sb.text:SetFontObject(gui.barFont)
	 timer.sb.text:SetAllPoints(timer.sb)
      end
      timer:SetScript("OnUpdate", timer_StatusBar_OnUpdate)
   end
   timer:Show()
   tinsert(active_timers, timer)
   return timer
end

function guiFunc:ReleaseTimer()
   if not self.timer then return end
   if self.timer:IsObjectType("Frame") then
      self.timer:ClearAllPoints() -- potential for breakage if we have objectives linked to this, be mindful
      self.timer:SetParent(nil)
      self.timer:SetScript("OnUpdate", nil)
      tinsert(recycler.statusbars, self.timer)
   else
      self:SetScript("OnUpdate", nil)
   end
   self.timer:Hide()
   for k,v in ipairs(active_timers) do
      if v == self.timer then
	 tremove(active_timers, k)
	 break
      end
   end
   self.timer = nil
   self:RelinkChildren()
   self:UpdateSize(true)
end

function guiFunc:UpdateTimers()
   self:UpdateTimer()
   for _,v in ipairs(self.children) do v:UpdateTimers() end
end

function gui:UpdateTimers()
   for _,v in ipairs(self.children) do v:UpdateTimers() end
end

function gui:IterateObjects(oType)
   if not oType then return ipairs(active_objects)
   else
      local cache = {}
      for _,v in ipairs(active_objects) do
	 if v.owner.type == oType then
	    tinsert(cache, v)
	 end
      end
      return ipairs(cache)
   end
end

function gui:UpdateScripts()
--[[ This needs additional handling. Once we mouseover something clickable, it triggers the fadeout animation.
   if st.cfg.fade then
      self:SetScript("OnEnter", self.OnEnter)
      self:SetScript("OnLeave", self.OnLeave)
   else
      self:SetScript("OnEnter", nil)
      self:SetScript("OnLeave", nil)
   end
]]--

   for _,v in gui:IterateObjects() do v:UpdateScripts() end
end

local function onClick(self, button, down)
   local c = st.cfg.mouse[self.owner.type.name]
   local func

   if button == "LeftButton" and c.LeftButton then
      if IsAltKeyDown() and c.LeftButton.Alt then func = c.LeftButton.Alt
      elseif IsControlKeyDown() and c.LeftButton.Control then func = c.LeftButton.Control
      elseif IsShiftKeyDown() and c.LeftButton.Shift then func = c.LeftButton.Shift
      else func = c.LeftButton.func end
   elseif button == "RightButton" and c.RightButton then
      if IsAltKeyDown() and c.RightButton.Alt then func = c.RightButton.Alt
      elseif IsControlKeyDown() and c.RightButton.Control then func = c.RightButton.Control
      elseif IsShiftKeyDown() and c.RightButton.Shift then func = c.RightButton.Shift
      else func = c.RightButton.func end
   end

   if not func or not self.owner.clickScripts or (not self.owner.clickScripts[func] and func ~= "__menu__") then return end

   if func == "__menu__" then
      local menu = {}

      for k,v in pairs(self.owner.clickScripts) do
	 local entry = {
	    arg1 = k,
	    arg2 = self.owner,
	    text = v.desc,
	    notCheckable = true,
	 }

	 if v.disabled then
	    if type(v.disabled) == "function" then entry.disabled = v:disabled(self.owner)
	    elseif type(v.disabled) == "boolean" then entry.disabled = v.disabled
	    else error("Unknown type for 'disabled': " .. type(v.disabled)) end
	 end

	 if v.func then
	    entry.func = function(_, _, questObject)
	       if type(v.func) == "function" then v.func(questObject)
	       elseif type(v.func) == "string" and questObject[v.func] then questObject[v.func](questObject) end
	    end
	 else
	    entry.disabled = true
	 end

	 tinsert(menu, entry)
      end
      tsort(menu, function(a,b)
	       local ao,bo = a.arg2.clickScripts[a.arg1],b.arg2.clickScripts[b.arg1]
	       if ao.order then
		  if bo.order then return ao.order < bo.order
		  else return true end
	       elseif bo.order then return false
	       else return ao.desc < bo.desc end
      end)

      tinsert(menu, 1, {notCheckable = true, notClickable = true})

      if type(self.owner.TitleText) == "function" then
	 menu[1].text = self.owner:TitleText()
      else
	 menu[1].text = self.owner.TitleText
      end

      -- Add another blank line and a close button.
      tinsert(menu, {
		 text = "",
		 disabled = true,
      })

      tinsert(menu, {
		 text = L.Close,
		 func = function() L_CloseDropDownMenus() end,
		 notCheckable = true,
      })
      L_EasyMenu(menu, gui.menu, "cursor", 0, 0, "menu", 10)
      return
   end

   if self.owner.clickScripts[func].disabled and (type(self.owner.clickScripts[func].disabled) == "boolean" or (type(self.owner.clickScripts[func].disabled) == "function" and self.owner.clickScripts[func].disabled(self.owner))) then return end

   func = self.owner.clickScripts[func].func

   if type(func) == "function" then func(self.owner)
   elseif type(func) == "string" and self.owner[func] then self.owner[func](self.owner) end
end

function guiFunc:UpdateScripts()
   if st.cfg.mouse.enabled and st.cfg.mouse[self.owner.type.name] and st.cfg.mouse[self.owner.type.name].enabled then
      self:EnableMouse(true)
      self:SetScript("OnMouseDown", onClick)
   else
      self:EnableMouse(false)
      self:SetScript("OnMouseDown")
   end
end
