
UIPanelWindows["RuneforgeFrame"] = { area = "left", pushable = 3, showFailedFunc = C_LegendaryCrafting.CloseRuneforgeInteraction, };

-- Determined by hand using positioning macros.
local CircleRuneEffects = {
	{ effectID = 60, offsetX = 51, offsetY = 149 },
	{ effectID = 62, offsetX = 155, offsetY = 33 },
	{ effectID = 63, offsetX = 156, offsetY = -39 },
	{ effectID = 64, offsetX = 23, offsetY = -165 },
	{ effectID = 65, offsetX = -54, offsetY = -153 },
	{ effectID = 66, offsetX = -141, offsetY = -80 },
	{ effectID = 67, offsetX = -129, offsetY = 94 },
	{ effectID = 68, offsetX = -64, offsetY = 143 },
};


RuneforgeFrameMixin = CreateFromMixins(CallbackRegistryMixin);

RuneforgeFrameMixin:GenerateCallbackEvents(
{
	"BaseItemChanged",
	"PowerSelected",
	"ModifiersChanged",
	"ItemSlotOnEnter",
	"ItemSlotOnLeave",
	"UpgradeItemChanged",
	"UpgradeItemSlotOnEnter",
	"UpgradeItemSlotOnLeave",
});

local RuneforgeFrameEvents = {
	"CURRENCY_DISPLAY_UPDATE",
	"RUNEFORGE_LEGENDARY_CRAFTING_CLOSED",
};

local RuneforgeFrameUnitEvents = {
	"UNIT_SPELLCAST_SUCCEEDED",
};

function RuneforgeFrameMixin:OnLoad()
	CallbackRegistryMixin.OnLoad(self);
	self.ResultTooltip:Init();
	self.runeforgeState = RuneforgeUtil.RuneforgeState.Craft
end

function RuneforgeFrameMixin:OnShow()
	FrameUtil.RegisterFrameForEvents(self, RuneforgeFrameEvents);
	FrameUtil.RegisterFrameForUnitEvents(self, RuneforgeFrameUnitEvents, "player");

	self:RefreshCurrencyDisplay();
	self:SetStaticEffectsShown(true);

	self.Title:SetText(self:IsRuneforgeUpgrading() and RUNEFORGE_LEGENDARY_CRAFTING_FRAME_UPGRADE_TITLE or RUNEFORGE_LEGENDARY_CRAFTING_FRAME_TITLE);
end

function RuneforgeFrameMixin:OnHide()
	FrameUtil.UnregisterFrameForEvents(self, RuneforgeFrameEvents);
	FrameUtil.UnregisterFrameForEvents(self, RuneforgeFrameUnitEvents);

	C_LegendaryCrafting.CloseRuneforgeInteraction();

	self:SetStaticEffectsShown(false);

	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged);
end

function RuneforgeFrameMixin:OnEvent(event, ...)
	if event == "CURRENCY_DISPLAY_UPDATE" then
		-- If this is a Runeforge currency, update.
		local updatedCurrencyID = ...;
		for i, currencyID in ipairs(C_LegendaryCrafting.GetRuneforgeLegendaryCurrencies()) do
			if currencyID == updatedCurrencyID then
				self:RefreshCurrencyDisplay();
				break;
			end
		end
	elseif event == "RUNEFORGE_LEGENDARY_CRAFTING_CLOSED" then
		HideUIPanel(self);
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, castGUID, spellID = ...;
		if spellID == C_LegendaryCrafting.GetRuneforgeLegendaryCraftSpellID() then
			self:SetItem(nil);
		end
	end
end

function RuneforgeFrameMixin:SetStaticEffectsShown(shown)
	if not self.centerPassiveEffect and shown then
		self.centerPassiveEffect = self:AddEffect(RuneforgeUtil.Level.Background, RuneforgeUtil.Effect.CenterPassive, self.CraftingFrame.BaseItemSlot);

		local bottomEffectDynamicDescription = { effectID = RuneforgeUtil.Effect.BottomPassive, offsetY = -204, };
		self.bottomEffect = self.BottomModelScene:AddDynamicEffect(bottomEffectDynamicDescription, self);

	elseif self.centerPassiveEffect and not shown then
		self.centerPassiveEffect:CancelEffect();
		self.centerPassiveEffect = nil;

		self.bottomEffect:CancelEffect();
		self.bottomEffect = nil;
	end
end

function RuneforgeFrameMixin:SetRunesShown(shown)
	if self.runeEffects and not shown then
		for i, effectController in ipairs(self.runeEffects) do
			effectController:CancelEffect();
		end

		self.runeEffects = nil;
	elseif not self.runeEffects and shown then
		self.runeEffects = {};

		for i, effect in ipairs(CircleRuneEffects) do
			local effectController = self.OverlayModelScene:AddDynamicEffect(effect, self.CraftingFrame.BaseItemSlot);
			table.insert(self.runeEffects, effectController);
		end
	end
end

function RuneforgeFrameMixin:RefreshCurrencyDisplay()
	local initFunction = nil;
	local initialAnchor = nil;
	local gridLayout = nil;
	local tooltipAnchor = "ANCHOR_RIGHT";
	return self.CurrencyDisplay:SetCurrencies(C_LegendaryCrafting.GetRuneforgeLegendaryCurrencies(), initFunction, initialAnchor, gridLayout, tooltipAnchor);
end

function RuneforgeFrameMixin:GetLegendaryCraftInfo()
	local itemLocation = self:GetItem();
	if itemLocation then
		local powerID = self.CraftingFrame:GetPowerID();
		local modifiers = self.CraftingFrame:GetModifiers();
		return itemLocation, powerID, modifiers;
	end

	return nil;
end

function RuneforgeFrameMixin:RefreshResultTooltip()
	local resultTooltip = self.ResultTooltip;
	local tooltipWasShown = resultTooltip:IsShown();
	local baseItem, powerID, modifiers = self:GetLegendaryCraftInfo();
	local hasItem = baseItem ~= nil;
	if hasItem then
		resultTooltip:SetOwner(self, "ANCHOR_NONE");
		resultTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, -162);

		local itemID = C_Item.GetItemID(baseItem);
		local upgradeItem = self:GetUpgradeItem();
		local hasUpgradeItem = upgradeItem ~= nil;
		local itemLevel = hasUpgradeItem and C_Item.GetCurrentItemLevel(upgradeItem) or C_Item.GetCurrentItemLevel(baseItem);
		resultTooltip:SetRuneforgeResultItem(itemID, itemLevel, powerID, modifiers);
	end
	
	resultTooltip:SetShown(hasItem);

	if tooltipWasShown ~= hasItem then
		local panelWidth = hasItem and (self:GetWidth() + resultTooltip:GetWidth()) or self:GetWidth();
		SetUIPanelAttribute(self, "width", panelWidth);
		UpdateUIPanelPositions(self);
	end
end

function RuneforgeFrameMixin:ShowComparisonTooltip()
	local baseItem, powerID, modifiers = self:GetLegendaryCraftInfo();
	local upgradeItem = self:GetUpgradeItem();
	if baseItem == nil or upgradeItem == nil then
		return;
	end

	GameTooltip:SetOwner(self, "ANCHOR_NONE");
	GameTooltip:SetPoint("LEFT", self.CraftingFrame.BaseItemSlot, "RIGHT", 10, 0);

	local itemID = C_Item.GetItemID(baseItem);
	local itemLevel = C_Item.GetCurrentItemLevel(baseItem);
	GameTooltip:SetRuneforgeResultItem(itemID, itemLevel, powerID, modifiers);
	SharedTooltip_SetBackdropStyle(GameTooltip, GAME_TOOLTIP_BACKDROP_STYLE_RUNEFORGE_LEGENDARY);
	GameTooltip:Show();

	local resultTooltip = self.ResultTooltip;
	resultTooltip:SetOwner(self, "ANCHOR_NONE");
	resultTooltip:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 4, 0);
	local upgradeItemLevel = C_Item.GetCurrentItemLevel(upgradeItem);
	resultTooltip:SetRuneforgeResultItem(itemID, upgradeItemLevel, powerID, modifiers);
	resultTooltip:Show();

	SetUIPanelAttribute(self, "width", self:GetWidth());
	UpdateUIPanelPositions(self);
end

function RuneforgeFrameMixin:ShowUpgradeTooltip()
end

function RuneforgeFrameMixin:SetItem(itemLocation, autoSelectSlot)
	return self.CraftingFrame:SetItem(itemLocation, autoSelectSlot);
end

function RuneforgeFrameMixin:SetItemAutomatic(itemLocation)
	local autoSelectSlot = true;
	return self.CraftingFrame:SetItem(itemLocation, autoSelectSlot);
end

function RuneforgeFrameMixin:GetItem()
	return self.CraftingFrame:GetItem();
end

function RuneforgeFrameMixin:HasItem()
	return self:GetItem() ~= nil;
end

function RuneforgeFrameMixin:GetUpgradeItem()
	return self.CraftingFrame:GetUpgradeItem();
end

function RuneforgeFrameMixin:HasUpgradeItem()
	return self.CraftingFrame:GetUpgradeItem() ~= nil;
end

function RuneforgeFrameMixin:SetPowerID(powerID)
	return self.CraftingFrame:SetPowerID(powerID);
end

function RuneforgeFrameMixin:GetPowerID()
	return self.CraftingFrame:GetPowerID();
end

function RuneforgeFrameMixin:TogglePowerList()
	self.CraftingFrame:TogglePowerList();
end

function RuneforgeFrameMixin:GetPowers()
	local item = self.CraftingFrame:GetItem();
	return C_LegendaryCrafting.GetRuneforgePowers(item);
end

function RuneforgeFrameMixin:GetCraftDescription()
	local craftDescription = {};

	local baseItem, powerID, modifiers = self:GetLegendaryCraftInfo();
	if not baseItem or not powerID or #modifiers ~= 2 then
		return nil;
	end

	return C_LegendaryCrafting.MakeRuneforgeCraftDescription(baseItem, powerID, modifiers);
end

function RuneforgeFrameMixin:CanCraftRuneforgeLegendary()
	local baseItem, powerID, modifiers = self:GetLegendaryCraftInfo();

	if baseItem == nil then
		return false, nil;
	end

	local isUpgrading = self:IsRuneforgeUpgrading();
	local upgradeItem = self:GetUpgradeItem();
	if isUpgrading and (upgradeItem == nil) then
		return false, nil;
	end

	local costs = isUpgrading and C_LegendaryCrafting.GetRuneforgeLegendaryUpgradeCost(baseItem, upgradeItem) or C_LegendaryCrafting.GetRuneforgeLegendaryCost(baseItem);
	for i, cost in ipairs(costs) do
		local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(cost.currencyID);
		if cost.amount > currencyInfo.quantity then
			local formatString = isUpgrading and RUNEFORGE_LEGENDARY_ERROR_UPGRADE_INSUFFICIENT_CURRENCY_FORMAT or RUNEFORGE_LEGENDARY_ERROR_INSUFFICIENT_CURRENCY_FORMAT;
			return false, formatString:format(currencyInfo.name);
		end
	end

	-- We need exactly 2 modifiers, one for each secondary stat.
	if not powerID or #modifiers ~= 2 then
		return false, nil;
	end

	return true, nil;
end

function RuneforgeFrameMixin:GetModelSceneFromLevel(level)
	if level == RuneforgeUtil.Level.Background then
		return self.BackgroundModelScene;
	elseif level == RuneforgeUtil.Level.Overlay then
		return self.OverlayModelScene;
	else -- RuneforgeUtil.Level.Frame is omitted as that is the default level.
		return self.CraftingFrame.ModelScene;
	end
end

function RuneforgeFrameMixin:AddEffect(level, ...)
	local modelScene = self:GetModelSceneFromLevel(level);
	return modelScene:AddEffect(...);
end

function RuneforgeFrameMixin:SetRuneforgeState(state)
	self:SetItem(nil);
	self.runeforgeState = state;

	ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged);
end

function RuneforgeFrameMixin:GetRuneforgeState()
	return self.runeforgeState;
end

function RuneforgeFrameMixin:GetItemContext()
	local hasItem = self:HasItem();
	if self:GetRuneforgeState() == RuneforgeUtil.RuneforgeState.Upgrade then
		return self:HasItem() and ItemButtonUtil.ItemContextEnum.SelectRuneforgeUpgradeItem or ItemButtonUtil.ItemContextEnum.SelectRuneforgeItem;
	else
		return ItemButtonUtil.ItemContextEnum.PickRuneforgeBaseItem;
	end
end

function RuneforgeFrameMixin:GetCost()
	local baseItem = self:GetItem();
	if self:IsRuneforgeUpgrading() then
		local upgradeItem = self:GetUpgradeItem();
		return (baseItem and upgradeItem) and C_LegendaryCrafting.GetRuneforgeLegendaryUpgradeCost(baseItem, upgradeItem) or nil;
	else
		return baseItem and C_LegendaryCrafting.GetRuneforgeLegendaryCost(baseItem) or nil;
	end
end

function RuneforgeFrameMixin:IsUpgradeItemValidForRuneforgeLegendary(itemLocation)
	local baseItem = self:GetItem();
	if not baseItem then
		return false;
	end

	return C_LegendaryCrafting.IsUpgradeItemValidForRuneforgeLegendary(baseItem, itemLocation);
end

function RuneforgeFrameMixin:IsRuneforgeCrafting()
	return self:GetRuneforgeState() == RuneforgeUtil.RuneforgeState.Craft;
end

function RuneforgeFrameMixin:IsRuneforgeUpgrading()
	return self:GetRuneforgeState() == RuneforgeUtil.RuneforgeState.Upgrade;
end

function RuneforgeFrameMixin:GetRuneforgeComponentInfo()
	if not self:IsRuneforgeUpgrading() then
		return nil;
	end

	local baseItem = self:GetItem();
	if baseItem == nil then
		return nil;
	end

	return C_LegendaryCrafting.GetRuneforgeLegendaryComponentInfo(baseItem);
end

function RuneforgeFrameMixin:Close()
	HideUIPanel(self);
end
