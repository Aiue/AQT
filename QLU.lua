function QuestLog_Update(self)
	local numEntries, numQuests = GetNumQuestLogEntries();
	if ( numEntries == 0 ) then
		EmptyQuestLogFrame:Show();
		QuestLogFrameAbandonButton:Disable();
		QuestLogFrame.hasTimer = nil;
		QuestLogDetailScrollFrame:Hide();
		QuestLogExpandButtonFrame:Hide();
	else
		EmptyQuestLogFrame:Hide();
		QuestLogFrameAbandonButton:Enable();
		QuestLogDetailScrollFrame:Show();
		QuestLogExpandButtonFrame:Show();
	end

	-- Update Quest Count
	QuestLogQuestCount:SetText(format(QUEST_LOG_COUNT_TEMPLATE, numQuests, MAX_QUESTLOG_QUESTS));
	QuestLogCountMiddle:SetWidth(QuestLogQuestCount:GetWidth());

	-- ScrollFrame update
	FauxScrollFrame_Update(QuestLogListScrollFrame, numEntries, QUESTS_DISPLAYED, QUESTLOG_QUEST_HEIGHT, nil, nil, nil, QuestLogHighlightFrame, 293, 316 )
	
	-- Update the quest listing
	QuestLogHighlightFrame:Hide();
	
	local questIndex, questLogTitle, questTitleTag, questNumGroupMates, questNormalText, questHighlight, questCheck;
	local questLogTitleText, level, questTag, isHeader, isCollapsed, isComplete, color;
	local numPartyMembers, partyMembersOnQuest, tempWidth, textWidth;
	for i=1, QUESTS_DISPLAYED, 1 do
		questIndex = i + FauxScrollFrame_GetOffset(QuestLogListScrollFrame);
		questLogTitle = _G["QuestLogTitle"..i];
		questTitleTag = _G["QuestLogTitle"..i.."Tag"];
		questNumGroupMates = _G["QuestLogTitle"..i.."GroupMates"];
		questCheck = _G["QuestLogTitle"..i.."Check"];
		questNormalText = _G["QuestLogTitle"..i.."NormalText"];
		questHighlight = _G["QuestLogTitle"..i.."Highlight"];
		if ( questIndex <= numEntries ) then
			questLogTitleText, level, questTag, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling = GetQuestLogTitle(questIndex);
			if ( isHeader ) then
				if ( questLogTitleText ) then
					questLogTitle:SetText(questLogTitleText);
				else
					questLogTitle:SetText("");
				end
				
				if ( isCollapsed ) then
					questLogTitle:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up");
				else
					questLogTitle:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up"); 
				end
				questHighlight:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight");
				questNumGroupMates:SetText("");
				questCheck:Hide();
			else
				questLogTitle:SetText("  "..(questLogTitleText or ""));
				--Set Dummy text to get text width *SUPER HACK*
				QuestLogDummyText:SetText("  "..questLogTitleText);

				questLogTitle:SetNormalTexture("");
				questHighlight:SetTexture("");

				-- If not a header see if any nearby group mates are on this quest
				partyMembersOnQuest = 0;
				for j=1, GetNumSubgroupMembers() do
					if ( IsUnitOnQuest(questIndex, "party"..j) ) then
						partyMembersOnQuest = partyMembersOnQuest + 1;
					end
				end
				if ( partyMembersOnQuest > 0 ) then
					questNumGroupMates:SetText("["..partyMembersOnQuest.."]");
				else
					questNumGroupMates:SetText("");
				end
			end
			-- Save if its a header or not
			questLogTitle.isHeader = isHeader;

			-- Set the quest tag
			if ( isComplete and isComplete < 0 ) then
				questTag = FAILED;
			elseif ( isComplete and isComplete > 0 ) then
				questTag = COMPLETE;
			end
			if ( questTag ) then
				questTitleTag:SetText("("..questTag..")");
				-- Shrink text to accomdate quest tags without wrapping
				tempWidth = 275 - 15 - questTitleTag:GetWidth();
				
				if ( QuestLogDummyText:GetWidth() > tempWidth ) then
					textWidth = tempWidth;
				else
					textWidth = QuestLogDummyText:GetWidth();
				end
				
				questNormalText:SetWidth(tempWidth);
				
				-- If there's quest tag position check accordingly
				questCheck:Hide();
				if ( IsQuestWatched(questIndex) ) then
					if ( questNormalText:GetWidth() + 24 < 275 ) then
						questCheck:SetPoint("LEFT", questLogTitle, "LEFT", textWidth+24, 0);
					else
						questCheck:SetPoint("LEFT", questLogTitle, "LEFT", textWidth+10, 0);
					end
					questCheck:Show();
				end
			else
				questTitleTag:SetText("");
				-- Reset to max text width
				if ( questNormalText:GetWidth() > 275 ) then
					questNormalText:SetWidth(260);
				end

				-- Show check if quest is being watched
				questCheck:Hide();
				if ( IsQuestWatched(questIndex) ) then
					if ( questNormalText:GetWidth() + 24 < 275 ) then
						questCheck:SetPoint("LEFT", questLogTitle, "LEFT", QuestLogDummyText:GetWidth()+24, 0);
					else
						questCheck:SetPoint("LEFT", questNormalText, "LEFT", questNormalText:GetWidth(), 0);
					end
					questCheck:Show();
				end
			end

			-- Color the quest title and highlight according to the difficulty level
			local playerLevel = UnitLevel("player");
			if ( isHeader ) then
				color = QuestDifficultyColors["header"];
			else
				color = GetQuestDifficultyColor(level);
			end
			questLogTitle:SetNormalFontObject(color.font);
			questTitleTag:SetTextColor(color.r, color.g, color.b);
			questNumGroupMates:SetTextColor(color.r, color.g, color.b);
			questLogTitle.r = color.r;
			questLogTitle.g = color.g;
			questLogTitle.b = color.b;
			questLogTitle:Show();

			-- Place the highlight and lock the highlight state
			if ( QuestLogFrame.selectedButtonID and GetQuestLogSelection() == questIndex ) then
				QuestLogSkillHighlight:SetVertexColor(questLogTitle.r, questLogTitle.g, questLogTitle.b);
				QuestLogHighlightFrame:SetPoint("TOPLEFT", "QuestLogTitle"..i, "TOPLEFT", 0, 0);
				QuestLogHighlightFrame:Show();
				questTitleTag:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
				questNumGroupMates:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
				questLogTitle:LockHighlight();
			else
				questLogTitle:UnlockHighlight();
			end

		else
			questLogTitle:Hide();
		end
	end

	-- Set the expand/collapse all button texture
	local numHeaders = 0;
	local notExpanded = 0;
	-- Somewhat redundant loop, but cleaner than the alternatives
	for i=1, numEntries, 1 do
		local index = i;
		local questLogTitleText, level, questTag, isHeader, isCollapsed = GetQuestLogTitle(i);
		if ( questLogTitleText and isHeader ) then
			numHeaders = numHeaders + 1;
			if ( isCollapsed ) then
				notExpanded = notExpanded + 1;
			end
		end
	end
	-- If all headers are not expanded then show collapse button, otherwise show the expand button
	if ( notExpanded ~= numHeaders ) then
		QuestLogCollapseAllButton.collapsed = nil;
		QuestLogCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up");
	else
		QuestLogCollapseAllButton.collapsed = 1;
		QuestLogCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up");
	end

	-- Update Quest Count
	QuestLogQuestCount:SetText(format(QUEST_LOG_COUNT_TEMPLATE, numQuests, MAX_QUESTLOG_QUESTS));
	QuestLogCountMiddle:SetWidth(QuestLogQuestCount:GetWidth());

	-- If no selection then set it to the first available quest
	if ( GetQuestLogSelection() == 0 ) then
		QuestLog_SetFirstValidSelection();
	end

	-- Determine whether the selected quest is pushable or not
	if ( numEntries == 0 ) then
		QuestFramePushQuestButton:Disable();
	elseif ( GetQuestLogPushable() and IsInGroup() ) then
		QuestFramePushQuestButton:Enable();
	else
		QuestFramePushQuestButton:Disable();
	end
end
