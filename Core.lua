local _,st = ...

local AQT = LibStub("AceAddon-3.0"):NewAddon("AQT", "AceEvent-3.0", "LibSink-2.0")
local LDB = LibStub("LibDataBroker-1.1")
local LSM = LibStub("LibSharedMedia-3.0")
local Prism = LibStub("LibPrism-1.0")

local L = st.L

LSM:Register("sound", "Peasant: Job's Done", [[Interface\AddOns\AQT\Sounds\Peasant_work_done.mp3]])
LSM:Register("sound", "Peasant: More Work?", [[Sound\Creature\Peasant\PeasantWhat3.ogg]])
LSM:Register("sound", "Peasant: Ready to Work", [[Sound\Creature\Peasant\PeasantReady1.ogg]])
LSM:Register("sound", "Peon: Ready to Work", [[Sound\Creature\Peon\PeonReady1.ogg]])
LSM:Register("sound", "Peon: Work Complete", [[Sound\Creature\Peon\PeonBuildingComplete1.ogg]])
LSM:Register("sound", "Peon: Work Work", [[Sound\Creature\Peon\PeonYes3.ogg]])

-- Takes up a tiny bit more memory, but even if we consider that we don't have compiler substitutions, it will improve readability. Like what, a few bytes of memory at the most. Use shared table so it can be used in other files as well.
st.SOUND_COMPLETE = 1
st.SOUND_OBJECTIVE_COMPLETE = 2
st.SOUND_OBJECTIVE_PROGRESS = 3

-- Some strings that are of interest to us.
local ERR_QUEST_OBJECTIVE_COMPLETE_S = ERR_QUEST_OBJECTIVE_COMPLETE_S:gsub("%%%d($)", "%%"):gsub("%%(s)", "(.+")
local ERR_QUEST_UNKNOWN_COMPLETE = ERR_QUEST_UNKNOWN_COMPLETE
local FACTION_STANDING_DECREASED = FACTION_STANDING_DECREASED:gsub("%%%d($)", "%%"):gsub("%%(s)", "(.+)"):gsub("%%(d)", "(%%d+)")
local FACTION_STANDING_INCREASED = FACTION_STANDING_INCREASED:gsub("%%%d($)", "%%"):gsub("%%(s)", "(.+)"):gsub("%%(d)", "(%%d+)")
local QUEST_COMPLETE = QUEST_COMPLETE
local QUEST_FACTION_NEEDED = QUEST_FACTION_NEEDED:gsub("%%%d($)", "%%"):gsub("%%(s)", "(.+)")
local QUEST_ITEMS_NEEDED = QUEST_ITEMS_NEEDED:gsub("%%%d($)", "%%"):gsub("%%(s)", "(.+)"):gsub("%%(d)", "(%%d+)")
local QUEST_MONSTERS_KILLED = QUEST_MONSTERS_KILLED:gsub("%%%d($)", "%%"):gsub("%%(s)", "(.+)"):gsub("%%(d)", "(%%d+)")
local QUEST_OBJECTS_FOUND = QUEST_OBJECTS_FOUND:gsub("%%%d($)", "%%"):gsub("%%(s)", "(.+)"):gsub("%%(d)", "(%%d+)")

local date,difftime,time = date,difftime,time
local floor = math.floor
local tinsert,tremove = table.insert,table.remove

local events = {}
local factionCache = {}

function AQT:OnDisable()
end

-- Not sure why I left this here.
--local hooks = {
--   "AbandonQuest",
--   "GetQuestReward",
--   "SetAbandonQuest",
--}

local QuestCache = {}
local HeaderCache = {}

StaticPopupDialogs["AQTCopy"] = {
   text = "",
   hasEditBox = 1,
   hasWideEditBox = 1,
   button2 = L.Close,
   preferredIndex = 3,
   hideOnEscape = 1,
   timeout = 0,
   whileDead = 1,
   OnShow = function(self, data)
      self.editBox:SetWidth(250)
   end,
   EditBoxOnEnterPressed = function(self)
      self:GetParent():Hide()
   end,
   EditBoxOnEscapePressed = function(self)
      self:GetParent():Hide()
   end,
}

st.types = {}

local baseObject = {
   __tostring = function(t) return t.name end,
}

baseObject.__index = baseObject

function baseObject:New(o)
   if not o.name or st.types[o.name] then error("AQT baseObject:New(): (unique) name required") end
   o.__index = o
   o.type = o
   setmetatable(o, baseObject)
   st.types[o.name] = o
   return o
end

local Header = baseObject:New(
   {
      clickScripts = {
	 Toggle = {
	    desc = L.Toggle,
	    func = function(self)
	       self.uiObject:ToggleCollapsed(true)
	    end,
	 },
      },
      name = "Header", -- L.Header
      sortFields = {
	 name = L.Title,
	 HasTimer = L["Has Timed Quest"],
	 IsClass = L["Matches Class Name"],
	 IsCurrentZone = L["Matches Current Zone"],
	 lastUpdate = L["Last Update"],
	 NumberCompleted = L["# of Completed Quests"],
	 NumberQuests = L["# of Quests"],
      },
   }
)

local Objective = baseObject:New(
   {
      name = "Objective", -- L.Objective
      sortFields = {
	 index = L.Index,
	 lastUpdate = L["Last Update"],
	 text = L.Description,
	 Completion = L["% Complete"],
      },
   }
)

local Quest = baseObject:New(
   {
      name = "Quest", -- L.Quest
      clickScripts = {
	 __blank1 = {
	    desc = "",
	    order = 5,
	 },
	 AnnounceProgress = {
	    desc = L["Announce Progress"],
	    order = 6,
	    func = function(self)
	       local channel
	       if IsInRaid() then channel = "RAID"
	       else
		  local instanceGroup = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) -- Shouldn't be relevant for classic, but put it here regardless.
		  if instanceGroup then channel = "INSTANCE_CHAT"
		  elseif IsInGroup() then channel = "PARTY" 
		  else channel = "SAY" end
	       end
	       if channel then
		  local title

		  if st.cfg.showTags then
		     local tag = self.tag and self.tag:sub(1,1) or ""
		     title = "[" .. tostring(self.level) .. tag .. "] " .. self.title
		  else
		     title = self.title
		  end

		  SendChatMessage(title .. ":", channel)
		  for k,v in ipairs(self.objectives) do
		     SendChatMessage("- " .. v.text .. " (" .. tostring(v.have) .. "/" .. tostring(v.need) .. ")", channel)
		  end
	       end
	    end,
	 },
	 SendToChat = {
	    desc = L["Send to Chat"],
	    order = 7,
	    func = function(self)
	       local title

	       if st.cfg.showTags then
		  local tag = self.tag and self.tag:sub(1,1) or ""
		  title = "[" .. tostring(self.level) .. tag .. "] " .. self.title
	       else
		  title = self.title
	       end

	       ChatEdit_InsertLink(title)
	    end,
	    disabled = function(self)
	       return not ChatEdit_GetActiveWindow()
	    end,
	 },
	 WowheadLink = {
	    desc = L["Get Wowhead URL"],
	    order = 8,
	    func = function(self)
	       local popup = StaticPopup_Show("AQTCopy")
	       local url
	       local locale = GetLocale()
	       if locale == "koKR" then
		  url = "http://wow.inven.co.kr/dataninfo/wdb/edb_quest/detail.php?id="
	       else
		  local prefix = ""
		  if locale == "deDE" then prefix = "de."
		  elseif locale == "esES" or locale == "esMX" then prefix = "es."
		  elseif locale == "frFR" then prefix = "fr."
		  elseif locale == "itIT" then prefix = "it."
		  elseif locale == "ptBR" then prefix = "pt."
		  elseif locale == "ruRU" then prefix = "ru."
		  elseif lcoale == "zhCN" or locale == "zhTW" then prefix = "cn." end
		  url = "https://" .. prefix .. "classic.wowhead.com/quest="
	       end
	       popup.editBox:SetText(url .. tostring(self.id))
	    end,
	 },
	 AbandonQuest = {
	    desc = L["Abandon Quest"],
	    order = 4,
	    func = function(self)
	       QuestLog_SetSelection(GetQuestLogIndexByID(self.id)) -- Needed, because it seems we can't use an index argument for SetAbandonQuest().
	       SetAbandonQuest()
	       local items = GetAbandonQuestItems()
	       if ( items ) then
		  StaticPopup_Hide("ABANDON_QUEST")
		  StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", GetAbandonQuestName(), items)
	       else
		  StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS")
		  StaticPopup_Show("ABANDON_QUEST", GetAbandonQuestName())
	       end
	    end,
	 },
	 ShowInQuestLog = {
	    desc = L["Show In Quest Log"],
	    order = 1,
	    func = function(self)
	       -- First make sure the header is not collapsed.
	       local index = GetQuestLogIndexByID(self.id)
	       for i = 1, GetNumQuestLogEntries(), 1 do
		  local name,_,_,isHeader,isCollapsed = GetQuestLogTitle(i)
		  if name == self.header.name and isHeader then
		     if isCollapsed then ExpandQuestHeader(i) end
		     break
		  end
	       end
	       local frame = ClassicQuestLog or QuestLogExFrame or QuestLogFrame
	       if (frame:IsShown() and GetQuestLogIndexByID(self.id) == GetQuestLogSelection()) or not frame:IsShown() then ToggleQuestLog() end
	       if ClassicQuestLog then
		  frame:SelectQuestIndex(index)
		  frame:UpdateLogList()
	       elseif QuestLogFrame:IsShown() then
		  QuestLog_SetSelection(index)
		  local offset
		  local entries = GetNumQuestLogEntries()

		  if index - floor(QUESTS_DISPLAYED/2) < 0 then offset = 0
		  elseif index + floor(QUESTS_DISPLAYED/2) > entries then offset = entries-QUESTS_DISPLAYED
		  else offset = index - floor(QUESTS_DISPLAYED/2) end

		  QuestLogListScrollFrameScrollBar:SetValue(offset*16)
		  FauxScrollFrame_SetOffset(QuestLogListScrollFrame, offset)
		  QuestLog_Update()
	       end
	    end,
	 },
	 ShareQuest = {
	    desc = L["Share Quest"],
	    order = 2,
	    func = function(self)
	       QuestLogPushQuest(GetQuestLogIndexByID(self.id))
	    end,
	    disabled = function(self)
	       return not IsInGroup()
	    end,
	 },
	 Untrack = {
	    desc = L.Untrack,
	    order = 3,
	    func = "Untrack",
	 },
      },
      sortFields = {
	 complete = L.Completion,
	 HasTimer = L["Has Timer"],
	 level = L.Level,
	 tag = L.Tag,
	 title = L.Title,
	 lastUpdate = L["Last Update"],
	 AverageCompletion = L["Average Completion"],
      },
   }
)

-- May rename this later, right now it's only a special case used by only one ui element. Could be relevant if I take a more modular approach later. In case I need to include support for, I dunno, achievements or something silly like that.
local Title = baseObject:New(
   {
      name = "Title",
      __tostring = function(t) return "Title" end,
      TitleText = st.L.Quests,

      CounterText = function(self)
	 local text
	 if st.cfg.useProgressColor then text = "|cff" .. Prism:Gradient(st.cfg.useHSVGradient and "hsv" or "rgb", st.cfg.progressColorMin.r, st.cfg.progressColorMax.r, st.cfg.progressColorMin.g, st.cfg.progressColorMax.g, st.cfg.progressColorMin.b, st.cfg.progressColorMax.b, (MAX_QUESTLOG_QUESTS-self.quests)/MAX_QUESTLOG_QUESTS) .. tostring(self.quests) .. "/" .. tostring(MAX_QUESTLOG_QUESTS) .. "|r"
	 else text = tostring(self.quests) .. "/" .. tostring(MAX_QUESTLOG_QUESTS) end

	 return text
      end,

      quests = 0,
   }
)

local function QuestLogClick(self, button)
   local index = self:GetID() + FauxScrollFrame_GetOffset(QuestLogListScrollFrame)

   local _,_,_,_,_,_,_,id = GetQuestLogTitle(index)
   if IsShiftKeyDown() then
      if not QuestCache[id] then error("Unknown quest with id '" .. tostring(id) .. "'.") end
      QuestCache[id]:Toggle()
      -- Ugly hack. Need to find a better way to handle this. But I also want to do it while minimizing my interaction with the default UI (HELLO TAINT), but bypassing the quest watch limit.
      if IsQuestWatched(index) then RemoveQuestWatch(index) end
   end
end

function AQT:OnInitialize()
   st.initConfig()
end

function AQT:OnEnable()
   QuestTimerFrame:SetScript("OnShow", function(self)
				if st.cfg.hideQuestTimerFrame then self:Hide() end
   end)

   QuestWatchFrame:SetScript("OnShow", function(self)
				if st.cfg.hideQuestWatch then self:Hide() end
   end)

   if st.cfg.hideQuestTimerFrame then QuestTimerFrame:Hide() end
   if st.cfg.hideQuestWatch then QuestWatchFrame:Hide() end

   st.gui:OnEnable()

   self:RegisterEvent("BAG_UPDATE_DELAYED", "Event")
   self:RegisterEvent("UPDATE_FACTION", "Event")
   self:RegisterEvent("PLAYER_LEVEL_UP", "Event")
   self:RegisterEvent("QUEST_LOG_UPDATE", "Event")
   self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "Event")
   self:SuppressionCheck()

   if ClassicQuestLog then
      ClassicQuestLog.ToggleWatch = function(self, index)
	 if not index then index = GetQuestLogSelection() end
	 local _,_,_,_,_,_,_,id = GetQuestLogTitle(index)
	 if not QuestCache[id] then error("Unknown quest with id '" .. tostring(id) .. "'.") end
	 QuestCache[id]:Toggle()
	 ClassicQuestLog:UpdateLogList()
      end
   end

   local icon = [[Interface\GossipFrame\AvailableQuestIcon]]
   AQT.LDBObject = LDB:NewDataObject("AQT", {type = "launcher",icon = icon,OnClick = function(self, button) if button == "LeftButton" then AQT:ToggleConfig() end end,tocname = "AQT"})
   self:UpdateLDBIcon()
   hooksecurefunc("QuestLogTitleButton_OnClick", QuestLogClick)

   self:QuestLogUpdate(true)
   if st.db.char.tracked_quests then
      for k,v in pairs(st.db.char.tracked_quests) do
	 if not QuestCache[k] then st.db.char.tracked_quests[k] = nil
	 elseif v == true then
	    if not QuestCache[k]:IsTracked() then QuestCache[k]:Track(true) end
	 elseif v == false then
	    if QuestCache[k]:IsTracked() then QuestCache[k]:Untrack(true) end
	 elseif type(v) == "number" and not QuestCache[k]:IsTracked() then
	    local factor = (st.cfg.autoTrackTimeUnits == "minutes" and 60 or 1)
	    if st.cfg.autoTrackTimer > 0 and difftime(time(), v) > (st.cfg.autoTrackTimer*factor) then st.db.char.tracked_quests[k] = nil
	    else QuestCache[k]:Track(v) end
	 end
      end
   end

   self:ZoneChangedNewArea()
end

function AQT:UpdateLDBIcon()
   local icon = [[Interface\ICONS\INV_MISC_Book_%02d]]
   if st.cfg.LDBIcon == -1 then self.LDBObject.icon = [[Interface\GossipFrame\AvailableQuestIcon]]
   elseif st.cfg.LDBIcon == 0 then self.LDBObject.icon = icon:format(random(1,15))
   else self.LDBObject.icon = icon:format(st.cfg.LDBIcon) end
end

function Header:CounterText()
   if st.cfg.showHeaderCount then
      local text
      local completed = 0
      local progress
 
      for k,v in ipairs(self.quests) do
	 if v.complete and v.complete > 0 then completed = completed + 1 end
      end

      if #self.quests > 0 then
	 progress = completed/#self.quests
      else
	 progress = 1
      end

      if st.cfg.useProgressColor then 
	 text = "|cff" .. Prism:Gradient(st.cfg.useHSVGradient and "hsv" or "rgb", st.cfg.progressColorMin.r, st.cfg.progressColorMax.r, st.cfg.progressColorMin.g, st.cfg.progressColorMax.g, st.cfg.progressColorMin.b, st.cfg.progressColorMax.b, progress) .. tostring(completed) .. "/" .. tostring(#self.quests)
      else
	 text = tostring(completed) .. "/" .. tostring(#self.quests)
      end

      return text
   else
      return ""
   end
end

function Header:CreateUIObject()
   if self.uiObject then error("Header:CreateUIObject(): '" .. self.name .. "' already has an uiObject.") end
   self.uiObject = st.gui.title:New(self)
end

function Header:HasTimer()
   for k,v in ipairs(self.trackedQuests) do
      if v.timer then return true end
   end
   return false
end

function Header:IsClass()
   return (UnitClass("player") == self.name)
end

function Header:IsCurrentZone()
   return (GetRealZoneText() == self.name)
end

function Header:New(o)
   if not o.name then error("Header:New() requires header name to be set.") end
   setmetatable(o, self)
   if not o.quests then o.quests = {} end
   if not o.trackedQuests then o.trackedQuests = {} end
   HeaderCache[o.name] = o
   o.lastUpdate = time()
   return o
end

function Header:NumberCompleted()
   local completed = 0
   for k,v in ipairs(self.quests) do
      if v.complete and v.complete > 0 then completed = completed + 1 end
   end

   return completed
end

function Header:NumberQuests()
   return #self.quests
end

function Header:Remove()
   if #self.quests > 0 then error("Header:Remove(): '" .. self.name .. "': trying to remove header that still has quests attached.") end
   if self.uiObject then self.uiObject:Release() end
   HeaderCache[self.name] = nil
end

function Header:TestCollapsedState()
   if st.cfg.automaticCollapseExpand and self.uiObject then
      if self:IsCurrentZone() then self.uiObject:ExpandHeader() else self.uiObject:CollapseHeader() end
   end
end

function Header:TitleText()
   if self:IsCurrentZone() then
      self.uiObject:SetZoneHighlight()
      if st.cfg.highlightCurrentZoneText then
	 local fmt = "|cff%02x%02x%02x%s|r"
	 local c = st.cfg.highlightCurrentZoneTextColor
	 return fmt:format(c.r*255, c.g*255, c.b*255, self.name)
      end
   end
   return self.name
end

function Header:Update()
   if st.cfg.showHeaders and #self.trackedQuests > 0 then
      if not self.uiObject then
	 self:CreateUIObject()
      end
      self:TestCollapsedState() -- Should probably put this here too, in case we pick up something new that should be under a collapsed header.
      self.uiObject:Update()
   elseif self.uiObject then
      self.uiObject:Release()
   end
end

function Objective:Completion()
   return self.have/self.need
end

function Objective:CounterText()
   local text

   local counterString = self.counterString and self.counterString or (tostring(self.have) .. "/" .. tostring(self.need))

   if st.cfg.useProgressColor then
      text = "|cff" .. Prism:Gradient(st.cfg.useHSVGradient and "hsv" or "rgb", st.cfg.progressColorMin.r, st.cfg.progressColorMax.r, st.cfg.progressColorMin.g, st.cfg.progressColorMax.g, st.cfg.progressColorMin.b, st.cfg.progressColorMax.b, self.have/self.need) .. counterString .. "|r"
   else
      text = counterString
   end

   return text
end

function Objective:New(o)
   if not o.quest then error("Objective:New() requires quest id to be set.") end
   setmetatable(o, self)
   return o
end

function Objective:TitleText()
   local text
   local prefix = st.cfg.objectivePrefix

   if st.cfg.useProgressColor then
      text = "|cff" .. Prism:Gradient(st.cfg.useHSVGradient and "hsv" or "rgb", st.cfg.progressColorMin.r, st.cfg.progressColorMax.r, st.cfg.progressColorMin.g, st.cfg.progressColorMax.g, st.cfg.progressColorMin.b, st.cfg.progressColorMax.b, self.have/self.need) .. prefix .. self.text .. "|r"
   else
      text = prefix .. self.text
   end

   return text
end

function Objective:Update(qIndex, oIndex, noPour)
   local oText,oType,complete = GetQuestLogLeaderBoard(oIndex, qIndex)
   local text,have,need
   local countertext
   local update
   local sound

   if oType == "monster" then
      text,have,need = string.match(oText, "^" .. QUEST_MONSTERS_KILLED .. "$")
      if not have then -- Some of these objectives apparently do not follow this string pattern.
	 text,have,need = string.match(oText, "^(.+): (%d+)/(%d+)$")
      end
   elseif oType == "item" then
      text,have,need = string.match(oText, "^" .. QUEST_ITEMS_NEEDED .. "$")

   elseif oType == "object" then
      text,have,need = string.match(oText, "^" .. QUEST_OBJECTS_FOUND .. "$")

   elseif oType == "reputation" then
      text,have,need = string.match(oText, "^" .. QUEST_FACTION_NEEDED .. "$")
      if not factionCache[text] then
	 countertext = have:sub(1,1) .. "/" .. need:sub(1,1)
	 have,need = (complete and 1 or 0),1
      else
	 have = factionCache[text].reputation or 0
	 if need == FACTION_STANDING_LABEL1 then need = -42000 -- Hated. This would be strange, but uh, ok.
	 elseif need == FACTION_STANDING_LABEL2 then need = -6000 -- Hostile
	 elseif need == FACTION_STANDING_LABEL3 then need = -3000 -- Unfriendly
	 elseif need == FACTION_STANDING_LABEL4 then need = 0 -- Neutral
	 elseif need == FACTION_STANDING_LABEL5 then need = 3000 -- Friendly
	 elseif need == FACTION_STANDING_LABEL6 then need = 9000 -- Honored
	 elseif need == FACTION_STANDING_LABEL7 then need = 21000 -- Revered
	 elseif need == FACTION_STANDING_LABEL8 then need = 42000 -- Exalted
	 else need = have end -- Just default to something.
	 local fmt = "%.1fk/%.1fk"
	 countertext = fmt:format(have/1000,need/1000)
      end

   elseif oType == "event" then
      have,need = (complete and 1 or 0),1
      countertext = ""
      text = oText
   else
      print("AQT:CheckObjectives(): Unknown objective type '" .. oType .. "'. Falling back to default parsing with this debug info.")
      have,need = (complete and 1 or 0),1
      text = "(" .. oType .. ")" .. cstring .. oText .. "|r"
   end

   if self.text ~= text or self.have ~= have or self.need ~= need or self.complete ~= complete then
      if not self.new then
	 sound = st.SOUND_OBJECTIVE_PROGRESS
      end
      update = true
      self.lastUpdate = time()
   end

   if not self.new then
      local pour,_,r,g,b
      if complete and not self.complete then
	 sound = st.SOUND_OBJECTIVE_COMPLETE
	 pour = true
	 self.progress = 1
	 r,g,b = st.cfg.progressColorMax.r, st.cfg.progressColorMax.g, st.cfg.progressColorMax.b
      elseif self.have ~= have and not complete then
	 pour = true
	 _,r,g,b = Prism:Gradient(st.cfg.useHSVGradient and "hsv" or "rgb", st.cfg.progressColorMin.r, st.cfg.progressColorMax.r, st.cfg.progressColorMin.g, st.cfg.progressColorMax.g, st.cfg.progressColorMin.b, st.cfg.progressColorMax.b, have/need)
      end

      if pour and not noPour then AQT:PrePour(text .. ": " .. tostring(have) .. "/" .. tostring(need), r, g, b) end
   end

   self.new = nil

   self.text = text
   self.have = have
   self.need = need
   self.complete = complete
   self.counterString = countertext and countertext or nil --(tostring(have) .. "/" .. tostring(need))
   self.index = oIndex

   if self.complete and st.cfg.hideCompletedObjectives then
      if self.uiObject then
	 self.uiObject:Release()
	 update = false -- just in case
      end
   elseif not self.uiObject and QuestCache[self.quest].uiObject then
      self.uiObject = QuestCache[self.quest].uiObject:New(self)
      update = true
   end

   if update and self.uiObject then self.uiObject:Update() end
   return sound
end

function Quest:AverageCompletion()
   if #self.objectives == 0 then return 1 end

   local have,need = 0,0
   for k,v in ipairs(self.objectives) do
      have = have + v.have
      need = need + v.need
   end

   return have/need
end

function Quest:HasTimer()
   if v.timer then return true else return false end
end

function Quest:IsTracked()
   return (self.uiObject and not self.uiObject.releasing) and true or false
end

function Quest:New(o, noAuto)
   if not o.id then error("Quest:New() requires id to be set.") end
   setmetatable(o, self)
   if not o.objectives then o.objectives = {} end
   local header = o.header and o.header.name or "Unknown"
   if not HeaderCache[header] then o.header = Header:New({name = header, quests = {o}})
   else
      o.header = HeaderCache[header] 
      tinsert(o.header.quests, o)
   end
   QuestCache[o.id] = o
   -- if o.timer, then add handling here .. then in Quest:Track(), and make the proper ui changes. But first: sleep.
   o:Update()
   if st.cfg.trackAll then o:Track()
   elseif st.cfg.autoTrackZone and o.header:IsCurrentZone() then o:Track(0)
   elseif st.cfg.autoTrackNew and not noAuto then o:Track(time()) end
   return o
end

function Quest:Remove()
   if self.uiObject then self:Untrack(true) end
   for i,v in ipairs(self.header.quests) do
      if self == v then tremove(self.header.quests, i) end
   end
   self.header = nil
   if st.db.char.tracked_quests then st.db.char.tracked_quests[self.id] = nil end
   QuestCache[self.id] = nil
end

function Quest:SetUntrackTimer(timer)
   local factor = (st.cfg.autoTrackTimeUnits == "minutes" and 60 or 1)
   local diff = difftime(time(), timer)
   local delay = (st.cfg.autoTrackTimer * factor) - diff

   if self.untrackTimer then self.untrackTimer:Cancel() end

   self.untrackTimer = C_Timer.NewTimer(delay, function()
					   self.untrackTimer = nil
					   if self:IsTracked() then
					      self:Untrack(time())
					   end 
   end)
end

function Quest:TitleText()
   local text

   if st.cfg.showTags then
      local tag = self.tag and self.tag:sub(1,1) or ""
      text = "[" .. tostring(self.level) .. tag .. "] " .. self.title
   else
      text = self.title
   end

   if st.cfg.useDifficultyColor then
      local c = GetQuestDifficultyColor(self.level)
      text = "|cff%02x%02x%02x" .. text .. "|r"
      text = text:format(c.r*255,c.g*255,c.b*255)
   end

   return text
end

function Quest:Toggle()
   if not self:IsTracked() then self:Track(true)
   else self:Untrack(true) end
end

function Quest:Track(override)
   if self.override and not override then return end

   if self:IsTracked() then return end

   self.override = override

   if override then
      if not st.db.char.tracked_quests then st.db.char.tracked_quests = {} end
      st.db.char.tracked_quests[self.id] = override

      if type(override) == "number" and override > 0 and st.cfg.autoTrackTimer > 0 then
	 self:SetUntrackTimer(override)
      end
   end

   local fader = self.uiObject and self.uiObject:GetFader()
   
   if fader then
      local alpha = self.uiObject:GetAlpha()
      fader:Stop()
      self.uiObject:Fade(0, 1, 0, self.uiObject)
      self.uiObject.releasing = nil
      return
   end

   local parent
   if st.cfg.showHeaders then
      if not self.header.uiObject then self.header:CreateUIObject() end
      parent = self.header.uiObject
   else parent = st.gui.title end

   tinsert(self.header.trackedQuests, self)
   self.uiObject = parent:New(self)
   self:Update() -- Temporary fix
   self.header:Update()
   self.uiObject:Update()
end

function Quest:Untrack(override)
   if self.override and not override then return end

   if not self:IsTracked() then return end

   if self.untrackTimer then
      self.untrackTimer:Cancel()
      self.untrackTimer = nil
      self.override = nil
   end

   if override then
      if not st.db.char.tracked_quests then st.db.char.tracked_quests = {} end
      if type(override) == "number" then
	 st.db.char.tracked_quests[self.id] = nil
	 self.override = nil
      else
	 st.db.char.tracked_quests[self.id] = false
	 self.override = override
      end
   end

   for i,v in ipairs(self.header.trackedQuests) do
      if self == v then tremove(self.header.trackedQuests, i) end
   end

   self.uiObject:Release()
   self.header:Update()
end

function Quest:Update(timer)
   local index = GetQuestLogIndexByID(self.id)
   if not index then error("Quest:Update(): Unable to find quest '" .. self.title .. "' in log.") end

   local qTitle,qLevel,qTag,qHeader,qCollapsed,qComplete = GetQuestLogTitle(index)
   local sound = nil
   local update = nil
   local title

   if timer then
      if self.timer then -- There already is a timer, update it if needed.
	 self.timer.timeleft = timeleft -- this should only really be relevant for sorting purposes, and will not be needed in continuous updates beyond QLU
	 if not(difftime(self.timer.expires, timer.expires) < 5 or diffctime(self.timer.expires, timer.expires) > 5) then -- unless expires-5<expires<expires+5 it's well outside of error margin, so the timer has changed
	    self.timer.expires = timer.expires
	    self.timer.started = timer.started
	 end
      else
	 self.timer = timer
      end
   end

   if self.title ~= qTitle or self.level ~= qLevel or self.tag  ~= qTag or (self.complete ~= qComplete and GetNumQuestLeaderBoards(index) > 0) then
      update = true
   end

   if qComplete then
      if st.cfg.hideQuestCompletedObjectives then
	 for k,v in ipairs(self.objectives) do
	    if v.uiObject then
	       v.uiObject:Release()
	    end
	 end
      end
      if not self.complete and qComplete > 0 then
	 sound = st.SOUND_COMPLETE
	 AQT:PrePour("Quest Complete: " .. qTitle, st.cfg.progressColorMax.r, st.cfg.progressColorMax.g, st.cfg.progressColorMax.b)
      end
   end
   if GetNumQuestLeaderBoards(index) == 0 then qComplete = 1 end -- Special handling
   self.title = qTitle
   self.level = qLevel
   self.tag = qTag
   self.complete = qComplete

   if not qComplete then
      sound = self:UpdateObjectives()
      if sound then
	 update = true
	 self.lastUpdate = time()
      end
   elseif not st.cfg.hideQuestCompletedObjectives then self:UpdateObjectives(true) end
   if update then
      self.lastUpdate = time()
      if self.uiObject then
	 self.uiObject:Update()
	 if self.timer then self.uiObject:UpdateTimer() end
	 if st.cfg.autoTrackUpdated and self.untrackTimer then self:SetUntrackTimer(time()) end
      elseif st.cfg.autoTrackUpdated then
	 self:Track(time())
      end
   end
   self.header:Update()
   return sound
end

--[[
function Quest:UpdateScripts()
   if not self.uiObject then return end
   local ui = self.uiObject
   if st.cfg.mouse.enabled then 
      ui:EnableMouse(true)
   else
      ui:EnableMouse(false)
   end
end
]]--

function Quest:UpdateObjectives(noPour)
   local index = GetQuestLogIndexByID(self.id)
   if not index then error("Quest:UpdateObjectives(): Unable to find quest '" .. self.title .. "' in log.") end

   local sound

   for i = 1, GetNumQuestLeaderBoards(index) do
      if not self.objectives[i] then self.objectives[i] = Objective:New({quest = self.id, index = i, new = true}) end
      local check = self.objectives[i]:Update(index, i, noPour)

      if check then
	 if sound then
	    if sound > check then sound = check end
	 else
	    sound = check
	 end
      end
   end
   return sound
end

function AQT:QuestLogUpdate(noAuto)
   -- Find any updated quests or new quests/headers.
   local entries,questentries = GetNumQuestLogEntries()
   local localQuestCache = {}
   local localHeaderCache = {}
   local currentHeader = nil
   local count = 0
   local playSound = nil
   local sound
   local i = 1
   local timers = {GetQuestTimers()}
   for k,v in ipairs(timers) do
      local now = date("*t")
      now.sec = now.sec + timers[k] -- Yes, despite documentation stating this field is between 0--61, lua seems to actually support this. This table now represents the expiracy time.
      timers[k] = {timeleft = timers[k],index = GetQuestIndexForTimer(k), started = time(), expires = time(now)}
   end
   while i do
      local qTitle,qLevel,qTag,qHeader,qCollapsed,qComplete,qFreq,qID = GetQuestLogTitle(i)

      if not qTitle then i = nil;break end

      if currentHeader and i > entries then currentHeader = nil end
      if qHeader then
	 localHeaderCache[qTitle] = true
	 -- Separate if rather than "and" so we can use else.
	 if not HeaderCache[qTitle] then currentHeader = Header:New({name = qTitle}) else currentHeader = HeaderCache[qTitle] end
      else
	 local timer
	 for k,v in ipairs(timers) do
	    if v.index == i then timer = v end
	 end
	 localQuestCache[qID] = true
	 if not QuestCache[qID] then
	    Quest:New({title = qTitle, level = qLevel, tag = qTag, complete = qComplete, id = qID, header = currentHeader, timer = timer}, noAuto)
	 else 
	    local q = QuestCache[qID]
	    local sound = q:Update(timer)
	    if sound then
	       if not playSound then playSound = sound
	       elseif playSound > sound then playSound = sound end
	    end
	 end
      end
      i = i + 1
   end
   -- Find any removed quests or headers.
   for k,v in pairs(QuestCache) do
      if not localQuestCache[k] then v:Remove() end
   end
   for k,v in pairs(HeaderCache) do
      if k ~= "Unknown" and not localHeaderCache[k] then v:Remove() end
   end

   if playSound == st.SOUND_COMPLETE and st.cfg.playCompletionSound then
      if st.cfg.useFactionCompletionSound then
	 if UnitFactionGroup("player") == "Alliance" then sound = "Peasant: Job's Done"
	 else sound = "Peon: Work Complete" end -- Should only get here if the player is Horde. Otherwise, the horde is more awesome anyway.
      else sound = st.cfg.completionSoundName end
   elseif playSound and playSound <= st.SOUND_OBJECTIVE_COMPLETE and st.cfg.playObjectiveSound then -- objective complete
      if st.cfg.useFactionObjectiveSound then
	 if UnitFactionGroup("player") == "Alliance" then sound = "Peasant: Ready to Work"
	 else sound = "Peon: Ready to Work" end -- default to horde, as it should be!
      else sound = st.cfg.objectiveSoundName end
   elseif playSound and playSound <= st.SOUND_OBJECTIVE_PROGRESS and st.cfg.playObjectiveProgressSound then
      if st.cfg.useFactionObjectiveProgressSound then
	 if UnitFactionGroup("player") == "Alliance" then sound = "Peasant: More Work?"
	 else sound = "Peon: Work Work" end
      else sound = st.cfg.objectiveProgressSoundName end
   end

   if sound then PlaySoundFile(LSM:Fetch("sound", sound)) end

   Title.quests = questentries
   st.gui.title:UpdateText()
end

function AQT:PlayerLevelUp()
   for k,v in pairs(QuestCache) do if v.uiObject then v.uiObject:UpdateText() end end
end

function AQT:ZoneChangedNewArea()
   self:TrackingUpdate()

   st.gui.title:Sort()
   st.gui.highlight:Hide()
   self:UpdateHeaders()
   --[[ Should no longer be needed, as we'll be updating all headers, which will call this function as well.
   if st.cfg.automaticCollapseExpand then for k,v in pairs(HeaderCache) do v:TestCollapsedState() end end
   ]]--
end

-- This is ugly, but AceHook didn't seem to deliver quite according to documentation.

local function errorFrameAddMessage(self, msg, r, g, b, a)
   if r == 1 and g == 1 and b == 0 and not msg:match("^|cff") then -- All relevant default quest messages are in yellow, and should have no colour string. This should be a good first filter for anything we don't want to suppress.
      if msg == QUEST_COMPLETE then return -- Don't think this is in UIErrorsFrame, but just in case?
      elseif msg == ERR_QUEST_UNKNOWN_COMPLETE then return
      elseif msg:match("^" .. QUEST_MONSTERS_KILLED .. "$") then return
      elseif msg:match("^" .. QUEST_ITEMS_NEEDED .. "$") then return
      elseif msg:match("^" .. QUEST_OBJECTS_FOUND .. "$") then return
      elseif msg:match("^" .. QUEST_FACTION_NEEDED .. "$") then return
      elseif msg:match("^" .. ERR_QUEST_OBJECTIVE_COMPLETE_S .. "$") then return end
   end
   AQT.ErrorFrameAddMessage(UIErrorsFrame, msg, r, g, b, a)
end

function AQT:SuppressionCheck()
   if st.cfg.suppressErrorFrame then
      if not AQT.ErrorFrameAddMessage then
	 AQT.ErrorFrameAddMessage = UIErrorsFrame.AddMessage
	 UIErrorsFrame.AddMessage = errorFrameAddMessage
      end
   elseif AQT.ErrorFrameAddMessage then
      UIErrorsFrame.AddMessage = AQT.ErrorFrameAddMessage
      AQT.ErrorFrameAddMessage = nil
   end
end

function AQT:PrePour(msg, r, g, b)
   if not msg:match("^|cff") then -- no point applying colour code if the message is coded already
      msg:format("|cff%02x%02x%02x" .. msg .. "|r", r*255, g*255, b*255)
      if r == 1 and g == 1 and b == 0 then b = .001 end -- Just to make sure we don't suppress our own messages, if Sink is directed to the errorframe.
      self:Pour(msg, r, g, b)
   end
end

function AQT:Event_UpdateFaction(arg1, arg2)
   if not GetFactionInfo(1) then return end

   local i = 1
   local otherfound
   while i do
      local faction,_,standing,offset,_,value = GetFactionInfo(i)
      -- This looks really strange, but GetFactionInfo(i) will:
      -- * Return the "Other" entry at the proper place.
      -- * Eventually return the "Inactive"
      -- * Then, after, I would assume, cycling through the inactives return "Other" again for each incremental value of i.
      -- So yes, this looks really strange. But there's a reason for it. I give you: The Blizzard WoW API.
      if not faction or faction == "Other" then
	 if not faction or otherfound then
	    i = nil
	    break
	 else
	    otherfound = true
	 end
      end

      if factionCache[faction] then
	 factionCache[faction].reputation = value
	 factionCache[faction].standing = standing
      else
	 factionCache[faction] = {
	    reputation = value,
	    standing = standing,
	 }
      end
      i = i + 1
   end

   self:QuestLogUpdate()
end

function AQT:ExpandHeaders() -- While it seems to make more sense to stick this with the gui functions, this is where we have the iterator cache. So.. well, possibly make it accessible from elsewhere, or just keep this here.
   for k,v in pairs(HeaderCache) do if v.uiObject then v.uiObject:ExpandHeader() end end
end

function AQT:ToggleHeaders()
   local cache = {} -- Only iterate over the ones with uiObjects the second time around.
   for k,v in pairs(QuestCache) do
      if v.uiObject then
	 tinsert(cache, v)
	 v.uiObject:Orphan()
      end
   end

   for k,v in ipairs(cache) do
      local parent
      if st.cfg.showHeaders then
	 if not v.header.uiObject then v.header:CreateUIObject() end
	 parent = v.header.uiObject
      else
	 parent = st.gui.title
      end
      v.uiObject:GetAdopted(parent)
   end
   if not st.cfg.showHeaders then st.gui.title:Update() end
   AQT:UpdateHeaders()
end

function AQT:UpdateHeaders()
   for k,v in pairs(HeaderCache) do v:Update() end
end

--[[
function AQT:UpdateScripts()
   for k,v in pairs(QuestCache) do v:UpdateScripts() end
end
]]--

-- This current works because we don't need to consider any arguments for any of the events. Should this change, I'll have to change this.
function AQT:Event(event, ...)
   if not events[event] then
      local func

      if event == "BAG_UPDATE_DELAYED" or event == "QUEST_LOG_UPDATE" then func = "QuestLogUpdate"
      elseif event == "UPDATE_FACTION" then func = "Event_UpdateFaction"
      elseif event ==  "PLAYER_LEVEL_UP" then func = "PlayerLevelUp"
      elseif event == "ZONE_CHANGED_NEW_AREA" then func = "ZoneChangedNewArea"
      else return end

      events[event] = true
      C_Timer.After(.05, function()
		       AQT[func](AQT)
		       events[event] = nil
      end)
   end
end

function AQT:TrackingUpdate()
   if st.cfg.trackAll then for k,v in pairs(QuestCache) do v:Track() end
   else
      for k,v in pairs(QuestCache) do
	 if st.cfg.autoTrackZone then
	    if not v.override or (type(v.override) == "number" and v.override == 0) then
	       if v.header:IsCurrentZone() and not v:IsTracked() then v:Track(0)
	       elseif not v.header:IsCurrentZone() and v:IsTracked() then v:Untrack(0) end
	    end
	 elseif v.override == 0 then v:Untrack(0) end
      end
   end
end

-- The functions below are to be considered experimental, as they could well risk causing taint.
function IsQuestWatched(index)
   local _,_,_,_,_,_,_,id = GetQuestLogTitle(index)
   return QuestCache[id] and QuestCache[id]:IsTracked()
end
