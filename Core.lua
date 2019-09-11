local _,st = ...

local AQT = LibStub("AceAddon-3.0"):NewAddon("AQT", "AceEvent-3.0", "LibSink-2.0")
local LSM = LibStub("LibSharedMedia-3.0")
local Prism = LibStub("LibPrism-1.0")

LSM:Register("sound", "Peasant: Job's Done", [[Interface\AddOns\AQT\Sounds\Peasant_work_done.mp3]])
LSM:Register("sound", "Peasant: Ready to Work", [[Sound\Creature\Peasant\PeasantReady1.ogg]])
LSM:Register("sound", "Peon: Ready to Work", [[Sound\Creature\Peon\PeonReady1.ogg]])
LSM:Register("sound", "Peon: Work Complete", [[Sound\Creature\Peon\PeonBuildingComplete1.ogg]])
LSM:Register("sound", "Peon: Work Work", [[Sound\Creature\Peon\PeonYes3.ogg]])

local tinsert = table.insert

function AQT:OnInitialize()
end

function AQT:OnEnable()
   st.gui:OnEnable()
   self:RegisterEvent("QUEST_LOG_UPDATE", "QuestLogUpdate")
   self:RegisterEvent("PLAYER_LEVEL_UP", "PlayerLevelUp")
end

function AQT:OnDisable()
end

local hooks = {
   "AbandonQuest",
   "GetQuestReward",
   "SetAbandonQuest",
}

local QuestCache = {}
local HeaderCache = {}

function AQT:AddQuest(header, index)
   local qTitle,qLevel,qTag,qHeader,qCollapsed,qComplete,qFreq,qID = GetQuestLogTitle(index)
   if QuestCache[qID] then error("Attempting to add quest that is already cached.") end
   if not HeaderCache[header] then error("Unknown header: " .. header) end

   QuestCache[qID] = {
      uiObject = HeaderCache[header].uiObject:New(),
      title = qTitle,
      level = qLevel,
      tag = qTag,
      complete = qComplete,
      objectives = {},
   }
   self:SetQuestTitle(qID)
   self:CheckObjectives(index)
   HeaderCache[header].uiObject:Sort()
end

function AQT:SetQuestTitle(id)
   local q = QuestCache[id]
   local c = GetQuestDifficultyColor(q.level)
   local str = "|cff%02x%02x%02x[%d%s] " .. q.title .. "|r"
   local tag
   if not q.tag then tag = ""
   else tag = q.tag:sub(1,1) end
   q.uiObject.text:SetText(str:format(c.r*255, c.g*255, c.b*255, q.level, tag))
   if q.complete then
      if q.complete < 0 then
	 q.uiObject.button:SetNormalTexture([[Interface\RAIDFRAME\ReadyCheck-NotReady]])
      elseif q.complete > 0 then
	 q.uiObject.button:SetNormalTexture([[Interface\RAIDFRAME\ReadyCheck-Ready]])
      end
      q.uiObject.button:Show()
   end
   q.uiObject:UpdateSize(true)
end

function AQT:RemoveQuest(id)
   local q = QuestCache[id]
-- Should be redundant, since it will recurse regardless.
--   for k,v in pairs(q.objectives) do
--      if v.uiObject then v.uiObject:Release() end
--   end
   q.uiObject:Release()
   QuestCache[id] = nil
end

function AQT:CheckQuestForUpdates(index)
   local qTitle,qLevel,qTag,qHeader,qCollapsed,qComplete,qFreq,qID = GetQuestLogTitle(index)
   local q = QuestCache[qID]
   local sound = nil
   if qComplete then
      for k,v in pairs(q.objectives) do
	 if v.uiObject then
	    v.uiObject:Release()
	    v.uiObject = nil
	 end
      end
      if not q.complete then
	 sound = true
	 self:Pour("Quest Complete: " .. qTitle, 0, 1, 0)
      end
   end
   if GetNumQuestLeaderBoards(index) == 0 then qComplete = 1 end -- Special handling
   q.title = qTitle
   q.level = qLevel
   q.complete = qComplete
   self:SetQuestTitle(qID)
   if not qComplete then sound = self:CheckObjectives(index) end
   return sound
end

function AQT:CheckObjectives(index) --!!!RE!!! Did most of this while my mind was all kinds of mushy, so should probably make sure to look over all of this.
   local qTitle,qLevel,qTag,qHeader,qCollapsed,qComplete,qFreq,qID = GetQuestLogTitle(index)
   local sound
   local q = QuestCache[qID]

   for i = 1, GetNumQuestLeaderBoards(index) do
      local oText,oType,complete = GetQuestLogLeaderBoard(i, index)
      local text,have,need
      local countertext
      local cstring,r,g,b
      local pour

      if oType == "monster" then
	 text,have,need = string.match(oText, "^" .. string.gsub(string.gsub(QUEST_MONSTERS_KILLED, "%%(s)", "(.+)"), "%%(d)", "(%%d+)") .. "$")
	 if not have then -- Some of these objectives apparently do not follow this string pattern.
	    text,have,need = string.match(oText, "^(.+): (%d+)/(%d+)$")
	 end
	 if not have or not need then error("STILL can't parse the damn string? Figure out what's wrong.") end --!!!RE!!! Remove this if this error isn't thrown at some point soon.
      elseif oType == "item" then
	 text,have,need = string.match(oText, "^" .. string.gsub(string.gsub(QUEST_ITEMS_NEEDED, "%%(s)", "(.+)"), "%%(d)", "(%%d+)") .. "$")
      elseif oType == "object" then
	 text,have,need = string.match(oText, "^" .. string.gsub(string.gsub(QUEST_OBJECTS_FOUND, "%%(s)", "(.+)"), "%%(d)", "(%%d+)") .. "$")
      elseif oType == "reputation" then
	 text,have,need = string.match(oText, "^" .. string.gsub(QUEST_FACTION_NEEDED, "%%(s)", "(.+)") .. "$")
	 --!!!RE!!! Return to this and see if we can fetch actual numerical values for string colourization later.
	 local cstring = "|cff" .. (complete and "00ff" or "ff00") .. "00"
	 countertext = cstring .. have:gsub(1,1) .. "/" .. need:gsub(1,1) .. "|r"
	 have,need = (complete and 1 or 0),1 -- Not sure this will be needed, actually, since we've already colourized.
      elseif oType == "event" then
	 have,need = (complete and 1 or 0),1
	 countertext = ""
	 local cstring = "|cff" .. (complete and "00ff" or "ff00") .. "00"
	 text = cstring .. oText .. "|r"
      else
	 print("AQT:CheckObjectives(): Unknown objective type '" .. oType .. "'. Falling back to default parsing with this debug info.")
	 have,need = (complete and 1 or 0),1
	 local cstring = "|cff" .. (complete and "00ff" or "ff00") .. "00"
	 text = "(" .. oType .. ")" .. cstring .. oText .. "|r"
      end

      if q.objectives[i] then
	 local o = q.objectives[i]
	 local pour
	 if not o.complete and complete then
	    if o.uiObject then
	       o.uiObject:Release()
	       o.uiObject = nil
	    end
	    sound = false
	    pour = true
	    r,g,b = 0,1,0
	 elseif o.have ~= have and not complete then
	    pour = true
	    cstring,r,g,b = Prism:Gradient("hsv", 1, 0, 0, 1, 0, 0, have/need)
	 elseif not complete and o.text ~= text or o.need ~= need then
	    cstring,r,g,b = Prism:Gradient("hsv", 1, 0, 0, 1, 0, 0, have/need)
	 end
	 o.have = have
	 o.need = need
	 o.complete = complete
	 if pour then self:Pour(text .. ": " .. tostring(have) .. "/" .. tostring(need), r, g, b) end
      else
	 q.objectives[i] = {
	    have = have,
	    need = need,
	    complete = complete,
	 }
	 if not complete then
	    q.objectives[i].uiObject = q.uiObject:New()
	    cstring = Prism:Gradient("hsv", 1, 0, 0, 1, 0, 0, have/need)
	 end
      end
      if q.objectives[i].uiObject and cstring then
	 q.objectives[i].uiObject.text:SetText("|cff" .. cstring .. tostring(text) .. "|r")
	 q.objectives[i].uiObject.counter:SetText(countertext and countertext or ("|cff" .. cstring .. tostring(have) .. "/" .. tostring(need)))
	 q.objectives[i].uiObject:UpdateSize(true)
      elseif cstring then
	 print("uiObject expected but not found. quest " .. qTitle .. ", index " .. tostring(i))
      end
   end
   return sound
--[[
	["QUEST_CRITERIA_TREE_OBJECTIVE"] = "%2$llu/%3$llu %1$s",
	["QUEST_CRITERIA_TREE_OBJECTIVE_NOPROGRESS"] = "%1$s",
	["QUEST_FACTION_NEEDED"] = "%s:  %s / %s",
	["QUEST_FACTION_NEEDED_NOPROGRESS"] = "%2$s %1$s",
	["QUEST_INTERMEDIATE_ITEMS_NEEDED"] = "%s: (%d)",
	["QUEST_ITEMS_NEEDED"] = "%s: %d/%d",
	["QUEST_ITEMS_NEEDED_NOPROGRESS"] = "%2$d x %1$s",
	["QUEST_MONSTERS_KILLED"] = "%s slain: %d/%d",
	["QUEST_MONSTERS_KILLED_NOPROGRESS"] = "%2$d x %1$s",
	["QUEST_OBJECTIVE_PROGRESS_BAR"] = "%d%%",
	["QUEST_OBJECTS_FOUND"] = "%s: %d/%d",
	["QUEST_OBJECTS_FOUND_NOPROGRESS"] = "%2$d x %1$s",
	["QUEST_PLAYERS_DEFEATED_PET_BATTLE"] = "%1$d/%2$d Players defeated in pet battle",
	["QUEST_PLAYERS_DEFEATED_PET_BATTLE_NOPROGRESS"] = "%d x Players defeated in pet battle",
	["QUEST_PLAYERS_KILLED"] = "%1$d/%2$d %3$s Players slain",
	["QUEST_PLAYERS_KILLED_NOPROGRESS"] = "%2$s Players x %1$d",
	["QUEST_PROGRESS_NEEDED"] = "Progress: %1$d",
	["QUEST_SPELL_NEEDED"] = "Learn Spell: %s",
	["QUEST_SPELL_REWARD_TYPE_AURA"] = 4,
	["QUEST_SPELL_REWARD_TYPE_SPELL"] = 5,
	["QUEST_SPELL_REWARD_TYPE_TRADESKILL_SPELL"] = 2,
	["QUEST_SPELL_REWARD_TYPE_UNLOCK"] = 6,
	["QUEST_TAG_DUNGEON_TYPES"] = {
		[88] = true,
		[89] = true,
		[62] = true,
		[81] = true,
	},
	["QUEST_TYPE_SCENARIO"] = 98,
]]--
end

function AQT:AddHeader(name)
   if HeaderCache[name] then error ("Attempting to add header that is already cached.") end
   local header = {}
   HeaderCache[name] = header
   header.uiObject = st.gui.title:New()
   header.uiObject.button.isClickButton = true
   header.uiObject.text:SetText(name)
   header.complete = 0
   header.uiObject:UpdateSize(true)
   st.gui.title:Sort()
end

function AQT:RemoveHeader(name)
   HeaderCache[name].uiObject:Release()
   HeaderCache[name] = nil
end

function AQT:UpdateHeaders()
   for k,v in pairs(HeaderCache) do
      local h,w = v.uiObject:GetSize()
      local colorstring = Prism:Gradient("hsv", 1, 0, 0, 1, 0, 0, v.complete/#v.uiObject.children)
      v.uiObject.counter:SetText("|cff" .. colorstring .. tostring(v.complete) .. "/" .. tostring(#v.uiObject.children))
   end
end

function AQT:ExpandHeaders(collapsedheaders)
   -- We may end up triggering the event a few times while processing, so we'll want to avoid unneccessary superfluous calls.
   self:UnregisterEvent("QUEST_LOG_UPDATE")
   -- Start by expanding any collapsed headers, so we can fetch info about their quests.
   local i = 1
   while GetQuestLogTitle(i) do
      local qTitle,qLevel,qTag,qHeader,qCollapsed = GetQuestLogTitle(i)
      if qCollapsed then
	 tinsert(collapsedheaders, i)
	 ExpandQuestHeader(i)
      end
      i = i + 1
   end
end

function AQT:CollapseHeaders(collapsedheaders)
   -- Collapse any previously expanded headers.
   for i = #collapsedheaders, 1, -1 do
      CollapseQuestHeader(collapsedheaders[i])
   end
   -- Start reacting to the event firing again.
   self:RegisterEvent("QUEST_LOG_UPDATE", "QuestLogUpdate") -- This seems to still reenable it too soon. Any time a header is collapsed, QLU keeps firing indefinitely.
end

function AQT:QuestLogUpdate(...)
   local collapsedheaders = {}
   self:ExpandHeaders(collapsedheaders)

   -- Find any updated quests or new quests/headers.
   local entries,questentries = GetNumQuestLogEntries()
   local localQuestCache = {}
   local localHeaderCache = {}
   local currentHeader = nil
   local count = 0
   local playSound = nil
   local sound
   for i = 1, entries do
      local qTitle,qLevel,qTag,qHeader,qCollapsed,qComplete,qFreq,qID = GetQuestLogTitle(i)

      if qHeader then
	 localHeaderCache[qTitle] = true
	 -- Separate if rather than "and" so we can use else.
	 if not HeaderCache[qTitle] then self:AddHeader(qTitle) end
	 currentHeader = qTitle
	 HeaderCache[qTitle].complete = 0
      else
	 count = count + 1
	 if qComplete then HeaderCache[currentHeader].complete = HeaderCache[currentHeader].complete + 1 end
	 localQuestCache[qID] = true
	 if not QuestCache[qID] then self:AddQuest(currentHeader, i)
	 else 
	    local sound = self:CheckQuestForUpdates(i)
	    if sound and not playSound then playSound = sound -- true, quest completed
	    elseif sound == false and not playSound then playSound = sound -- false, objective completed
	    end -- else it's nil, nothing completed
	 end
      end
   end
   -- Find any removed quests or headers.
   for k,v in pairs(QuestCache) do
      if not localQuestCache[k] then self:RemoveQuest(k) end
   end
   for k,v in pairs(HeaderCache) do
      if not localHeaderCache[k] then self:RemoveHeader(k) end
   end

   if playSound then -- quest complete
      if UnitFactionGroup("player") == "Alliance" then sound = "Peasant: Job's Done"
      else sound = "Peon: Work Complete" end -- Should only get here if the player is Horde. Otherwise, the horde is more awesome anyway.
   elseif playSound == false then -- objective complete
      if UnitFactionGroup("player") == "Alliance" then sound = "Peasant: Ready to Work"
      else sound = "Peon: Ready to Work" end -- default to horde, as it should be!
   end

   if sound then PlaySoundFile(LSM:Fetch("sound", sound)) end

   self:CollapseHeaders(collapsedheaders)
   self:UpdateHeaders() -- Simplest way of doing it. May want to revisit this later.
   local colorstring = Prism:Gradient("hsv", 0, 1, 1, 0, 0, 0, count/MAX_QUESTLOG_QUESTS)
   st.gui.title.counter:SetText("|cff" .. colorstring .. tostring(count) .. "/" .. tostring(MAX_QUESTLOG_QUESTS) .. "|r")
end

function AQT:PlayerLevelUp(...)
   local headers = {}
   self:ExpandHeaders(headers)
   for k,v in pairs(QuestCache) do self:SetQuestTitle(k) end
   self:CollapseHeaders(headers)
end
