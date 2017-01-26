--[[ MountMiniMe.lua ]]--

local AddonName, AddonTable = ...
local Addon = LibStub('AceAddon-3.0'):NewAddon(AddonTable, AddonName, 'AceBucket-3.0', 'AceEvent-3.0', 'AceConsole-3.0', 'AceTimer-3.0', 'AceHook-3.0')
local L = LibStub('AceLocale-3.0'):GetLocale(AddonName)

local DEBUG = false;

local CURRENT_VERSION = GetAddOnMetadata(AddonName, 'Version')
local CONFIG_ADDON_NAME = AddonName .. '_Config'

local MountCollection = {}
local PetSpellIds = {}
local NumPetSpellIds
local StealthPetId, PlayerStealthed, PlayerMounted, PlayerHasHunterPet, DesiredPetId
local RepeatingSummonTimerId, SummonTimerId, DismissTimerId
local PetChangeInProgress

local PlayerInfo = {
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
		--    print('loading config addon: ' .. CONFIG_ADDON_NAME)
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
	self:RegisterEvent("LOOT_STARTED", Addon.LootStartedHandler);
	self:RegisterEvent("LOOT_STOPPED", Addon.LootStoppedHandler);

	--Control lost
	self:RegisterEvent("PLAYER_CONTROL_LOST", Addon.ControlLostStartedHandler);
	self:RegisterEvent("PLAYER_CONTROL_GAINED", Addon.ControlLostStoppedHandler);
	
	--Mount Journal
	self:RegisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED", Addon.UpdateMountJournalOverlays);
	
	--Pet Journal
	self:RegisterBucketEvent("PET_JOURNAL_LIST_UPDATE", 0.1, Addon.CompanionUpdateEvent)
--	self:RegisterBucketEvent("COMPANION_UPDATE", 0.1, Addon.CompanionUpdateEvent)
	
	--Stealth
	self:RegisterEvent("UPDATE_STEALTH", Addon.UpdateStealthEventHandler);
	
	--Hunter pets
	self:RegisterBucketEvent("UNIT_PET", 0.5, Addon.UnitPetEventHandler);

	--Summon timer
	RepeatingSummonTimerId = self:ScheduleRepeatingTimer("RepeatingSummonPet", 0.5);

--	--Mount journal search
--	self:RegisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED", Addon.MountJournalSearch);

	--test
--	self:RegisterEvent("PLAYER_FLAGS_CHANGED", Addon.FlagChange);
--	self:RegisterEvent("UNIT_FLAGS", Addon.UnitFlags);
--	self:RegisterEvent("UNIT_AURA", Addon.Sitting);
end

--function Addon:MountJournalSearch()
--	Addon:debug_print('MountJournalSearch');
--	Addon:UpdateMountJournalOverlays();
--end

--function Addon:Sitting()
--	Addon:debug_print("Sitting called");
--	--    local name, rank, icon, count, dispelType, duration, expires, caster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, _, nameplateShowAll, timeMod, value1, value2, value3 = UnitDebuff("player", "Sitting");
--	
--	--	local name, rank, icon, castingTime, minRange, maxRange, spellID = GetSpellInfo(76701);
--	--    Addon:debug_print('sitting = ' .. tostring(name));
--	--    name, rank, icon, castingTime, minRange, maxRange, spellID = GetSpellInfo(80612);
--	--    Addon:debug_print('sitting = ' .. tostring(name));
--	--    name, rank, icon, castingTime, minRange, maxRange, spellID = GetSpellInfo(89279);
--	--    Addon:debug_print('sitting = ' .. tostring(name));
--	
--	--	Addon:debug_print('in range = ' .. tostring(IsSpellInRange("Sitting", "player")));    
--    
--end

--function Addon:FlagChange()
--	Addon:debug_print('player flag change');
--end
--
--function Addon:UnitFlags()
--	Addon:debug_print('unit flags');
--end

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
				perCharDismount = {
					enabled = false,
				},
			},
			hunterModePairs = {
			},
			perCharDismountPairs = {
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


--[[ Profile Functions ]]--

function Addon:SaveProfile(name)
	local toCopy = self.db:GetCurrentProfile()
	if name and name ~= toCopy then
		self:Unload()
		self.db:SetProfile(name)
		self.db:CopyProfile(toCopy)
		self.isNewProfile = nil
		self:Load()
	end
end

function Addon:SetProfile(name)
	local profile = self:MatchProfile(name)
	if profile and profile ~= self.db:GetCurrentProfile() then
		self:Unload()
		self.db:SetProfile(profile)
		self.isNewProfile = nil
		self:Load()
	else
		self:Print(format(L.InvalidProfile, name or 'null'))
	end
end

function Addon:DeleteProfile(name)
	local profile = self:MatchProfile(name)
	if profile and profile ~= self.db:GetCurrentProfile() then
		self.db:DeleteProfile(profile)
	else
		self:Print(L.CantDeleteCurrentProfile)
	end
end

function Addon:CopyProfile(name)
	if name and name ~= self.db:GetCurrentProfile() then
		self:Unload()
		self.db:CopyProfile(name)
		self.isNewProfile = nil
		self:Load()
	end
end

function Addon:ResetProfile()
	self:Unload()
	self.db:ResetProfile()
	self.isNewProfile = true
	self:Load()
end

function Addon:ListProfiles()
	self:Print(L.AvailableProfiles)

	local current = self.db:GetCurrentProfile()
	for _,k in ipairs(self.db:GetProfiles()) do
		if k == current then
			print(' - ' .. k, 1, 1, 0)
		else
			print(' - ' .. k)
		end
	end
end

function Addon:MatchProfile(name)
	local name = name:lower()
	local nameRealm = name .. ' - ' .. GetRealmName():lower()
	local match

	for i, k in ipairs(self.db:GetProfiles()) do
		local key = k:lower()
		if key == name then
			return k
		elseif key == nameRealm then
			match = k
		end
	end
	return match
end


--[[ Profile Events ]]--

function Addon:OnNewProfile(msg, db, name)
	self.isNewProfile = true
	self:Print(format(L.ProfileCreated, name))
end

function Addon:OnProfileDeleted(msg, db, name)
	self:Print(format(L.ProfileDeleted, name))
end

function Addon:OnProfileChanged(msg, db, name)
	self:Print(format(L.ProfileLoaded, name))
end

function Addon:OnProfileCopied(msg, db, name)
	self:Print(format(L.ProfileCopied, name))
end

function Addon:OnProfileReset(msg, db)
	self:Print(format(L.ProfileReset, db:GetCurrentProfile()))
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

--[[ Configuration Functions ]]--

--minimap button
function Addon:SetShowMinimap(enable)
	self.db.profile.minimap.hide = not enable
	self:GetModule('Launcher'):Update()
end

function Addon:ShowingMinimap()
	return not self.db.profile.minimap.hide
end

--Stealth
function Addon:IsDismissOnStealth()
	return self.db.profile.options.stealth.dismiss;
end

function Addon:SetDismissOnStealth(enable)
	self:debug_print('dismiss stealth = ' .. tostring(enable));
	self.db.profile.options.stealth.dismiss = enable;
end

--Dismount
function Addon:IsDetectDismount()
	return self.db.profile.options.dismount.enabled;
end

function Addon:SetDetectDismount(enable)
	self:debug_print('detect dismount = ' .. tostring(enable));
	self.db.profile.options.dismount.enabled = enable;
end

function Addon:GetDismountOperation()
	return self.db.profile.options.dismount.operation;
end

function Addon:SetDismountOperation(value)
	self:debug_print('dismount op = ' .. tostring(value));
	self.db.profile.options.dismount.operation = value;
end

function Addon:GetDismountPetId()
	return self.db.profile.options.dismount.petId;
end

function Addon:SetDismountPetId(petId)
	self:debug_print('dismount petId = ' .. tostring(petId));
	self.db.profile.options.dismount.petId = petId;
end

--Hunter mode
function Addon:IsHunterMode()
	return self.db.profile.options.hunterMode.enabled;
end

function Addon:SetHunterMode(enable)
	self:debug_print('hunter mode = ' .. tostring(enable));
	self.db.profile.options.hunterMode.enabled = enable;
end

function Addon:GetHunterModeOperation()
	return self.db.profile.options.hunterMode.operation;
end

function Addon:SetHunterModeOperation(value)
	self:debug_print('hunter mode op = ' .. tostring(value));
	self.db.profile.options.hunterMode.operation = value;
end

--Per-character dismount
function Addon:IsPerCharDismount()
	return self.db.profile.options.perCharDismount.enabled;
end

function Addon:SetPerCharDismount(enable)
	self:debug_print('per-char dismount = ' .. tostring(enable));
	self.db.profile.options.perCharDismount.enabled = enable;
	if enable then
		Addon:AddPerCharDismountPet(Addon:GetDismountPetId());
	end
end


--[[ Init/cleanup functions ]]--

function Addon:CreateMountTable()
	--  self:Print('CreateMountTable')

	for i, mountId in ipairs(C_MountJournal.GetMountIDs()) do
		local creatureName, spellId, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(mountId);
		if isCollected and isUsable then
			MountCollection[spellId] = creatureName
		end
	end
end

function Addon:DestroyMountTable()

--	-- Nil out elements
--	for k,v in pairs(MountCollection) do
--		MountCollection[k] = nil
--	end
--	-- Create new table to make sure
--	MountCollection = {}


	MountCollection = wipe(MountCollection);	

end

function Addon:CreatePetSpellIdsTable()
--	Addon:debug_print('num pets = ' .. C_PetJournal.GetNumPets());
--	for i = 1, GetNumCompanions("CRITTER"), 1 do
--		local creatureId, creatureName, spellId, icon, active, mountFlags = GetCompanionInfo("CRITTER", i);
--		Addon:debug_print(creatureName .. ' ' .. spellId);
--		PetSpellIds[spellId] = true;
--	end

--	local petId, speciesId, isOwned, customName, level, favorite, isRevoked, name, icon, petType, a, b, c, d, canBattle = C_PetJournal.GetPetInfoByIndex(1);
	
	local filteredCount, totalCount = C_PetJournal.GetNumPets();
	
--	if totalCount ~= NumPetSpellIds then
		Addon:debug_print('updating PetSpellIds: totalCount = ' .. tostring(totalCount));
		NumPetSpellIds = totalCount;
		local count = 0;
		for i=1,totalCount do
			local petId, speciesId, isOwned, customName, level, favorite, isRevoked, name, icon, petType, a, b, c, d, canBattle = C_PetJournal.GetPetInfoByIndex(i);
			if name then
--				local spellName, spellRank, spellIcon, spellCastingTime, spellMinRange, spellMaxRange, spellId = GetSpellInfo(name);
--				if spellId then
					PetSpellIds[name] = petId;
					count = count + 1;
--				else
--					Addon:debug_print('No spellId for ' .. tostring(name));
--				end
			end
			
--			local creatureId, creatureName, spellId, icon, active, mountFlags = GetCompanionInfo("critter", i);
--			if spellId then
--				Addon:debug_print(tostring(creatureName) .. ' ' .. tostring(creatureId) .. ' ' .. tostring(spellId));
--				count = count + 1;
--			end
				
			
--			local father = "Father";
--			if string.sub(name,1,string.len(father))==father then
--				Addon:debug_print(petId);
-- --				Addon:debug_print(GetItemSpell(name));
-- --				local speciesId, customName, level, xp, maxXp, displayId, isFavorite, petName, petIcon, petType, creatureId, sourceText, description, isWild, canBattle, tradable, unique = C_PetJournal.GetPetInfoByPetID(petId);
--				local name, rank, icon, castingTime, minRange, maxRange, spellId = GetSpellInfo(name);
--				Addon:debug_print(tostring(spellId));
--			end
		end
		Addon:debug_print('Found ' .. tostring(count) .. ' pet names');
--	else
--		Addon:debug_print('PetSpellIds is up to date');
--	end	
end

function Addon:DestroyPetSpellIdsTable()

--	-- Nil out elements
--	for k,v in pairs(PetSpellIds) do
--		PetSpellIds[k] = nil
--	end
--	-- Create new table to make sure
--	PetSpellIds = {}

	PetSpellIds = wipe(PetSpellIds);
end

function Addon:InitTrackingVars()
	PetChangeInProgress = false; 
	NumPetSpellIds = 0;
	StealthPetId = nil;
	PlayerStealthed = self:IsStealthed();
	PlayerMounted = IsMounted();
	PlayerHasHunterPet = IsPetActive();
	DesiredPetId = C_PetJournal.GetSummonedPetGUID();

	self:debug_print('PlayerStealthed = ' .. tostring(PlayerStealthed));
	self:debug_print('PlayerMounted = ' .. tostring(PlayerMounted));
	self:debug_print('PlayerHasHunterPet = ' .. tostring(PlayerHasHunterPet));

	self:UpdatePlayerInfo();
	
	if PlayerHasHunterPet and self:IsHunterMode() then
--		local hunterModeOp = self:GetHunterModeOperation();
--		self:debug_print('hunterModeOp' .. tostring(hunterModeOp));
--		if PlayerMounter and (hunterModeOp == 'summon') then
--			Addon:debug_print('player loaded in and has pet and hunter mode active, but mount summon option set')
--			Addon:HandleMountStart();
--		else
			Addon:debug_print('player loaded in and has pet and hunter mode active')
			Addon:HandleHunterPetSummon();
--		end
	else
		if PlayerMounted then
			Addon:debug_print('player loaded in mounted');
			Addon:HandleMountStart();
		elseif PlayerStealthed then
			Addon:debug_print('player loaded in stealthed');
			Addon:HandleStealthStart();
		end
	end
end

--[[ Utility methods ]]--

function Addon:UpdatePlayerInfo()
	self:SetPlayerInfo({combat = UnitAffectingCombat("player") or UnitAffectingCombat("pet"), dead = UnitIsDead("player"), feigning = Addon:IsFeigning(), casting = false, channeling = false});
--	self:SetPlayerInfo({casting = true});
end

function Addon:SetPlayerInfo(info)
	if info.combat then
		PlayerInfo.combat = info.combat;
	end
	if info.dead then
		PlayerInfo.dead = info.dead;
	end
	if info.feigning then
		PlayerInfo.feigning = info.feigning;
	end
	if info.casting then
		PlayerInfo.casting = info.casting;
	end
	if info.channeling then
		PlayerInfo.channeling = info.channeling;
	end

	Addon:debug_print('PlayerInfo:');
	Addon:debug_tprint(PlayerInfo, 1);
end

function Addon:FindMountSpellId()
	-- No use trying to find a mount if we're not mounted
	if not IsMounted() then
		return nil
	end

	local buffs, i = {}, 1;
	local name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i);
	while name do
		if MountCollection[spellId] then
			return spellId
		end
		i = i + 1;
		name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i);
	end
end

function Addon:FindPetName(petId)
	if not petId then
		return nil
	end

	local _, customName, _, _, _, _, _, petName = C_PetJournal.GetPetInfoByPetID(petId)
	if customName then
		return customName
	else
		return petName
	end
end

function Addon:FindPetBaseName(petId)
	if not petId then
		return nil
	end

	local _, customName, _, _, _, _, _, petName = C_PetJournal.GetPetInfoByPetID(petId)
	return petName
end

function Addon:FindHunterPetName()
	if not IsPetActive() then
		return nil
	end
	
	local name = UnitFullName("pet");
	Addon:debug_print('pet full name - ' .. tostring(name));
	return name;
end

function Addon:FindMountName()
	if not IsMounted() then
		return nil
	end

	local allMounts = C_MountJournal.GetMountIDs()

	for index=1,#allMounts do
		local name, _, _, isActive, isUsable, _, _, _, _, _, _, mountID = C_MountJournal.GetMountInfoByID(allMounts[index])
		if  isUsable and isActive then
			return name
		end
	end
end

function Addon:GetLatencyMillis()
	local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = GetNetStats();
	self:debug_print('latencyHome ' .. latencyHome);
	self:debug_print('latencyWorld ' .. latencyWorld);
	local latency = math.max(latencyHome, latencyWorld);
	if latency == 0 then
		latency = 100;
	end
	return latency;
end

function Addon:IsStealthed()
	local stealthForm = IsStealthed();

	if DEBUG and (not stealthForm) then
		--    self:debug_print('gogo gadget shapeshift')
		stealthForm = (GetShapeshiftFormID() ~= nil);
	--    self:debug_print('fake stealth? = ' .. tostring(stealthForm));
	end

	return stealthForm;
end

function Addon:IsFeigning()
--	local buffs, i = {}, 1;
--	local name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i);
--	while name do
--		if FEIGN_SPELL_ID == spellId then
--			return true;
--		end
--		i = i + 1;
--		name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i);
--	end
--	return false;
	
	return UnitIsFeignDeath('player');
end

function Addon:CanSummonPet()

	if IsFlying()
	or (UnitAffectingCombat("player") or UnitAffectingCombat("pet") or PlayerInfo.combat)
	or (UnitIsDeadOrGhost("player") or PlayerInfo.dead)
	or (UnitIsFeignDeath("player") or PlayerInfo.feigning)
	or PlayerInfo.casting
	or PlayerInfo.channeling
	or PlayerInfo.looting
	or PlayerInfo.controlLost
	or PlayerInfo.sitting
	or UnitOnTaxi("player")
	--UnitHasVehiclePlayerFrameUI
	--UnitIsControlling
	or UnitIsCharmed("player")
	--UnitPlayerControlled("player") ??? is player controllign toon?
	or UnitUsingVehicle("player")
	then
		return false
	end
	return true

end

function Addon:FindPetIdForMountSpellId(mountSpellId)
	if not mountSpellId then
		return nil;
	end
	return self.db.profile.pairs[mountSpellId];
end

function Addon:SetPetIdForMountSpellId(mountSpellId, petId)
	if not mountSpellId then
		return;
	end
	self.db.profile.pairs[mountSpellId] = petId;
end

function Addon:FindPetIdForHunterPetName(hunterPetName)
	if not hunterPetName then
		Addon:debug_print('hunterPetName is nil');
		return nil;
	end
	local petId = self.db.profile.hunterModePairs[hunterPetName];
	Addon:debug_print('hunterPetName pair: ' .. tostring(hunterPetName) .. ' - ' .. tostring(petId));
	return petId;
end

function Addon:SetPetIdForHunterPetName(hunterPetName, petId)
	if not hunterPetName then
		Addon:debug_print('hunterPetName is nil');
		return;
	end
	self.db.profile.hunterModePairs[hunterPetName] = petId;
end

function Addon:FindPetIdForCharacterName(characterName)
	if not characterName then
		Addon:debug_print('characterName is nil');
		return nil;
	end
	local petId = self.db.profile.perCharDismountPairs[characterName];
	Addon:debug_print('characterName pair: ' .. tostring(characterName) .. ' - ' .. tostring(petId));
	return petId;
end

function Addon:SetPetIdForCharacterName(characterName, petId)
	if not characterName then
		Addon:debug_print('characterName is nil');
		return;
	end
	self.db.profile.perCharDismountPairs[characterName] = petId;
end

function Addon:IsPetSpellId(spellId)
	Addon:debug_print('IsPetSpellId - ' .. tostring(spellId) .. tostring(PetSpellIds[spellId]));
	return PetSpellIds[spellId];
end

--	if petId == C_PetJournal.GetSummonedPetGUID() then
function Addon:IsCurrentPet(petId)
	if petId then
		local currentPetId = C_PetJournal.GetSummonedPetGUID();
--		Addon:debug_print('currentPetId = ' .. tostring(currentPetId));
		if petId == currentPetId then
			--GUIDs match
--			Addon:debug_print('pet GUIDs match');
			return true;
		else
			--See if base name matches
			local paramBaseName = Addon:FindPetBaseName(petId);
			local summonedBaseName = Addon:FindPetBaseName(currentPetId);
			if paramBaseName == summonedBaseName then
--				Addon:debug_print('Base names match');
				return true;
			end
			return false;
		end
	end
	return false;
end

function Addon:CancelTimers()
	if SummonTimerId then
		Addon:debug_print("cancelling summon timer");
		Addon:CancelTimer(SummonTimerId);
		SummonTimerId = nil;
	end
	if DismissTimerId then
		Addon:debug_print("cancelling dismiss timer");
		Addon:CancelTimer(DismissTimerId);
		DismissTimerId = nil;
	end
end

--[[ Debug ]]--
function Addon:debug_print(message)
	if DEBUG and message then
		print(message)
	end
end

-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
function Addon:debug_tprint (tbl, indent)
	if DEBUG and tbl then
		if not indent then indent = 0 end
		for k, v in pairs(tbl) do
			formatting = string.rep("  ", indent) .. k .. ": "
			if type(v) == "table" then
				Addon:debug_print(formatting)
				Addon:debug_tprint(v, indent+1)
			elseif type(v) == 'boolean' then
				Addon:debug_print(formatting .. tostring(v))
			else
				Addon:debug_print(formatting .. v)
			end
		end
	end
end

--[[ Event handling ]]--

function Addon:RegenEnabledEventHandler()
	Addon:debug_print('RegenEnabledEventHandler');
	PlayerInfo.combat = false;
end

function Addon:RegenDisabledEventHandler()
	Addon:debug_print('RegenDisabledEventHandler');
	PlayerInfo.combat = true;
end

function Addon:LootStartedHandler()
	Addon:debug_print('LootStartedHandler');
	PlayerInfo.looting = true;
end

function Addon:LootStoppedHandler()
	Addon:debug_print('LootStoppedHandler');
	PlayerInfo.looting = false;
end

function Addon:ControlLostStartedHandler()
	Addon:debug_print('ControlLostStartedHandler');
	PlayerInfo.controlLost = true;
end

function Addon:ControlLostStoppedHandler()
	Addon:debug_print('ControlLostStoppedHandler');
	PlayerInfo.controlLost = false;
end

function Addon:PlayerDeadEventHandler()
	Addon:debug_print('PlayerDeadEventHandler');
	PlayerInfo.dead = true;
end

function Addon:PlayerAliveEventHandler()
	Addon:debug_print('PlayerAliveEventHandler');
	PlayerInfo.dead = false;
end

function Addon:SpellcastSentEventHandler(unitId, spellName, rank, target, lineId)
	if unitId == "player" then
		Addon:debug_print('SpellcastSentEventHandler');
		Addon:CastStart();
	end
end

function Addon:SpellcastStartEventHandler(unitId, spellName, rank, lineId, spellId)
	if unitId == "player" then
		Addon:debug_print('SpellcastStartEventHandler: unitId = ' .. tostring(unitId));
		Addon:CastStart();
		
		Addon:debug_print('**** ' .. tostring(spellName) .. ' ' .. tostring(spellId) .. ' ' .. tostring(lineId));
		if Addon:IsPetSpellId(spellName) then
			Addon:debug_print('**** pet spell id');
			DesiredPetId = Addon:IsPetSpellId(spellName);
	--		Addon:debug_print('**** ' .. tostring(C_PetJournal.GetSummonedPetGUID()));
		end
		
	--	local spell, rank, displayName, icon, startTime, endTime, isTradeSkill, castID, interrupt = UnitCastingInfo("player");
	--	Addon:debug_print('**** ' .. tostring(displayName));	
	end
end

function Addon:SpellcastInterruptedEventHandler(unitId, spellName, rank, lineId, spellId)
	if unitId == "player" then
		Addon:debug_print('SpellcastInterruptedEventHandler');
		Addon:CastStop();
	end
end

function Addon:SpellcastStopEventHandler(unitId, spellName, rank, lineId, spellId)
	if unitId == "player" then
		Addon:debug_print('SpellcastStopEventHandler');
		Addon:CastStop();
	end
end

function Addon:SpellcastFailedEventHandler(unitId, spellName, rank, lineId, spellId)
	if unitId == "player" then
		Addon:debug_print('SpellcastFailedEventHandler');
		Addon:CastStop();
	end
end

function Addon:SpellcastFailedQuietEventHandler(unitId, spellName, rank, lineId, spellId)
	if unitId == "player" then
		Addon:debug_print('SpellcastFailedQuietEventHandler');
		Addon:CastStop();
	end
end

function Addon:SpellcastSucceededEventHandler(unitId, spellName, rank, lineId, spellId)
	if unitId == "player" then
		Addon:debug_print('SpellcastSucceededEventHandler: unitId = ' .. tostring(unitId));
		Addon:CastStop();
	
		Addon:debug_print('**** ' .. tostring(spellName) .. ' ' .. tostring(spellId) .. ' ' .. tostring(lineId));
		if Addon:IsPetSpellId(spellName) then
			Addon:debug_print('**** pet spell id');
			DesiredPetId = Addon:IsPetSpellId(spellName)
	--		Addon:debug_print('**** ' .. tostring(C_PetJournal.GetSummonedPetGUID()));
		end
	
	--	local spell, rank, displayName, icon, startTime, endTime, isTradeSkill, castID, interrupt = UnitCastingInfo("player");
	--	Addon:debug_print('**** ' .. tostring(displayName));	
	end
	
	Addon:debug_print('>>>> spellcast succeed ' .. tostring(spellName));
end

function Addon:ChannelStartEventHandler(unitId, spellName, rank, lineId, spellId)
	if unitId == "player" then
		Addon:debug_print('ChannelStartEventHandler');
		Addon:ChannelStart();
	end
end

function Addon:ChannelStopEventHandler(unitId, spellName, rank, lineId, spellId)
	if unitId == "player" then
		Addon:debug_print('ChannelStopEventHandler');
		Addon:ChannelStop();
	end
end

function Addon:CastStart()
	Addon:debug_print('CastStart');
	PlayerInfo.casting = true;
end

function Addon:CastStop()
	Addon:debug_print('CastStop');
	PlayerInfo.casting = false;
end

function Addon:ChannelStart()
	Addon:debug_print('ChannelStart');
	PlayerInfo.channeling = true;
end

function Addon:ChannelStop()
	Addon:debug_print('ChannelStop');
	PlayerInfo.channeling = false;
	Addon:CastStop();
end

function Addon:CompanionUpdateEvent()
--	Addon:debug_print('CompanionUpdateEvent');
	Addon:CreatePetSpellIdsTable();
end

--[[ MountJournal list overlay ]]--
function Addon:CreateMountJournalOverlays()

	local scrollFrame = MountJournal.ListScrollFrame;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;

	local numDisplayedMounts = C_MountJournal.GetNumDisplayedMounts();
	for i=1, #buttons do
		local button = buttons[i];
		local displayIndex = i + offset;

		if displayIndex <= numDisplayedMounts then
			local index = displayIndex;
			local creatureName, mountSpellId, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountId = C_MountJournal.GetDisplayedMountInfo(index);

			if (not isFiltered) and isUsable and isCollected and Addon:FindPetIdForMountSpellId(mountSpellId) then
				if not button["minime"] then
					local texture = button:CreateTexture("minime" .. mountSpellId, "OVERLAY")
					texture:SetParent(button)
					local iconPath = ([[Interface\Addons\%s\%s]]):format(AddonName, AddonName)
					texture:SetTexture(iconPath)
					texture:SetSize(16, 16)
					texture:SetPoint("CENTER", button.icon, 18, -18)
					button["minime"] = texture
				end
				button.minime:Show()
			else
				if button.minime then
					button.minime:Hide()
				end
			end
		else
			if button.minime then
				button.minime:Hide()
			end
		end
	end
end

function Addon:UpdateMountJournalOverlays()
	Addon:debug_print('UpdateMountJournalOverlays');

	if MountJournal and MountJournal.ListScrollFrame:IsVisible() then
		MountJournal.ListScrollFrame:update()
	end

end

function Addon:Hook_MountJournal_UpdateMountList()

	hooksecurefunc(MountJournal.ListScrollFrame, "update", function()
		self:CreateMountJournalOverlays()
	end)

	MountJournal.ListScrollFrame:update()

end

function Addon:UpdateMountJournalTooltip(button)

	if button and button.spellID then
		local petId = Addon:FindPetIdForMountSpellId(button.spellID);

		if petId then
			local petName = self:FindPetName(petId)

			if petName then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine("|cFF33FF99Mount Mini-Me|r: " .. petName, true)
				GameTooltip:Show()
			end
		end
	end
end

function Addon:Hook_MountJournalMountButton_UpdateTooltip()

	hooksecurefunc("MountJournalMountButton_UpdateTooltip", function(button)
		self:UpdateMountJournalTooltip(button)
	end)
end

--function Addon:Hook_SitStandOrDescendStart()
--	Addon:debug_print("SitStandOrDescendStart hook");
--	
--	hooksecurefunc("SitStandOrDescendStart", function()
--		Addon:debug_print("SitStandOrDescendStart called");
--	end)
--end

--function Addon:Hook_DismissCompanion()
--
--	hooksecurefunc("DismissCompanion", function(button)
--		Addon:debug_print('DismissCompanion');
--	end)
--end

--==============================================================================
--Hook this so manually summoned/dismissed pets stick
local old_C_PetJournal_SummonPetByGUID = C_PetJournal.SummonPetByGUID;
function postHook_C_PetJournal_SummonPetByGUID(petId, ...)
	Addon:debug_print('postHook_C_PetJournal_SummonPetByGUID - petId = ' .. tostring(petId));
--	if petId == C_PetJournal.GetSummonedPetGUID() then
	if Addon:IsCurrentPet(petId) then
		DesiredPetId = nil
	else
		DesiredPetId = petId;
	end
end
function C_PetJournal.SummonPetByGUID(petId)
	postHook_C_PetJournal_SummonPetByGUID(petId, old_C_PetJournal_SummonPetByGUID(petId));
end

function Addon:SittingStart()
	Addon:debug_print('SittingStart');
	PlayerInfo.sitting = true;
end

function Addon:SittingStop()
	Addon:debug_print('SittingStop');
	PlayerInfo.sitting = false;
end

function Addon:SitStandOrDescendStart()
	Addon:debug_print('SitStandOrDescendStart called');
	if PlayerInfo.sitting then
		Addon:SittingStop();
	else
		Addon:SittingStart();
	end
end

function Addon:JumpOrAscendStart()
	Addon:debug_print('JumpOrAscendStart called');
	Addon:SittingStop();
end

function Addon:MoveAndSteerStart()
	Addon:debug_print('MoveAndSteerStart called');
	Addon:SittingStop();
end

function Addon:MoveBackwardStart()
	Addon:debug_print('MoveBackwardStart called');
	Addon:SittingStop();
end

function Addon:MoveForwardStart()
	Addon:debug_print('MoveForwardStart called');
	Addon:SittingStop();
end

function Addon:StrafeLeftStart()
	Addon:debug_print('StrafeLeftStart called');
	Addon:SittingStop();
end

function Addon:StrafeRightStart()
	Addon:debug_print('StrafeRightStart called');
	Addon:SittingStop();
end

function Addon:ToggleAutoRun()
	Addon:debug_print('ToggleAutoRun called');
	Addon:SittingStop();
end

function Addon:TurnLeftStart()
	Addon:debug_print('TurnLeftStart called');
	Addon:SittingStop();
end

function Addon:TurnRightStart()
	Addon:debug_print('TurnRightStart called');
	Addon:SittingStop();
end

function Addon:TurnOrActionStart()
	Addon:debug_print('TurnOrActionStart called');
	Addon:SittingStop();
end

--===============================================================================
--local old_CallCompanion = CallCompanion;
--function postHook_CallCompanion(type, index, ...)
--	Addon:debug_print('postHook_CallCompanion - type = ' .. tostring(type) .. ', index = ' .. tostring(index));
--end
--function CallCompanion(type, index)
--	postHook_CallCompanion(type, index, old_CallCompanion(type, index));
--end

--===============================================================================
--local old_DismissCompanion = DismissCompanion;
--function postHook_DismissCompanion(type, ...)
--	Addon:debug_print('postHook_DismissCompanion - type = ' .. tostring(type));
--end
--function DismissCompanion(type)
--	postHook_CallCompanion(type, old_DismissCompanion(type));
--end

--local oldDismount = Dismount;
--function Addon:Hook_Dismount(...)
--
--	Addon:debug_print('Dismount');
--
--end
--
--function Dismount()
--	Addon:Hook_Dismount(oldDismount());
--end

--C_MountJournal.Dismiss();
--local oldDismiss = C_MountJournal.Dismiss;
--function postHookDismiss()
--	Addon:debug_print('postHookDismiss');
--end
--function C_MountJournal.Dismiss()
--	postHookDismiss(oldDismiss());
--end


--C_MountJournal.SummonByID(mountId);


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
--		Addon:Hook_DismissCompanion();
--		Addon:Hook_Dismount();

--		Addon:CreatePetSpellIdsTable();

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

--[[ Pairing functions ]]--
function Addon:AddMountPair()
	self:debug_print('AddMountPair');
	self:debug_print('hunter mode = ' .. tostring(self:IsHunterMode()));
	
	if (not IsMounted()) and (not self:IsDetectDismount() and not self:IsHunterMode()) then
		self:Print(L.NotMountedError);
		return
	end

	local petId = C_PetJournal.GetSummonedPetGUID();

	if not petId then
		self:Print(L.NoPetSummoned);
		return;
	end

	if IsMounted() then
		local mountSpellId = self:FindMountSpellId();

		if mountSpellId then
			Addon:SetPetIdForMountSpellId(mountSpellId, petId);
			self:Print(format(L.PairAdded, self:FindPetName(petId), self:FindMountName()));
			self:UpdateMountJournalOverlays();
		end
	else
		if IsPetActive() and self:IsHunterMode() then
			self:debug_print('Adding hunter pet: petId = ' .. tostring(petId));
--			local petGUID = UnitGUID("pet");
--			Addon:debug_print('pet GUID - ' .. tostring(petGUID));
			
--			self.db.profile.hunterModePairs[petGUID] = petId;
			local hunterPetName = self:FindHunterPetName();
			Addon:SetPetIdForHunterPetName(hunterPetName, petId);
			self:Print(format(L.HunterPairAdded, self:FindPetName(petId), hunterPetName));			
		else
			self:debug_print('Adding dismount pet: petId = ' .. tostring(petId));
			self:Print(format(L.DismountedPairAdded, self:FindPetName(petId)));
			if Addon:IsPerCharDismount() then
				Addon:AddPerCharDismountPet(petId);
			else
				self:SetDismountPetId(petId);
			end
		end
	end
end

function Addon:ClearMountPair()
	self:debug_print('ClearMountPair');
	self:debug_print('hunter mode = ' .. tostring(self:IsHunterMode()));

	if not IsMounted() and (not self:IsDetectDismount() and not self:IsHunterMode()) then
		self:Print(L.NotMountedError);
		return
	end

	if IsMounted() then
		local mountSpellId = self:FindMountSpellId();

		if mountSpellId then
			local oldPet = Addon:FindPetIdForMountSpellId(mountSpellId);
			Addon:SetPetIdForMountSpellId(mountSpellId, nil);
			local oldPetName = self:FindPetName(oldPet);
			if oldPetName then
				self:Print(format(L.PairCleared, oldPetName, self:FindMountName()));
				self:UpdateMountJournalOverlays();
			end
		end
	else
		if IsPetActive() and self:IsHunterMode() then
			self:debug_print('Clearing hunter pet');
--			local petGUID = UnitGUID("pet");
--			Addon:debug_print('pet GUID - ' .. tostring(petGUID));

			local hunterPetName = self:FindHunterPetName();
			local oldPet = Addon:FindPetIdForHunterPetName(hunterPetName);
			Addon:SetPetIdForHunterPetName(hunterPetName, nil);
			local oldPetName = self:FindPetName(oldPet)
			
			self:Print(format(L.HunterPairCleared, oldPetName, hunterPetName));			
		else
			self:debug_print('Clearing dismount pet');
			self:Print(L.DismountedPairCleared)
			self:SetDismountPetId(nil);
		end
	end
end

function Addon:ResummonPet()
	self:debug_print('ResummonPet');
	self:debug_print('hunter mode = ' .. tostring(self:IsHunterMode()));

	if not IsMounted() and (not self:IsDetectDismount() and not self:IsHunterMode()) then
		self:Print(L.NotMountedError)
		return
	end
	
	if IsMounted() then
		self:debug_print('Resummon mount pet');
		local mountSpellId = self:FindMountSpellId()
		Addon:SummonPet(Addon:FindPetIdForMountSpellId(mountSpellId));
	else
		if IsPetActive() and self:IsHunterMode() then
			self:debug_print('Resummon hunter pet');
--			local petGUID = UnitGUID("pet");
			local hunterPetName = Addon:FindHunterPetName();
			Addon:SummonPet(Addon:FindPetIdForHunterPetName(hunterPetName));
		else
			self:debug_print('Resummon dismount pet');
			Addon:SummonPet(Addon:GetDismountPetId());
		end
	end
	
end

function Addon:AddPerCharDismountPet(petId)
	if not petId then
		return;
	end
	
	Addon:SetPetIdForCharacterName(UnitFullName("player"), petId);
end

--[[ Summon/Dismiss related event handling ]]--

--Mount summoning
function Addon:UnitAuraEventHandler()
--	Addon:debug_print('UnitAuraEventHandler');

--	Addon:debug_print('PlayerStealthed = ' .. tostring(PlayerStealthed));
--	Addon:debug_print('IsStealthed = ' .. tostring(Addon:IsStealthed()));

	
--    if unit ~= "player" then
--        return
--    end
    
	local wasPlayerMounted = PlayerMounted;
	PlayerMounted = IsMounted();
	
	if PlayerMounted and (not wasPlayerMounted) then
		Addon:debug_print('mount');
		Addon:HandleMountStart();
	elseif (not PlayerMounted) and wasPlayerMounted then
		Addon:debug_print('dismount');
		Addon:HandleMountEnd();
	end

end

function Addon:HandleMountStart()
	Addon:debug_print('HandleMountStart');
	
	StealthPetId = nil;
	
	local hunterModeOp = self:GetHunterModeOperation();
	self:debug_print('hunterModeOp' .. tostring(hunterModeOp));
	
	if Addon:IsHunterMode() and IsPetActive() and (hunterModeOp == 'keep') then
		Addon:debug_print('Hunter mode active, not summoning mount pet');
		return;
	end
	local mountSpellId = Addon:FindMountSpellId()
	Addon:SummonPet(Addon:FindPetIdForMountSpellId(mountSpellId));	
end

function Addon:HandleMountEnd()
	Addon:debug_print('HandleMountEnd');

	local hunterModeOp = self:GetHunterModeOperation();
	self:debug_print('hunterModeOp' .. tostring(hunterModeOp));

	if Addon:IsHunterMode() and IsPetActive() and (hunterModeOp == 'keep') then
		Addon:debug_print('Hunter mode active, not summoning dismount pet');
		return;
	elseif Addon:IsHunterMode() and IsPetActive() and (hunterModeOp == 'summon') then
		Addon:debug_print('Dismount, hunter mode active, summoning hunter pet');
		Addon:HandleHunterPetSummon();
		return;
	end
	
	Addon:CheckAndSummonDismountPet();
end

--Hunter pet summoning
function Addon:UnitPetEventHandler(unitId)
	Addon:debug_print('UnitPetEventHandler - unitId = ' .. tostring(unitId));
	if not unitId or unitId == "player" then
	
		Addon:debug_print('UnitPetEventHandler');
		
		local playerHadHunterPet = PlayerHasHunterPet;
		PlayerHasHunterPet = IsPetActive();
		
		Addon:debug_print('playerHadHunterPet = ' .. tostring(playerHadHunterPet));
		Addon:debug_print('PlayerHasHunterPet = ' .. tostring(PlayerHasHunterPet));
		
		local hunterModeOp = Addon:GetHunterModeOperation();
		Addon:debug_print('hunterModeOp' .. tostring(hunterModeOp));
		if IsMounted() and (hunterModeOp == 'summon') then
			Addon:debug_print('Player is mounted and hunterModeOp is summon');
			return;
		end
		
		if PlayerHasHunterPet and (not playerHadHunterPet) then
			Addon:debug_print('petGUID = ' .. tostring(UnitGUID("pet")));
		
			Addon:debug_print('hunter pet summoned');
			Addon:HandleHunterPetSummon();
		elseif (not PlayerHasHunterPet) and playerHadHunterPet then
			Addon:debug_print('hunter pet dismissed');
			Addon:HandleHunterPetDismiss();
		elseif playerHadHunterPet and PlayerHasHunterPet then
			Addon:debug_print('hunter pet switch (for handling warlock pets that dont need to be manually dismissed to change)');
			Addon:HandleHunterPetSummon();
		end
	end
end

function Addon:HandleHunterPetSummon()
	Addon:debug_print('HandleHunterPetSummon');

--	local petGUID = UnitGUID("pet");
--	Addon:SummonPet(Addon:FindPetIdForHunterPetGUID(petGUID));	

	local hunterPetName = Addon:FindHunterPetName();
	Addon:SummonPet(Addon:FindPetIdForHunterPetName(hunterPetName));	
end

function Addon:HandleHunterPetDismiss()
	Addon:debug_print('HandleHunterPetDismiss');
	
	PlayerHasHunterPet = IsPetActive();
	
	Addon:CheckAndSummonDismountPet();
end

--function Addon:SummonOnEvent()
--	Addon:debug_print('SummonOnEvent');
--	
--	
--	--Check stealth status
--	local stealthForm = Addon:IsStealthed();
--	local stealthStart = stealthForm and (not PlayerStealthed);
--	local stealthEnd = (not stealthForm) and PlayerStealthed;
--end

--Stealth summoning
function Addon:UpdateStealthEventHandler()
	Addon:debug_print('UpdateStealthEventHandler');
	
	local wasPlayerStealthed = PlayerStealthed;
	PlayerStealthed = Addon:IsStealthed();
	
	if PlayerStealthed and (not wasPlayerStealthed) then
		Addon:debug_print('stealth start');
		Addon:HandleStealthStart();
	elseif (not PlayerStealthed) and wasPlayerStealthed then
		Addon:debug_print('stealth end');
		Addon:HandleStealthEnd();
	end
end

function Addon:HandleStealthStart()
	Addon:debug_print('HandleStealthStart');

	if Addon:IsDismissOnStealth() then
		local currentPetId = C_PetJournal.GetSummonedPetGUID();
		StealthPetId = currentPetId;
		Addon:debug_print('storing pet id - ' .. tostring(StealthPetId));
		if currentPetId then
			Addon:DismissPet();
		end
	end
end

function Addon:HandleStealthEnd()
	Addon:debug_print('HandleStealthEnd');

--	if PlayerStealthed then
		Addon:debug_print('resummon after leave stealth');
		if StealthPetId then
			Addon:debug_print('resummon petId = ' .. tostring(StealthPetId));
			Addon:SummonPet(StealthPetId);
		elseif self:IsDetectDismount() and (not C_PetJournal.GetSummonedPetGUID()) then
			Addon:debug_print('summon dismount pet');
			Addon:CheckAndSummonDismountPet();
		end
		StealthPetId = nil;
--	end
end

--Summoning
function Addon:CheckAndSummonDismountPet()
--	self:debug_print('detecting dismount is true');
	local dismountOp = self:GetDismountOperation();
	self:debug_print('dismountOp = ' .. tostring(dismountOp));
	if dismountOp == 'summon' then
		local petId = self:FindPetIdForCharacterName(UnitFullName("player"));
		if Addon:IsPerCharDismount() and petId then
			self:debug_print('dismount summon: petId = ' .. tostring(petId));
			self:SummonPet(petId);
		else
			petId = self:GetDismountPetId();
			self:debug_print('dismount summon: petId = ' .. tostring(petId));
			--        self:CallSummonPetByGUID(self:GetDismountPetId());
			self:SummonPet(petId);
		end
	elseif dismountOp == 'dismiss' then
		self:debug_print('dismount dismiss');
		--        DismissCompanion("CRITTER");
		self:DismissPet();
	end
end

function Addon:RepeatingSummonPet()
--	Addon:debug_print('.');
--	local currentPetId = C_PetJournal.GetSummonedPetGUID();
--	if DesiredPetId and not (currentPetId == DesiredPetId) then
	if DesiredPetId and not Addon:IsCurrentPet(DesiredPetId) then
		Addon:debug_print('RepeatingSummonPet');
		Addon:SummonPet(DesiredPetId);
	end
end

function Addon:SummonPet(petId)
--	Addon:debug_print("SummonPet - " .. tostring(petId));

--	if DismissTimerId then
--		Addon:debug_print("cancelling dismiss timer");
--		Addon:CancelTimer(DismissTimerId);
--		DismissTimerId = nil;
--	end

	if PlayerStealthed or Addon:IsStealthed() then
		Addon:debug_print('summon - stealthed, no call');
		return;
	end

	if PetChangeInProgress then
		Addon:debug_print('summon - pet change in progress');
	end
	PetChangeInProgress = true;

	Addon:CancelTimers();

	DesiredPetId = petId;
	
--	if not DesiredPetId then
--		Addon:DismissPet();
--		return;
--	end
	
	local currentPetId = C_PetJournal.GetSummonedPetGUID()
	Addon:debug_print('Current pet: ' .. tostring(currentPetId));
	if Addon:IsCurrentPet(DesiredPetId) then
--		Addon:debug_print('Requested pet is already active');
		return;
	elseif not Addon:IsCurrentPet(DesiredPetId) then
		Addon:debug_print('Summoning desired pet: ' .. tostring(DesiredPetId));
		if self:CanSummonPet() then
			self:CallSummonPetByGUID(petId);
			PetChangeInProgress = false;
		else
			self:debug_print('Cannot summon now');
			self:debug_print('PlayerInfo:');
			self:debug_tprint(PlayerInfo, 1);
			
			SummonTimerId = self:ScheduleTimer("SummonPet", 0.5, petId);
		end
	end
	
end

function Addon:CallSummonPetByGUID(petId)
	self:debug_print('CallSummonPetByGUID')
	if petId then
		local delay = self:GetLatencyMillis()/1000.0;
		self:debug_print('summon delay ' .. delay);
		self:ScheduleTimer("CallSummonPetByGUID_Callback", delay, petId);
	end
end

function Addon:CallSummonPetByGUID_Callback(petId)
	self:debug_print('CallSummonPetByGUID_Callback: petId = ' .. tostring(petId))
--	if petId and (petId ~= C_PetJournal.GetSummonedPetGUID()) then
	if petId and not Addon:IsCurrentPet(petId) then
		self:debug_print('summoning pet ' .. tostring(petId));
		C_PetJournal.SummonPetByGUID(petId);
	else
		self:debug_print('petId is nil or already summoned: ' .. tostring(petId));
	end
end

--Dismissing
function Addon:DismissPet()
	self:debug_print('DismissPet');

--	if PlayerStealthed or Addon:IsStealthed() then
--		Addon:debug_print('dismiss - stealthed, no call');
--		return;
--	end
	
	if PetChangeInProgress then
		Addon:debug_print('dismiss - pet change in progress');
	end
	PetChangeInProgress = true;
	
	DesiredPetId = nil;

	Addon:CancelTimers();

	if not C_PetJournal.GetSummonedPetGUID() then
		Addon:debug_print('No pet is active');
		return;
	end
	
	if self:CanSummonPet() then
		self:CallDismissCompanion();
		PetChangeInProgress = false;
	else
		self:debug_print('Cannot dismiss now');
		self:debug_print('PlayerInfo:');
		self:debug_tprint(PlayerInfo, 1);
		
		DismissTimerId = self:ScheduleTimer("DismissPet", 0.5);
	end

end

function Addon:CallDismissCompanion()
--	self:debug_print('CallDismissCompanion');
--
--	local delay = 100;
--	if not delayMillis then
--		delay = self:GetLatencyMillis();
--	else
--		delay = delayMillis;
--	end
--	delay = delay/1000.0;
--	self:debug_print('dismiss delay ' .. delay);
--	self:ScheduleTimer("CallDismissCompanion_Callback", delay);

	self:debug_print('CallDismissCompanion')
--	if petId then
		local delay = self:GetLatencyMillis()/1000.0;
		self:debug_print('dismiss delay ' .. delay);
		self:ScheduleTimer("CallDismissCompanion_Callback", delay);
--	end

end

function Addon:CallDismissCompanion_Callback()
	self:debug_print('CallDismissCompanion_Callback');

	local currentPetId = C_PetJournal.GetSummonedPetGUID();
	self:debug_print('current pet (before dismiss) = ' .. tostring(currentPetId))

	if currentPetId then
		C_PetJournal.SummonPetByGUID(currentPetId);
	end

	currentPetId = C_PetJournal.GetSummonedPetGUID();
	self:debug_print('current pet (after dismiss) = ' .. tostring(currentPetId))
end

