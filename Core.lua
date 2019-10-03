local _,st = ...

local AQT = LibStub("AceAddon-3.0"):NewAddon("AQT", "AceEvent-3.0", "AceTimer-3.0", "LibSink-2.0")
local LSM = LibStub("LibSharedMedia-3.0")
local Prism = LibStub("LibPrism-1.0")

local L = st.L

LSM:Register("sound", "Peasant: Job's Done", [[Interface\AddOns\AQT\Sounds\Peasant_work_done.mp3]])
LSM:Register("sound", "Peasant: Ready to Work", [[Sound\Creature\Peasant\PeasantReady1.ogg]])
LSM:Register("sound", "Peon: Ready to Work", [[Sound\Creature\Peon\PeonReady1.ogg]])
LSM:Register("sound", "Peon: Work Complete", [[Sound\Creature\Peon\PeonBuildingComplete1.ogg]])
LSM:Register("sound", "Peon: Work Work", [[Sound\Creature\Peon\PeonYes3.ogg]])

local tinsert,tremove = table.insert,table.remove

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
      sortConfigurable = true,
      testTable = {1,2,3},
      sortFields = {
	 name = L.Title,
	 IsCurrentZone = L["Matches Current Zone"],
      },
   }
)

Header.sortFields = {
   name = L.Title,
   IsCurrentZone = L["Matches Current Zone"],
}

local Objective = baseObject:New(
   {
      name = "Objective",
   }
)

local Quest = baseObject:New(
   {
      name = "Quest",
      sortConfigurable = true,
      sortFields = {
	 complete = L.Completion,
	 level = L.Level,
	 tag = L.Tag,
	 title = L.Title,
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

function AQT:OnEnable()
   QuestWatchFrame:SetScript("OnShow", function(self)
				if st.cfg.hideQuestWatch then self:Hide() end
   end)

   if st.cfg.hideQuestWatch then QuestWatchFrame:Hide() end

   st.gui:OnEnable()
   self:RegisterEvent("QUEST_LOG_UPDATE", "QuestLogUpdate")
   self:RegisterEvent("PLAYER_LEVEL_UP", "PlayerLevelUp")
   self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ResortHeaders")
   self:SuppressionCheck()
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

function Header:IsCurrentZone()
   return (GetRealZoneText() == self.name)
end

function Header:New(o)
   if not o.name then error("Header:New() requires header name to be set.") end
   setmetatable(o, self)
   if not o.quests then o.quests = {} end
   HeaderCache[o.name] = o
   return o
end

--[[ Never called.
function Header:Remove()
   if #self.quests > 0 then error("Header:Remove(): '" .. self.name .. "': trying to remove header that still has quests attached.") end
   if self.uiObject then self.uiObject:Release() end
   HeaderCache[self.name] = nil
end
]]--

function Header:Update() -- Probably redundant after the latest abstraction fix. Should be able to move these things elsewhere without breaking abstraction.
   self.TitleText = self.name
   if #self.quests > 0 then
      if not self.uiObject then
	 self:CreateUIObject()
	 self.uiObject:Update()
      end
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
      text,have,need = string.match(oText, "^" .. string.gsub(string.gsub(string.gsub(QUEST_MONSTERS_KILLED, "%%%d($)", "%%"), "%%(s)", "(.+)"), "%%(d)", "(%%d+)") .. "$")
      if not have then -- Some of these objectives apparently do not follow this string pattern.
	 text,have,need = string.match(oText, "^(.+): (%d+)/(%d+)$")
      end
   elseif oType == "item" then
      text,have,need = string.match(oText, "^" .. string.gsub(string.gsub(string.gsub(QUEST_ITEMS_NEEDED, "%%%d($)", "%%"), "%%(s)", "(.+)"), "%%(d)", "(%%d+)") .. "$")
   elseif oType == "object" then
      text,have,need = string.match(oText, "^" .. string.gsub(string.gsub(string.gsub(QUEST_OBJECTS_FOUND, "%%%d($)", "%%"), "%%(s)", "(.+)"), "%%(d)", "(%%d+)") .. "$")
   elseif oType == "reputation" then
      text,have,need = string.match(oText, "^" .. string.gsub(string.gsub(QUEST_FACTION_NEEDED, "%%%d($)", "%%"),"%%(s)", "(.+)") .. "$")
      --!!!RE!!! Return to this and see if we can fetch actual numerical values for string colourization later.
      countertext = have:sub(1,1) .. "/" .. need:sub(1,1)
      have,need = (complete and 1 or 0),1
   elseif oType == "event" then
      have,need = (complete and 1 or 0),1
      countertext = ""
      text = oText
   else
      print("AQT:CheckObjectives(): Unknown objective type '" .. oType .. "'. Falling back to default parsing with this debug info.")
      have,need = (complete and 1 or 0),1
      text = "(" .. oType .. ")" .. cstring .. oText .. "|r"
   end

   if self.text ~= text or self.have ~= have or self.need ~= need or self.complete ~= complete then update = true end

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
   self.counterString = countertext and countertext or (tostring(have) .. "/" .. tostring(need))
   self.index = oIndex

   if self.complete then
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
   o:Update()
   if st.cfg.trackAll then o:Track() end
   return o
end

function Quest:Remove()
   if self.uiObject then self:Untrack() end
   for k,v in ipairs(self.header.quests) do
      if v == self then tremove(self.header.quests, k) end
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

   self.uiObject = parent:New(self)
   self:Update() -- Temporary fix
   self.header:Update()
   self.uiObject:Update()
end

function Quest:Untrack()
   if not self.uiObject then error("Attempting to untrack untracked quest, '" .. self.title .. "'.") end

   for i,v in ipairs(self.header.quests) do
      if self == v then tremove(self.header.quests, i) end
   end

   self.uiObject:Release()
   self.header:Update()
end

function Quest:Update()
   local index = GetQuestLogIndexByID(self.id)
   if not index then error("Quest:Update(): Unable to find quest '" .. self.title .. "' in log.") end

   local qTitle,qLevel,qTag,qHeader,qCollapsed,qComplete = GetQuestLogTitle(index)
   local sound = nil
   local update = nil
   local title

   if self.title ~= qTitle or self.level ~= qLevel or self.tag  ~= qTag or self.complete ~= qComplete then update = true end

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

   if not qComplete then sound = self:UpdateObjectives() end
   if update then self.uiObject:Update() end
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
   while i do
      local qTitle,qLevel,qTag,qHeader,qCollapsed,qComplete,qFreq,qID = GetQuestLogTitle(i)

      if not qTitle then i = nil
      else
	 if currentHeader and i > entries then currentHeader = nil end
	 if qHeader then
	    localHeaderCache[qTitle] = true
	    -- Separate if rather than "and" so we can use else.
	    if not HeaderCache[qTitle] then currentHeader = Header:New({name = qTitle}) else currentHeader = HeaderCache[qTitle] end
	 else
	    localQuestCache[qID] = true
	    if not QuestCache[qID] then
	       Quest:New({title = qTitle, level = qLevel, tag = qTag, complete = qComplete, id = qID, header = currentHeader})
	    else 
	       local q = QuestCache[qID]
	       local sound = q:Update()
	       if sound and not playSound then playSound = sound -- true, quest completed
	       elseif sound == false and not playSound then playSound = sound -- false, objective completed
	       end -- else it's nil, nothing completed
	    end
	 end
	 i = i + 1
      end
   end
   -- Find any removed quests or headers.
   for k,v in pairs(QuestCache) do
      if not localQuestCache[k] then v:Remove() end
   end
--   for k,v in pairs(HeaderCache) do
--      if not localHeaderCache[k] then self:RemoveHeader(k) end
--   end

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
   self:ScheduleTimer("PlayerLevelUpUpdate", 1)
end

function AQT:PlayerLevelUpUpdate()
   for k,v in pairs(QuestCache) do if v.uiObject then v.uiObject:UpdateText() end end
end

function AQT:ResortHeaders()
   st.gui.title:Sort()
end

-- This is ugly, but AceHook didn't seem to deliver quite according to documentation.

local function errorFrameAddMessage(self, msg, r, g, b, a)
   if r == 1 and g == 1 and b == 0 and not msg:match("^|cff") then -- All relevant default quest messages are in yellow, and should have no colour string. This should be a good first filter for anything we don't want to suppress.
      if msg == QUEST_COMPLETE then return -- Don't think this is in UIErrorsFrame, but just in case?
      elseif msg == ERR_QUEST_UNKNOWN_COMPLETE then return
      elseif msg:match("^" .. string.gsub(string.gsub(string.gsub(QUEST_MONSTERS_KILLED, "%%%d($)", "%%"), "%%(s)", "(.+)"), "%%(d)", "(%%d+)") .. "$") then return
      elseif msg:match("^" .. string.gsub(string.gsub(string.gsub(QUEST_ITEMS_NEEDED, "%%%d($)", "%%"), "%%(s)", "(.+)"), "%%(d)", "(%%d+)") .. "$") then return
      elseif msg:match("^" .. string.gsub(string.gsub(string.gsub(QUEST_OBJECTS_FOUND, "%%%d($)", "%%"), "%%(s)", "(.+)"), "%%(d)", "(%%d+)") .. "$") then return
      elseif msg:match("^" .. string.gsub(string.gsub(QUEST_FACTION_NEEDED, "%%%d($)", "%%"),"%%(s)", "(.+)") .. "$") then return
      elseif msg:match("^" .. string.gsub(string.gsub(ERR_QUEST_OBJECTIVE_COMPLETE_S, "%%%d($)", "%%"), "%%(s)", "(.+)") .. "$") then return end
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
