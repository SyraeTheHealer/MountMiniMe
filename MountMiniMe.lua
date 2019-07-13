--[[ MountMiniMe.lua ]]--

local AddonName, AddonTable = ...
local Addon = LibStub('AceAddon-3.0'):NewAddon(AddonTable, AddonName, 'AceBucket-3.0', 'AceEvent-3.0', 'AceConsole-3.0', 'AceTimer-3.0', 'AceHook-3.0')
local L = LibStub('AceLocale-3.0'):GetLocale(AddonName)

AddonTable.L = L;

AddonTable.DEBUG = false;

local CURRENT_VERSION = GetAddOnMetadata(AddonName, 'Version')
local CONFIG_ADDON_NAME = AddonName .. '_Config'

AddonTable.MountCollection = {}
AddonTable.PetSpellIds = {}
AddonTable.NumPetSpellIds = 0;
AddonTable.StealthPetId = nil;
AddonTable.PlayerStealthed = false;
AddonTable.PlayerMounted = false;
AddonTable.PlayerHasHunterPet = false;
AddonTable.DesiredPetId = nil;
AddonTable.RepeatingSummonTimerId = nil;
AddonTable.SummonTimerId = nil;
AddonTable.DismissTimerId = nil;
AddonTable.CallSummonPetByGUIDTimerId = nil;
AddonTable.PetChangeInProgress = false;
AddonTable.SummonDelay = 0.5;
AddonTable.DefaultSummonDelay = 0.5;
AddonTable.Paused = false;

AddonTable.PlayerInfo = {
	combat = false,
	dead = false,
	feigning = false,
	casting = false,
	channeling = false,
	looting = false,
	controlLost = false,
	sitting = false,
}

--[[ Startup ]]--

function Addon:OnInitialize()

	--register database events
	self.db = LibStub('AceDB-3.0'):New(AddonName .. 'DB', self:GetDefaults(), true)
	self.db.RegisterCallback(self, 'OnNewProfile')
	self.db.RegisterCallback(self, 'OnProfileChanged')
	self.db.RegisterCallback(self, 'OnProfileCopied')
	self.db.RegisterCallback(self, 'OnProfileReset')
	self.db.RegisterCallback(self, 'OnProfileDeleted')

	--version update
	if _G[AddonName .. 'Version'] then
		if _G[AddonName .. 'Version'] ~= CURRENT_VERSION then
			self:UpdateSettings(_G[AddonName .. 'Version']:match('(%w+)%.(%w+)%.(%w+)'))
			self:UpdateVersion()
		end
		--new user
	else
		_G[AddonName .. 'Version'] = CURRENT_VERSION
	end

	--create a loader for the options menu
	local f = CreateFrame('Frame', nil, _G['InterfaceOptionsFrame'])
	f:SetScript('OnShow', function(self)
		self:SetScript('OnShow', nil)
		LoadAddOn(CONFIG_ADDON_NAME)
	end)

	--Register for a bunch of events for better checking for pet summoning
	self:RegisterBucketEvent("UNIT_AURA", 0.1, Addon.UnitAuraEventHandler);
	self:RegisterEvent("PLAYER_REGEN_ENABLED", Addon.RegenEnabledEventHandler);
	self:RegisterEvent("PLAYER_REGEN_DISABLED", Addon.RegenDisabledEventHandler);

	self:RegisterEvent("PLAYER_DEAD", Addon.PlayerDeadEventHandler);
	self:RegisterEvent("PLAYER_ALIVE", Addon.PlayerAliveEventHandler);
	self:RegisterEvent("PLAYER_UNGHOST", Addon.PlayerAliveEventHandler);

	--Spell cast
	self:RegisterEvent("UNIT_SPELLCAST_SENT", Addon.SpellcastSentEventHandler);
	self:RegisterEvent("UNIT_SPELLCAST_START", Addon.SpellcastStartEventHandler);
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", Addon.SpellcastInterruptedEventHandler);
	self:RegisterEvent("UNIT_SPELLCAST_STOP", Addon.SpellcastStopEventHandler);
	self:RegisterEvent("UNIT_SPELLCAST_FAILED", Addon.SpellcastFailedEventHandler);
	self:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET", Addon.SpellcastFailedQuietEventHandler);
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", Addon.SpellcastSucceededEventHandler);
	
	--Spell channeling
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", Addon.ChannelStartEventHandler);
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", Addon.ChannelStopEventHandler);
	
	--Looting
	self:RegisterEvent("LOOT_OPENED", Addon.LootStartedHandler);
	self:RegisterEvent("LOOT_CLOSED", Addon.LootStoppedHandler);

	--Control lost
	self:RegisterEvent("PLAYER_CONTROL_LOST", Addon.ControlLostStartedHandler);
	self:RegisterEvent("PLAYER_CONTROL_GAINED", Addon.ControlLostStoppedHandler);
	
	--Mount Journal
	self:RegisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED", Addon.UpdateMountJournalOverlays);
	
	--Pet Journal
	self:RegisterBucketEvent("PET_JOURNAL_LIST_UPDATE", 0.1, Addon.CompanionUpdateEvent)
--	self:RegisterEvent("COMPANION_UPDATE", Addon.CompanionUpdateEvent)
	
	--Stealth
	self:RegisterEvent("UPDATE_STEALTH", Addon.UpdateStealthEventHandler);
	
	--Hunter pets
	self:RegisterBucketEvent("UNIT_PET", 0.5, Addon.UnitPetEventHandler);
	
	--Shapeshift form
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", Addon.ShapeshiftHandler);
	
	--Talent switch
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", Addon.TalentHandler);

	--Summon timer
	AddonTable.RepeatingSummonTimerId = self:ScheduleRepeatingTimer("RepeatingSummonPet", 0.5);

end

function Addon:OnEnable()

	self:SecureHook("SitStandOrDescendStart");
	self:SecureHook("JumpOrAscendStart");
	self:SecureHook("MoveAndSteerStart");
	self:SecureHook("MoveBackwardStart");
	self:SecureHook("MoveForwardStart");
	self:SecureHook("StrafeLeftStart");
	self:SecureHook("StrafeRightStart");
	self:SecureHook("ToggleAutoRun");
	self:SecureHook("TurnLeftStart");
	self:SecureHook("TurnRightStart");
	self:SecureHook("TurnOrActionStart");

	self:Load()
end

--[[ Version Updating ]]--

function Addon:GetDefaults()
	return {
		profile = {
			pairs = {
			},
			minimap = {
				hide = false,
			},
			options = {
				dismount = {
					enabled = false,
					operation = 'summon',
					petId = nil,
				},
				stealth = {
					dismiss = false,
				},
				hunterMode = {
					enabled = false,
					operation = 'keep',
				},
        shapeshiftMode = {
          enabled = false,
          operation = 'keep',
        },
				perCharDismount = {
					enabled = false,
				},
        perSpecDismount = {
          enabled = false,
        },
				summonDelays = {
					dismountDelay = 1,
					combatDelay = 1,
					stealthDelay = 1,
					lootDelay = 1,
				}
			},
			hunterModePairs = {
			},
      shapeshiftModePairs = {
      },
			perCharDismountPairs = {
			},
      perSpecDismountPairs = {
      },
		},
	}
end

function Addon:UpdateSettings(major, minor, bugfix)
-- Nothing to see here for now
end

function Addon:UpdateVersion()
	_G[AddonName .. 'Version'] = CURRENT_VERSION

	self:Printf(L.Updated, _G[AddonName .. 'Version'])
end

function Addon:PrintVersion()
	self:Print(_G[AddonName .. 'Version'])
end


--Load is called  when the addon is first enabled, and also whenever a profile is loaded
function Addon:Load()
	local module_load = function(module)
		if module.Load then
			module:Load();
		end
	end


	for i, module in self:IterateModules() do
		local success, msg = pcall(module_load, module);
		if not success then
			self:Printf('Failed to load %s\n%s', module:GetName(), msg);
		end
	end

	self:CreateMountTable();
	self:CreatePetSpellIdsTable();
	self:InitTrackingVars();
end

--unload is called when we're switching profiles
function Addon:Unload()
	local module_unload = function(module)
		if module.Unload then
			module:Unload();
		end
	end

	--unload any module stuff
	for i, module in self:IterateModules() do
		local success, msg = pcall(module_unload, module);
		if not success then
			self:Printf('Failed to unload %s\n%s', module:GetName(), msg);
		end
	end

	self:DestroyMountTable();
	self:DestroyPetSpellIdsTable();
	self:InitTrackingVars();
end



--[[ Options Menu Display ]]--

function Addon:GetOptions()
	local options = self.Options

	if (not options) and LoadAddOn(CONFIG_ADDON_NAME) then
		options = self.Options
	end

	return options
end

function Addon:ShowOptions()
	if InCombatLockdown() then return end

	local options = self:GetOptions()
	if options then
		options:ShowAddonPanel()
		return true
	end

end

function Addon:NewMenu()
	local options = self:GetOptions()
	if options then
		return options.Menu:New()
	end
end

function Addon:IsConfigAddonEnabled()
	return GetAddOnEnableState(UnitName('player'), CONFIG_ADDON_NAME) >= 1
end




--==============================================================================
--Hook this so manually summoned/dismissed pets stick
local old_C_PetJournal_SummonPetByGUID = C_PetJournal.SummonPetByGUID;
function postHook_C_PetJournal_SummonPetByGUID(petId, ...)
	Addon:debug_print('postHook_C_PetJournal_SummonPetByGUID - petId = ' .. tostring(petId));
	if Addon:IsCurrentPet(petId) then
		AddonTable.DesiredPetId = nil
	else
		AddonTable.DesiredPetId = petId;
	end
end

function C_PetJournal.SummonPetByGUID(petId)
	Addon:debug_print('---> SummonPetByGUID - ' .. tostring(petId))
	postHook_C_PetJournal_SummonPetByGUID(petId, old_C_PetJournal_SummonPetByGUID(petId));
end

--[[ exports ]]--

_G[AddonName] = Addon

--[[ Frame for events ]]--
local frame = CreateFrame("FRAME", AddonName .. "Frame");
frame:RegisterEvent("PLAYER_LOGIN")
local function EventHandler(self, event, ...)
	if event=="ADDON_LOADED" and select(1,...)=="Blizzard_Collections" then
		self:UnregisterEvent("ADDON_LOADED");
		MountJournal:HookScript("OnShow",function(self) Addon:UpdateMountJournalOverlays() end);
		Addon:Hook_MountJournal_UpdateMountList();
		Addon:Hook_MountJournalMountButton_UpdateTooltip();

	elseif event=="PLAYER_LOGIN" then
		if IsAddOnLoaded("Blizzard_Collections") then
			-- for those addons that force a load in their login (sigh)
			EventHandler(self,"ADDON_LOADED","Blizzard_Collections");
		else
			self:RegisterEvent("ADDON_LOADED");
		end
	end
end
frame:SetScript("OnEvent", EventHandler);


