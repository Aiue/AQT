local _,st = ...

local AQT = LibStub("AceAddon-3.0"):NewAddon("AQT", "AceEvent-3.0", "LibSink-2.0")
local LDB = LibStub("LibDataBroker-1.1")
local LSM = LibStub("LibSharedMedia-3.0")
local Prism = LibStub("LibPrism-1.0")

local L = st.L

LSM:Register("sound", "Peasant: Job's Done", [[Interface\AddOns\AQT\Sounds\Peasant_work_done.mp3]])
LSM:Register("sound", "Peasant: Ready to Work", [[Sound\Creature\Peasant\PeasantReady1.ogg]])
LSM:Register("sound", "Peon: Ready to Work", [[Sound\Creature\Peon\PeonReady1.ogg]])
LSM:Register("sound", "Peon: Work Complete", [[Sound\Creature\Peon\PeonBuildingComplete1.ogg]])
LSM:Register("sound", "Peon: Work Work", [[Sound\Creature\Peon\PeonYes3.ogg]])

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

local tinsert,tremove = table.insert,table.remove

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
      name = "Header",
      TitleText = "",
      testTable = {1,2,3},
      sortFields = {
	 name = L.Title,
	 IsClass = L["Matches Class Name"],
	 IsCurrentZone = L["Matches Current Zone"],
	 lastUpdate = L["Last Update"],
      },
   }
)

local Objective = baseObject:New(
   {
      name = "Objective",
      sortFields = {
	 index = L.Index,
	 lastUpdate = L["Last Update"],
      },
   }
)

local Quest = baseObject:New(
   {
      name = "Quest",
      sortFields = {
	 complete = L.Completion,
	 level = L.Level,
	 tag = L.Tag,
	 title = L.Title,
	 lastUpdate = L["Last Update"],
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

function AQT:OnInitialize()
   st.initConfig()
end

local function factionInit()
   if not GetFactionInfo(1) then
      print("GetFactionInfo(1) returned nil, retrying in ten seconds..")
      C_Timer.After(10, factionInit())
      return
   end

   local i = 1
   local otherfound
   while i do
      local faction,_,standing,_,_,value = GetFactionInfo(i)
      -- This looks really strange, but GetFactionInfo(i) will:
      -- * Return the "Other" entry at the proper place.
      -- * Eventually return the "Inactive"
      -- * Then, after, I would assume, cycling through the inactives return "Other" again for each incremental value of i.
      -- So yes, this looks really strange. But there's a reason for it. I give you: The Blizzard WoW API.
      if not faction or faction == "Other" then
	 if otherfound then
	    i = nil
	    break
	 else
	    otherfound = true
	 end
      end
      local val

      if standing == 8 then val = value + 84000 -- Exalted
      elseif standing == 7 then val = value + 63000 -- Revered
      elseif standing == 6 then val = value + 51000 -- Honored
      elseif standing == 5 then val = value + 45000 -- Friendly
      elseif standing == 4 then val = value + 42000 -- Neutral
      elseif standing == 3 then val = value + 39000 -- Unfriendly
      elseif standing == 2 then val = value + 36000 -- Hostile
      else val = value end -- Hated, defaults to.  standing SHOULDN'T be other than 1 in this case, but never know..

      factionCache[faction] = {
	 raw = val,
	 relative = value,
	 standing = standing,
	 objectives = {},
      }
      i = i + 1
   end

   factionInit = nil
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

   factionInit()

   self:RegisterEvent("BAG_UPDATE_DELAYED", "QuestLogUpdate")
   self:RegisterEvent("CHAT_MSG_SYSTEM", "Event_ChatMsgSystem")
   self:RegisterEvent("PLAYER_LEVEL_UP", "PlayerLevelUp")
   self:RegisterEvent("QUEST_LOG_UPDATE", "QuestLogUpdate")
   self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ZoneChangedNewArea")
   self:SuppressionCheck()

   local icon = [[Interface\GossipFrame\AvailableQuestIcon]]
   AQT.LDBObject = LDB:NewDataObject("AQT", {type = "launcher",icon = icon,OnClick = function(self, button) if button == "LeftButton" then AQT:ToggleConfig() end end,tocname = "AQT"})
   self:UpdateLDBIcon()
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

function Header:Update()
   self.TitleText = self.name
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

   if st.cfg.useProgressColor then
      text = "|cff" .. Prism:Gradient(st.cfg.useHSVGradient and "hsv" or "rgb", st.cfg.progressColorMin.r, st.cfg.progressColorMax.r, st.cfg.progressColorMin.g, st.cfg.progressColorMax.g, st.cfg.progressColorMin.b, st.cfg.progressColorMax.b, self.have/self.need) .. self.text .. "|r"
   else
      text = self.text
   end

   return text
end

function Objective:Update(qIndex, oIndex)
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
	 have = factionCache[text].raw
	 if need == FACTION_STANDING_LABEL1 then need = 0 -- Hated. This would be strange, but uh, ok.
	 elseif need == FACTION_STANDING_LABEL2 then need = 36000 -- Hostile
	 elseif need == FACTION_STANDING_LABEL3 then need = 39000 -- Unfriendly
	 elseif need == FACTION_STANDING_LABEL4 then need = 42000 -- Neutral
	 elseif need == FACTION_STANDING_LABEL5 then need = 45000 -- Friendly
	 elseif need == FACTION_STANDING_LABEL6 then need = 51000 -- Honored
	 elseif need == FACTION_STANDING_LABEL7 then need = 63000 -- Revered
	 elseif need == FACTION_STANDING_LABEL8 then need = 84000 -- Exalted
	 else need = have end -- Just default to something.
	 local fmt = "%.1fk/%.1fk"
	 countertext = fmt:format(need/1000,have/1000)
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
      update = true
      self.lastUpdate = time()
   end

   if not self.new then
      local pour,_,r,g,b
      if complete and not self.complete then
	 sound = false
	 pour = true
	 self.progress = 1
	 r,g,b = st.cfg.progressColorMax.r, st.cfg.progressColorMax.g, st.cfg.progressColorMax.b
      elseif self.have ~= have and not complete then
	 pour = true
	 _,r,g,b = Prism:Gradient(st.cfg.useHSVGradient and "hsv" or "rgb", st.cfg.progressColorMin.r, st.cfg.progressColorMax.r, st.cfg.progressColorMin.g, st.cfg.progressColorMax.g, st.cfg.progressColorMin.b, st.cfg.progressColorMax.b, have/need)
      end

      if pour then AQT:PrePour(text .. ": " .. tostring(have) .. "/" .. tostring(need), r, g, b) end
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

function Quest:New(o)
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
   if st.cfg.trackAll then o:Track() end
   return o
end

function Quest:Remove()
   if self.uiObject then self:Untrack() end
   for i,v in ipairs(self.header.quests) do
      if self == v then tremove(self.header.quests, i) end
   end
   self.header = nil
   QuestCache[self.id] = nil
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
   else
      text = self.title
   end

   return text
end

function Quest:Track()
   if self.uiObject then error("Attempting to track already tracked quest, '" .. self.title .. "'.") end

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

function Quest:Untrack()
   if not self.uiObject then error("Attempting to untrack untracked quest, '" .. self.title .. "'.") end

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

   if self.title ~= qTitle or self.level ~= qLevel or self.tag  ~= qTag or self.complete ~= qComplete then
      update = true
      lastUpdate = time()
      self.header.lastUpdate = time()
   end

   if qComplete then
      for k,v in ipairs(self.objectives) do
	 if v.uiObject then
	    v.uiObject:Release()
	 end
      end
      if not self.complete and qComplete > 0 then
	 sound = true
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
      if sound == false then self.lastUpdate = time() end
   end
   if self.uiObject then
      if update then self.uiObject:Update() end
      if self.timer then self.uiObject:UpdateTimer() end
   end
   self.header:Update()
   return sound
end

function Quest:UpdateObjectives()
   local index = GetQuestLogIndexByID(self.id)
   if not index then error("Quest:UpdateObjectives(): Unable to find quest '" .. self.title .. "' in log.") end

   local sound

   for i = 1, GetNumQuestLeaderBoards(index) do
      if not self.objectives[i] then self.objectives[i] = Objective:New({quest = self.id, index = i, new = true}) end
      local check = self.objectives[i]:Update(index, i)
      if sound == nil then sound = check end
   end
   return sound
end

function AQT:QuestLogUpdate(...)
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
	    Quest:New({title = qTitle, level = qLevel, tag = qTag, complete = qComplete, id = qID, header = currentHeader, timer = timer})
	 else 
	    local q = QuestCache[qID]
	    local sound = q:Update(timer)
	    if sound and not playSound then playSound = sound -- true, quest completed
	    elseif sound == false and not playSound then playSound = sound -- false, objective completed
	    end -- else it's nil, nothing completed
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

   if playSound then -- quest complete
      if st.cfg.playCompletionSound then
	 if st.cfg.useFactionCompletionSound then
	    if UnitFactionGroup("player") == "Alliance" then sound = "Peasant: Job's Done"
	    else sound = "Peon: Work Complete" end -- Should only get here if the player is Horde. Otherwise, the horde is more awesome anyway.
	 else sound = st.cfg.completionSoundName end
      end
   elseif playSound == false then -- objective complete
      if st.cfg.playObjectiveSound then
	 if st.cfg.useFactionObjectiveSound then
	    if UnitFactionGroup("player") == "Alliance" then sound = "Peasant: Ready to Work"
	    else sound = "Peon: Ready to Work" end -- default to horde, as it should be!
	 else sound = st.cfg.objectiveSound end
      end
   end

   if sound then PlaySoundFile(LSM:Fetch("sound", sound)) end

   Title.quests = questentries
   st.gui.title:UpdateText()
end

function AQT:PlayerLevelUp()
   local function Update()
      for k,v in pairs(QuestCache) do if v.uiObject then v.uiObject:UpdateText() end end
   end
   C_Timer.After(1, Update)
end

function AQT:ZoneChangedNewArea()
   st.gui.title:Sort()
   if st.cfg.automaticCollapseExpand then for k,v in pairs(HeaderCache) do v:TestCollapsedState() end end
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

function AQT:Event_ChatMsgSystem(msg)
   local faction,change
   -- Yes, I'll be repeating myself a bit below, but.. eh, I probably have to, anyway. If only because it's either increase or decrease. Uh. Yes, I'm slightly tired at the moment.
   if msg:match("^" .. FACTION_STANDING_DECREASED .. "$") then
      faction,change = msg:match("^" .. FACTION_STANDING_DECREASED .. "$")
      change = -change
   elseif msg:match("^" .. FACTION_STANDING_INCREASED .. "$") then faction,change = msg:match("^" .. FACTION_STANDING_INCREASED .. "$")
   else return end

   if not factionCache[faction] then return end

   local fcf = factionCache[faction]
   fcf.raw = fcf.raw + change
   fcf.relative = fcf.relative + change

   if fcf.relative < 0 then fcf.standing = fcf.standing - 1 end

   local max = 0

   if fcf.standing == 1 then max = 36000 -- Hated
   elseif fcf.standing == 2 then max = 3000 -- Hostile
   elseif fcf.standing == 3 then max = 3000 -- Unfriendly
   elseif fcf.standing == 4 then max = 3000 -- Neutral
   elseif fcf.standing == 5 then max = 6000 -- Friendly
   elseif fcf.standing == 6 then max = 12000 -- Honored
   elseif fcf.standing == 7 then max = 21000 -- Revered
   else max = 0 end -- Exalted. Assume it's at 8 if none of the others.

   if fcf.relative > max then
      fcf.standing = max
      fcf.relative = fcf.relative - max
   end

   if fcf.relative < 0 then fcf.relative = max + fcf.relative end -- Yes, we need to check if this is < 0 again, but it's better than the alternative of doing the longer chain again.

   if fcf.objectives then
      for k,v in ipairs(fcf.objectives) do v:Update() end
   end
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
