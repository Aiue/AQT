std = "lua51"
max_line_length = false
exclude_files = {
   "LocaleParser.lua",
   "libs/utf8.lua",
}

globals = {
   "AceGUIWidgetLSMlists",
   "AQTCFG",
   "AQTParent",
   "BackdropTemplateMixin",
   "C_Timer",
   "ChatEdit_GetActiveWindow",
   "ChatEdit_InsertLink",
   "ClassicQuestLog",
   "CreateFont",
   "CreateFrame",
   "date",
   "difftime",
   "ELITE",
   "ERR_QUEST_OBJECTIVE_COMPLETE_S",
   "ERR_QUEST_UNKNOWN_COMPLETE",
   "ExpandQuestHeader",
   "FACTION_STANDING_LABEL1",
   "FACTION_STANDING_LABEL2",
   "FACTION_STANDING_LABEL3",
   "FACTION_STANDING_LABEL4",
   "FACTION_STANDING_LABEL5",
   "FACTION_STANDING_LABEL6",
   "FACTION_STANDING_LABEL7",
   "FACTION_STANDING_LABEL8",
   "FauxScrollFrame_GetOffset",
   "FauxScrollFrame_SetOffset",
   "GameTooltip",
   "GetAbandonQuestItems",
   "GetAbandonQuestName",
   "GetLocale",
   "GetFactionInfo",
   "GetNumQuestLeaderBoards",
   "GetNumQuestLogEntries",
   "GetQuestDifficultyColor",
   "GetQuestIndexForTimer",
   "GetQuestLogIndexByID",
   "GetQuestLogLeaderBoard",
   "GetQuestLogQuestText",
   "GetQuestLogSelection",
   "GetQuestLogTitle",
   "GetQuestTimers",
   "GetRealZoneText",
   "hooksecurefunc",
   "IsAltKeyDown",
   "IsControlKeyDown",
   "IsInGroup",
   "IsInRaid",
   "IsShiftKeyDown",
   "IsQuestWatched",
   "L_CloseDropDownMenus",
   "L_Create_UIDropDownMenu",
   "L_EasyMenu",
   "LE_PARTY_CATEGORY_INSTANCE",
   "LibStub",
   "MAX_QUESTLOG_QUESTS",
   "PlaySoundFile",
   "QUEST_COMPLETE",
   "QUEST_FACTION_NEEDED",
   "QUEST_ITEMS_NEEDED",
   "QUEST_MONSTERS_KILLED",
   "QUEST_OBJECTS_FOUND",
   "QuestLog_SetSelection",
   "QuestLog_Update",
   "QuestLogEx",
   "QuestLogExFrame",
   "QuestLogFrame",
   "QuestLogListScrollFrame",
   "QuestLogListScrollFrameScrollBar",
   "QuestLogPushQuest",
   "QUESTS_DISPLAYED",
   "QuestTimerFrame",
   "QuestWatchFrame",
   "RAID",
   "RAID_CLASS_COLORS",
   "random",
   "RemoveQuestWatch",
   "SetAbandonQuest",
   "StaticPopup_Hide",
   "StaticPopup_Show",
   "StaticPopupDialogs",
   "time",
   "ToggleQuestLog",
   "TRACKER_HEADER_DUNGEON",
   "UIErrorsFrame",
   "UIParent",
   "UnitClass",
   "UnitFactionGroup",
   "UnitInParty",
   "UnitInRaid",
   "UnitName",
   "UnitLevel",

   -- Use by Blizzard code we're fixing.
   "COMPLETE",
   "EmptyQuestLogFrame",
   "FAILED",
   "FauxScrollFrame_Update",
   "format",
   "GetNumSubgroupMembers",
   "GetQuestLogPushable",
   "HIGHLIGHT_FONT_COLOR",
   "IsUnitOnQuest",
   "QUEST_LOG_COUNT_TEMPLATE",
   "QUESTLOG_QUEST_HEIGHT",
   "QuestDifficultyColors",
   "QuestFramePushQuestButton",
   "QuestLog_SetFirstValidSelection",
   "QuestLogCollapseAll",
   "QuestLogCollapseAllButton",
   "QuestLogCountMiddle",
   "QuestLogDetailScrollFrame",
   "QuestLogDummyText",
   "QuestLogExpandButtonFrame",
   "QuestLogFrameAbandonButton",
   "QuestLogHighlightFrame",
   "QuestLogQuestCount",
   "QuestLogSkillHighlight",
}

ignore = {
   "211/L",
   "212", -- unused argument
}
