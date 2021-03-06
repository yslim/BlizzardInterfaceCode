function AddAutoCombatSpellToTooltip(tooltip, autoCombatSpell)
	local str;
	if (autoCombatSpell.icon) then
		str = CreateTextureMarkup(autoCombatSpell.icon, 64, 64, 16, 16, 0, 1, 0, 1, 0, 0);
	else
		str = "";
	end
	str = str .. " " .. autoCombatSpell.name;
	GameTooltip_AddColoredLine(tooltip, str, WHITE_FONT_COLOR);
	GameTooltip_AddBlankLineToTooltip(tooltip);
	if autoCombatSpell.cooldown > 0 then
		GameTooltip_AddColoredLine(tooltip, COVENANT_MISSIONS_COOLDOWN:format(autoCombatSpell.cooldown), WHITE_FONT_COLOR);
	end

	local wrap = true;
	GameTooltip_AddNormalLine(tooltip, autoCombatSpell.description, wrap);
end

---------------------------------------------------------------------------------
-- Covenant Mission Page Enemy Frame
---------------------------------------------------------------------------------
CovenantMissionPageEnemyMixin = { }

function CovenantMissionPageEnemyMixin:OnEnter()
	if (#self.autoCombatSpells > 0) then
		GameTooltip:SetOwner(self, "ANCHOR_NONE");
		GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMRIGHT", 0, 0);
		GameTooltip_SetTitle(GameTooltip, self.Name:GetText());
		
		for i = 1, #self.autoCombatSpells do
			GameTooltip_AddBlankLineToTooltip(GameTooltip);
			AddAutoCombatSpellToTooltip(GameTooltip, self.autoCombatSpells[i])
		end
		GameTooltip:Show();
	end
end

function CovenantMissionPageEnemyMixin:OnLeave()
	GameTooltip_Hide();
end

---------------------------------------------------------------------------------
-- Autospell Ability Tooltip Handlers
---------------------------------------------------------------------------------

function CovenantMissionAutoSpellAbilityTemplate_OnEnter(self)
	if ( not self.info ) then
		return; 
	end

	GameTooltip:SetOwner(self, "ANCHOR_NONE");
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMRIGHT", 0, 0);
	AddAutoCombatSpellToTooltip(GameTooltip, self.info);
	GameTooltip:Show();
end

function CovenantMissionAutoSpellAbilityTemplate_OnLeave()
	GameTooltip_Hide();
end

---------------------------------------------------------------------------------
-- Covenant Follower Tab Heal Button Handlers
---------------------------------------------------------------------------------

function CovenantMissionHealFollowerButton_OnClick(buttonFrame)
	local mainFrame = buttonFrame:GetParent();
	C_Garrison.RushHealFollower(mainFrame.followerID);
end

function CovenantMissionHealFollowerButton_OnEnter(buttonFrame)
	GameTooltip:SetOwner(buttonFrame, "ANCHOR_NONE");
	GameTooltip:SetPoint("TOPLEFT", buttonFrame, "BOTTOMRIGHT", 0, 0);
	GameTooltip_AddNormalLine(GameTooltip, buttonFrame.tooltip, wrap);
	GameTooltip:Show();
end

---------------------------------------------------------------------------------
-- Covenant Follower Tab Mixin
---------------------------------------------------------------------------------

CovenantFollowerTabMixin = {};

function CovenantFollowerTabMixin:OnUpdate()
	local SECONDS_BETWEEN_UPDATE = 1;
	local currentTime = GetTime();
	if (self.lastUpdate and (currentTime - self.lastUpdate) > SECONDS_BETWEEN_UPDATE) then 
		self.followerInfo.autoCombatantStats = C_Garrison.GetFollowerAutoCombatStats(self.followerID);
		self:UpdateCombatantStats(self.followerInfo);
		self.StatsFrame:Layout();
		self:UpdateHealCost();

		self.lastUpdate = GetTime();
	end
end

function CovenantFollowerTabMixin:UpdateValidSpellHighlightOnAbilityFrame()
end

function CovenantFollowerTabMixin:UpdateHealCost()	
	local followerStats = self.followerInfo.autoCombatantStats;
	self.HealFollowerButton.tooltip = nil;

	if not followerStats then
		self.HealFollowerButton:SetEnabled(false);
		return;
	end

	local buttonCost = ((followerStats.maxHealth - followerStats.currentHealth) / followerStats.maxHealth) * Constants.GarrisonConstsExposed.GARRISON_AUTO_COMBATANT_FULL_HEAL_COST;
	self.CostFrame.Cost:SetText(math.ceil(buttonCost));
	
	if (buttonCost == 0) then
		self.HealFollowerButton:SetEnabled(false);
		self.HealFollowerButton.tooltip = COVENANT_MISSIONS_HEAL_ERROR_FULL_HEALTH;
	else 
		local _, secondaryCurrency = C_Garrison.GetCurrencyTypes(GarrisonFollowerOptions[self.followerInfo.followerTypeID].garrisonType);
		local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(secondaryCurrency);
		if (buttonCost > currencyInfo.quantity) then 
			self.HealFollowerButton:SetEnabled(false);
			self.HealFollowerButton.tooltip = COVENANT_MISSIONS_HEAL_ERROR_RESOURCES;
		else
			self.HealFollowerButton:SetEnabled(true);
		end
	end
end

function CovenantFollowerTabMixin:GetStatsAnchorFrame()
	return self.StatsFrame;
end

function CovenantFollowerTabMixin:GetAbilitiesText()
	return self.StatsFrame.AbilitiesText;
end

function CovenantFollowerTabMixin:ShowFollower(followerID, followerList)

	local followerInfo = C_Garrison.GetFollowerInfo(followerID);
	local autoSpellAbilities = C_Garrison.GetFollowerAutoCombatSpells(followerID);
	local autoCombatantStats = C_Garrison.GetFollowerAutoCombatStats(followerID);
	local missionFrame = self:GetParent();

	self.followerID = followerID;
	self.ModelCluster.followerID = followerID;

	self:ShowFollowerModel(followerInfo);
	if (not followerInfo) then
		followerInfo = { };
		followerInfo.followerTypeID = missionFrame:GetFollowerList().followerType;
		followerInfo.quality = 1;
		followerInfo.abilities = { };
		followerInfo.unlockableAbilities = { };
		followerInfo.equipment = { };
		followerInfo.unlockableEquipment = { };
		followerInfo.combatAllySpellIDs = { };
	end

	if not autoSpellAbilities then
		autoSpellAbilities = {};
	end

	followerInfo.autoCombatantStats = autoCombatantStats;
	followerInfo.autoSpellAbilities = autoSpellAbilities;
	self.followerInfo = followerInfo;

	self.Name:SetText(followerInfo.name);
	self.ClassSpec:SetText(followerInfo.className);

	--Add in stats: hp, power, level, experience.
	self:UpdateCombatantStats(followerInfo);
	
	--Add in ability icons
	self:UpdateAutoSpellAbilities(followerInfo);

	self.StatsFrame:Layout();
	self.StatsFrame.AbilitiesText:SetPoint("TOPLEFT", self.StatsFrame, "BOTTOMLEFT", 0, -18)
	self.AbilitiesFrame:SetPoint("TOPLEFT", self.StatsFrame.AbilitiesText, "BOTTOMLEFT", 0, -18);

	--Set cost of the heal, enable/disable the button accordingly. 
	self:UpdateHealCost();

	self.lastUpdate = GetTime();
end

---------------------------------------------------------------------------------
--- Covenant Mission List Mixin												  ---
---------------------------------------------------------------------------------

function CovenantMissionList_Sort(missionsList)
	local comparison = function(mission1, mission2)

		--Filter inProgress to the bottom unless they can be completed
		if mission1.canBeCompleted ~= mission2.canBeCompleted then
			return mission1.canBeCompleted;
		end

		if mission1.inProgress ~= mission2.inProgress then
			return mission1.inProgress;
		end

		if ( mission1.level ~= mission2.level ) then
			return mission1.level > mission2.level;
		end

		if ( mission1.durationSeconds ~= mission2.durationSeconds ) then
			return mission1.durationSeconds < mission2.durationSeconds;
		end

		if ( mission1.isRare ~= mission2.isRare ) then
			return mission1.isRare;
		end

		return strcmputf8i(mission1.name, mission2.name) < 0;
	end

	table.sort(missionsList, comparison);
end

CovenantMissionListMixin = { }

function CovenantMissionListMixin:OnLoad()
	self.newMissionIDs = {};
	self.combinedMissions = {};
	self.listScroll:SetScript("OnMouseWheel", function(self, ...) HybridScrollFrame_OnMouseWheel(self, ...); GarrisonMissionList_UpdateMouseOverTooltip(self); end);
end

function CovenantMissionListMixin:OnUpdate()
	local timeNow = GetTime();
	for _, mission in ipairs(self.combinedMissions) do
	
		local limitedTimeOfferExpired = not mission.inProgress and mission.offerEndTime and mission.offerEndTime <= timeNow;
		local activelyInProgress = mission.inProgress and not mission.canBeCompleted;
		if ( activelyInProgress or limitedTimeOfferExpired) then
			self:UpdateMissions();
			break;
		end
	end

	self:Update();
end

function CovenantMissionListMixin:UpdateMissions()

	local inProgressMissions = {};
	local completedMissions = {};
	C_Garrison.GetInProgressMissions(inProgressMissions, self:GetMissionFrame().followerTypeID);
	completedMissions = C_Garrison.GetCompleteMissions(self:GetMissionFrame().followerTypeID);

	C_Garrison.GetAvailableMissions(self.combinedMissions, self:GetMissionFrame().followerTypeID);

	--Missions that are partially completed (initiated complete but didn't finish) are not marked InProgress, so this loop makes sure to add the unique complete missions while marking the inProgress Missions that are also complete. 
	for _, completedMission in ipairs(completedMissions) do
		local foundInProgress = false;
		for _, inProgressMission in ipairs(inProgressMissions) do 
			if completedMission.missionID == inProgressMission.missionID then
				inProgressMission.canBeCompleted = true;
				foundInProgress = true;
				break
			end
		end

		if not foundInProgress then 
			completedMission.canBeCompleted = true;
			table.insert(self.combinedMissions, completedMission);
		end
	end

	for _, inProgressMission in ipairs(inProgressMissions) do 
		table.insert(self.combinedMissions, inProgressMission);
	end

	CovenantMissionList_Sort(self.combinedMissions);

	self:Update();
end

function CovenantMissionListMixin:Update()
	local missions = self.combinedMissions;
	local followerTypeID = self:GetMissionFrame().followerTypeID;
	local numMissions = missions and #missions or 0;
	local scrollFrame = self.listScroll;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	local numButtons = #buttons;

	if (numMissions == 0) then
		self.EmptyListString:Show();
	else
		self.EmptyListString:Hide();
	end

	for i = 1, numButtons do
		local button = buttons[i];
		local index = offset + i; -- adjust index
		if ( index <= numMissions) then
			local mission = missions[index];
			button.id = index;
			button.info = mission;
			button.Title:SetWidth(0);
			button.Title:SetText(mission.name);
			button.Level:SetText(mission.level);
			button.Summary:Show();
			if not mission.encounterIconInfo then
				mission.encounterIconInfo = C_Garrison.GetMissionEncounterIconInfo(mission.missionID);
			end

			button.info.encounterIconInfo = mission.encounterIconInfo;

			if ( mission.durationSeconds >= GARRISON_LONG_MISSION_TIME ) then
				local duration = format(GARRISON_LONG_MISSION_TIME_FORMAT, mission.duration);
				button.Summary:SetFormattedText(PARENS_TEMPLATE, duration);
			else
				button.Summary:SetFormattedText(PARENS_TEMPLATE, mission.duration);
			end
			if ( mission.locTextureKit ) then
				button.LocBG:Show();
				button.LocBG:SetAtlas(mission.locTextureKit.."-List");
			else
				button.LocBG:Hide();
			end

			if ( button.EncounterIcon ) then
				button.EncounterIcon:SetEncounterInfo(button.info.encounterIconInfo);
			end
			
			button:Enable();
			button.Overlay:Hide();
			button.CompleteCheck:SetShown(mission.canBeCompleted);
			button.CompleteHighlight:SetShown(mission.canBeCompleted);

			if (mission.canBeCompleted) then
				button.Summary:SetShown(false);
			elseif (mission.inProgress) then
				button.Overlay:Show();
				button.Summary:SetText(mission.timeLeft.." "..RED_FONT_COLOR_CODE..GARRISON_MISSION_IN_PROGRESS..FONT_COLOR_CODE_CLOSE);
			end

			if ( button.Title:GetWidth() + button.Summary:GetWidth() + 8 < 655 - #mission.rewards * 65 ) then
				button.Title:SetPoint("LEFT", 165, 0);
				button.Summary:ClearAllPoints();
				button.Summary:SetPoint("BOTTOMLEFT", button.Title, "BOTTOMRIGHT", 8, 0);
			else
				button.Title:SetPoint("LEFT", 165, 10);
				button.Title:SetWidth(655 - #mission.rewards * 65);
				button.Summary:ClearAllPoints();
				button.Summary:SetPoint("TOPLEFT", button.Title, "BOTTOMLEFT", 0, -4);
			end

			GarrisonMissionButton_SetRewards(button, mission.rewards, #mission.rewards);
			button:Show();
		else
			button:Hide();
			button.info = nil;
		end
	end

	local totalHeight = numMissions * scrollFrame.buttonHeight;
	local displayedHeight = numButtons * scrollFrame.buttonHeight;
	HybridScrollFrame_Update(scrollFrame, totalHeight, displayedHeight);
end

---------------------------------------------------------------------------------
--- Covenant Mission List Button Handlers									  ---
---------------------------------------------------------------------------------

function CovenantMissionButton_OnClick(self)
	local missionFrame = self:GetParent():GetParent():GetParent():GetParent():GetParent();
	if (self.info.canBeCompleted) then
		missionFrame:InitiateMissionCompletion(self.info);
	else
		missionFrame:OnClickMission(self.info);
	end
end

function CovenantMissionButton_OnEnter(self)
	local missionInfo = self.info;

	if (missionInfo == nil) then
		return;
	end

	GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT");

	GameTooltip_SetTitle(GameTooltip, missionInfo.name);
	if(missionInfo.canBeCompleted) then
		GameTooltip_AddColoredLine(GameTooltip, COMPLETE, WHITE_FONT_COLOR);
	elseif missionInfo.inProgress then
		GameTooltip_AddColoredLine(GameTooltip, IN_PROGRESS, WHITE_FONT_COLOR);
	end

	GameTooltip_AddBlankLineToTooltip(GameTooltip);
	GameTooltip_AddNormalLine(GameTooltip, REWARDS);
	for id, reward in pairs(missionInfo.rewards) do
		if (reward.quality) then
			GameTooltip:AddLine(ITEM_QUALITY_COLORS[reward.quality + 1].hex..reward.title..FONT_COLOR_CODE_CLOSE);
		elseif (reward.itemID) then
			local itemName, _, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(reward.itemID);
			if itemName then
				GameTooltip:AddLine(ITEM_QUALITY_COLORS[itemRarity].hex..itemName..FONT_COLOR_CODE_CLOSE);
			end
        elseif (reward.currencyID and C_CurrencyInfo.IsCurrencyContainer(reward.currencyID, reward.quantity)) then
            local name, texture, quantity, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(reward.currencyID, reward.quantity);
            if name then
				GameTooltip:AddLine(ITEM_QUALITY_COLORS[quality].hex..name..FONT_COLOR_CODE_CLOSE);
			end
		else
			GameTooltip_AddColoredLine(GameTooltip, reward.title, WHITE_FONT_COLOR);
		end
	end

	if missionInfo.inProgress then
		if (self.info.followers ~= nil) then
			GameTooltip_AddBlankLineToTooltip(GameTooltip);
			GameTooltip_AddNormalLine(GameTooltip, COVENANT_MISSIONS_FOLLOWERS);
			for i=1, #(missionInfo.followers) do
				GameTooltip_AddColoredLine(GameTooltip, C_Garrison.GetFollowerName(missionInfo.followers[i]), WHITE_FONT_COLOR);
			end
		end
	elseif (missionInfo.isRare) then
		GameTooltip_AddNormalLine(GameTooltip, COVENANT_MISSIONS_AVAILABILITY);
		GameTooltip_AddColoredLine(GameTooltip, missionInfo.offerTimeRemaining, WHITE_FONT_COLOR);
	end

	GameTooltip:Show();
end

---------------------------------------------------------------------------------
--- Covenant Mission List Button Handlers									  ---
---------------------------------------------------------------------------------

CovenantMissionEncounterIconMixin = {}

function CovenantMissionEncounterIconMixin:SetEncounterInfo(encounterIconInfo)
	self.RareOverlay:SetShown(encounterIconInfo.isRare);
	self.EliteOverlay:SetShown(encounterIconInfo.isElite);
	GarrisonPortrait_Set(self.Portrait, encounterIconInfo.portraitFileDataID);
end

---------------------------------------------------------------------------------
--- Adventures Targeting Indicator											  ---
---------------------------------------------------------------------------------

AdventuresTargetingIndicatorMixin = {};

function AdventuresTargetingIndicatorMixin:OnShow()
	if self.targetingTextureAtlas then
		local useAtlasSize= true;
		self.TargetMarker:SetAtlas(self.targetingTextureAtlas, useAtlasSize);
	end

	EventRegistry:RegisterCallback("CovenantMission.CancelTargetingAnimation", self.OnCancelTargeting, self);
	EventRegistry:RegisterCallback("CovenantMission.CancelLoopingTargetingAnimation", self.StopLooping, self);
end

function AdventuresTargetingIndicatorMixin:OnHide()
	self:Stop();
	EventRegistry:UnregisterCallback("CovenantMission.CancelTargetingAnimation", self);
	EventRegistry:UnregisterCallback("CovenantMission.CancelLoopingTargetingAnimation", self);
end

function AdventuresTargetingIndicatorMixin:OnCancelTargeting()
	self:Stop();
	self:ResetPositions();
end

function AdventuresTargetingIndicatorMixin:StopLooping()
	if self.BobLoop:IsPlaying() then
		self.FadeIn:Stop();
		self.BobLoop:Stop();
		self.FadeOut:Play();
	end
end

function AdventuresTargetingIndicatorMixin:ResetPositions()
	self.TargetMarker:SetPoint("CENTER", self, "TOP", 0, 30);
end

function AdventuresTargetingIndicatorMixin:Play()
	if self.TargetingAnimation:IsPlaying() then
		self:Stop();
	end

	self.TargetingAnimation:Play();
end

function AdventuresTargetingIndicatorMixin:Stop()
	self.TargetingAnimation:Stop();
end

function AdventuresTargetingIndicatorMixin:Loop()
	if self.TargetingAnimation:IsPlaying() then 
		self.TargetingAnimation:Stop();
	end

	if not self.BobLoop:IsPlaying() then
		self:ResetPositions();
		self.FadeIn:Play();
		self.BobLoop:Play();
	end
end


---------------------------------------------------------------------------------
--- Covenant Portrait Mixin													  ---
---------------------------------------------------------------------------------

CovenantPortraitMixin = {};

function CovenantPortraitMixin:SetupPortrait(followerInfo)
	GarrisonPortrait_Set(self.Portrait, followerInfo.portraitIconID);
	self.HealthBar:Show();
	self.HealthBar:SetScale(0.7);
	self.LevelText:SetText(followerInfo.level);
	self.HealthBar:SetMaxHealth(followerInfo.autoCombatantStats.maxHealth);
	self.HealthBar:SetHealth(followerInfo.autoCombatantStats.currentHealth);
	self.HealthBar:SetRole(followerInfo.role);
end

function CovenantPortraitMixin:SetQuality(followerInfo)

end
---------------------------------------------------------------------------------
--- Health Bar Mixin													  ---
---------------------------------------------------------------------------------

AventuresPuckHealthBarMixin = {};

local HealthBarBorderSize = 2;
local TotalHealthBarBorderSize = HealthBarBorderSize * 2;
function AventuresPuckHealthBarMixin:SetHealth(health)
	self.health = health;

	local healthPercent = math.min(health / self.maxHealth, 1);
	local healthBarWidth = self.Background:GetWidth();
	self.Health:SetPoint("RIGHT", self.Background, "LEFT", healthBarWidth * healthPercent, 0);
end

function AventuresPuckHealthBarMixin:GetHealth()
	return self.health;
end

function AventuresPuckHealthBarMixin:SetMaxHealth(maxHealth)
	self.maxHealth = maxHealth;
end

function AventuresPuckHealthBarMixin:SetPuckDesaturation(desaturation)
	self.Background:SetDesaturation(desaturation);
	self.Health:SetDesaturation(desaturation);
	self.RoleIcon:SetDesaturation(desaturation);
end

function AventuresPuckHealthBarMixin:SetRole(role)
	local useAtlasSize = true;
	if role == Enum.GarrAutoCombatantRole.HealSupport then
		self.RoleIcon:SetAtlas("Adventures-Healer", useAtlasSize);
	elseif role == Enum.GarrAutoCombatantRole.Tank then
		self.RoleIcon:SetAtlas("Adventures-Tank", useAtlasSize);
	else
		self.RoleIcon:SetAtlas("Adventures-DPS", useAtlasSize);
	end
end
