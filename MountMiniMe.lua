--[[ MountMiniMe.lua ]]--

local AddonName, AddonTable = ...
local Addon = LibStub('AceAddon-3.0'):NewAddon(AddonTable, AddonName, 'AceBucket-3.0', 'AceEvent-3.0', 'AceConsole-3.0', 'AceTimer-3.0')
local L = LibStub('AceLocale-3.0'):GetLocale(AddonName)

local DEBUG = false;

local CURRENT_VERSION = GetAddOnMetadata(AddonName, 'Version')
local CONFIG_ADDON_NAME = AddonName .. '_Config'

local MountCollection = {}
local StealthPetId, PlayerStealthed, PlayerMounted

local PlayerInfo = {
	combat = false,
	dead = false,
	feigning = false,
	casting = false,
	channeling = false,
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
	
	--Mount Journal
	self:RegisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED", Addon.UpdateMountJournalOverlays);
	
--	self:RegisterEvent('UNIT_PET', Addon.UnitPetEventHandler);
	self:RegisterBucketEvent("UNIT_PET", 0.5, Addon.UnitPetEventHandler);
end

function Addon:OnEnable()
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
				},
			},
			hunterModePairs = {
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
			module:Load()
		end
	end


	for i, module in self:IterateModules() do
		local success, msg = pcall(module_load, module)
		if not success then
			self:Printf('Failed to load %s\n%s', module:GetName(), msg)
		end
	end

	self:CreateMountTable()
	self:InitTrackingVars()
end

--unload is called when we're switching profiles
function Addon:Unload()
	local module_unload = function(module)
		if module.Unload then
			module:Unload()
		end
	end

	--unload any module stuff
	for i, module in self:IterateModules() do
		local success, msg = pcall(module_unload, module)
		if not success then
			self:Printf('Failed to unload %s\n%s', module:GetName(), msg)
		end
	end

	self:DestroyMountTable()
	self:InitTrackingVars()
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

	-- Nil out elements
	for k,v in pairs(MountCollection) do
		MountCollection[k] = nil
	end
	-- Create new table to make sure
	MountCollection = {}
end

function Addon:InitTrackingVars()
	StealthPetId = nil;
	PlayerStealthed = self:IsStealthed();
	PlayerMounted = IsMounted();

	self:debug_print('PlayerStealthed = ' .. tostring(PlayerStealthed));
	self:debug_print('PlayerMounted = ' .. tostring(PlayerMounted));

	self:UpdatePlayerInfo();
end

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

--[[ Mount pairing functions ]]--

function Addon:AddMountPair()
	self:debug_print('AddMountPair');
	self:debug_print('hunter mode = ' .. tostring(self:IsHunterMode()));
	
	if (not IsMounted()) and (not self:IsDetectDismount() and not self:IsHunterMode()) then
		self:Print(L.NotMountedError)
		return
	end

	local petId = C_PetJournal.GetSummonedPetGUID()

	if not petId then
		self:Print(L.NoPetSummoned)
		return
	end

	if IsMounted() then
		local mountSpellId = self:FindMountSpellId()

		if mountSpellId then
			self.db.profile.pairs[mountSpellId] = petId
			self:Print(format(L.PairAdded, self:FindPetName(petId), self:FindMountName()))
			self:UpdateMountJournalOverlays()
		end
	else
		if IsPetActive() and self:IsHunterMode() then
			self:debug_print('Adding hunter pet: petId = ' .. tostring(petId));
			local petGUID = UnitGUID("pet");
			Addon:debug_print('pet GUID - ' .. tostring(petGUID));
			
			self.db.profile.hunterModePairs[petGUID] = petId;
			self:Print(format(L.HunterPairAdded, self:FindPetName(petId), self:FindHunterPetName()));			
		else
			self:debug_print('Adding dismount pet: petId = ' .. tostring(petId));
			self:Print(format(L.DismountedPairAdded, self:FindPetName(petId)))
			self:SetDismountPetId(petId);
		end
	end
end

function Addon:ClearMountPair()
	self:debug_print('ClearMountPair');
	self:debug_print('hunter mode = ' .. tostring(self:IsHunterMode()));

	if not IsMounted() and (not self:IsDetectDismount() and not self:IsHunterMode()) then
		self:Print(L.NotMountedError)
		return
	end

	if IsMounted() then
		local mountSpellId = self:FindMountSpellId()

		if mountSpellId then
			local oldPet = self.db.profile.pairs[mountSpellId]
			self.db.profile.pairs[mountSpellId] = nil
			local oldPetName = self:FindPetName(oldPet)
			if oldPetName then
				self:Print(format(L.PairCleared, oldPetName, self:FindMountName()))
				self:UpdateMountJournalOverlays()
			end
		end
	else
		if IsPetActive() and self:IsHunterMode() then
			self:debug_print('Clearing hunter pet');
			local petGUID = UnitGUID("pet");
			Addon:debug_print('pet GUID - ' .. tostring(petGUID));

			local oldPet = self.db.profile.hunterModePairs[petGUID]
			self.db.profile.hunterModePairs[petGUID] = nil;
			local oldPetName = self:FindPetName(oldPet)
			
			self:Print(format(L.HunterPairCleared, oldPetName, self:FindHunterPetName()));			
		else
			self:debug_print('Clearing dismount pet');
			self:Print(L.DismountedPairCleared)
			self:SetDismountPetId(nil);
		end
	end
end

function Addon:SummonMountPet()
	self:debug_print('SummonMountPet');
	self:debug_print('hunter mode = ' .. tostring(self:IsHunterMode()));

	if not IsMounted() then
		self:Print(L.NotMountedError)
		return
	end

	local mountSpellId = self:FindMountSpellId()

	local petId = self.db.profile.pairs[mountSpellId]
	if petId then
		self:SummonMountPetById(mountSpellId)
	else
		self:Print(format(L.NoPetForMount, self:FindMountName()))
	end
end

function Addon:SummonMountPetById(mountSpellId)

	if mountSpellId then
		local petId = self.db.profile.pairs[mountSpellId]
		local currentPetId = C_PetJournal.GetSummonedPetGUID()

		if petId and (petId ~= currentPetId) then
			self:SummonPet(petId);
		end
	end
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

--[[ Mount summon/dismiss functions ]]--
function Addon:CheckAndSummonDismountPet()
	self:debug_print('detecting dismount is true');
	local dismountOp = self:GetDismountOperation();
	self:debug_print('dismountOp = ' .. tostring(dismountOp));
	if dismountOp == 'summon' then
		self:debug_print('dismount summon: petId = ' .. tostring(self:GetDismountPetId()));
		--        self:CallSummonPetByGUID(self:GetDismountPetId());
		self:SummonPet(self:GetDismountPetId());
	elseif dismountOp == 'dismiss' then
		self:debug_print('dismount dismiss');
		--        DismissCompanion("CRITTER");
		self:DismissPet();
	end
end

function Addon:DismissPet(delayMillis)
	self:debug_print('DismissPet');
	self:CallDismissCompanion(delayMillis);
end

function Addon:CallDismissCompanion(delayMillis)
	self:debug_print('CallDismissCompanion');

	local delay = 100;
	if not delayMillis then
		delay = self:GetLatencyMillis();
	else
		delay = delayMillis;
	end
	delay = delay/1000.0;
	self:debug_print('dismiss delay ' .. delay);
	self:ScheduleTimer("CallDismissCompanion_Callback", delay);
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

function Addon:SummonPet(petId)
	self:debug_print('SummonPet');
	
	if petId and (petId == C_PetJournal.GetSummonedPetGUID()) then
		Addon:debug_print('Requested pet is already active');
		return;
	end
	
	if self:CanSummonPet() then
		self:CallSummonPetByGUID(petId);
	else
		self:debug_print('Cannot summon now');
		self:debug_print('PlayerInfo:');
		self:debug_tprint(PlayerInfo, 1);
		
		self:ScheduleTimer("SummonPet", 0.5, petId);
	end
end

function Addon:SummonHunterPet()
	if IsPetActive() and Addon:IsHunterMode() then
		local petGUID = UnitGUID("pet");
		Addon:debug_print('pet GUID ' .. tostring(petGUID));
		Addon:debug_print('petId = ' .. tostring(Addon.db.profile.hunterModePairs[petGUID]));
	
		local petId = Addon.db.profile.hunterModePairs[petGUID];
		
		Addon:debug_print('summoning hunter pet ' .. tostring(petId));
		Addon:SummonPet(petId);
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
	if petId and (petId ~= C_PetJournal.GetSummonedPetGUID()) then
		self:debug_print('summoning pet ' .. tostring(petId));
		C_PetJournal.SummonPetByGUID(petId);
	else
		self:debug_print('petId is nil or already summoned: ' .. tostring(petId));
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
		--    self:debug_print('gogo gadget ghostwolf')
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
	or PlayerInfo.channeling  then
		return false
	end
	return true

end

--[[ Event handling ]]--

function Addon:UnitAuraEventHandler()
	Addon:debug_print('UnitAuraEventHandler');
	Addon:SummonOnEvent();
end
	
function Addon:UnitPetEventHandler()
	Addon:debug_print('UnitPetEventHandler');
	
	Addon:SummonHunterPet();
end

function Addon:SummonOnEvent()

	local stealthForm = Addon:IsStealthed();

	if stealthForm and (not PlayerStealthed) then
		Addon:debug_print('stealth start');
		PlayerStealthed = true;
		Addon:HandleStealthStart();
	elseif (not stealthForm) and PlayerStealthed then
		Addon:debug_print('stealth end');
		Addon:HandleStealthEnd();
		PlayerStealthed = false;
	else
		Addon:HandleMountEvent();
	end

end

function Addon:RegenEnabledEventHandler()
	Addon:debug_print('RegenEnabledEventHandler');
	PlayerInfo.combat = false;
end

function Addon:RegenDisabledEventHandler()
	Addon:debug_print('RegenDisabledEventHandler');
	PlayerInfo.combat = true;
end

function Addon:PlayerDeadEventHandler()
	Addon:debug_print('PlayerDeadEventHandler');
	PlayerInfo.dead = true;
end

function Addon:PlayerAliveEventHandler()
	Addon:debug_print('PlayerAliveEventHandler');
	PlayerInfo.dead = false;
end

function Addon:SpellcastSentEventHandler()
	Addon:debug_print('SpellcastSentEventHandler');
	Addon:CastStart();
end

function Addon:SpellcastStartEventHandler()
	Addon:debug_print('SpellcastStartEventHandler');
	Addon:CastStart();
end

function Addon:SpellcastInterruptedEventHandler()
	Addon:debug_print('SpellcastInterruptedEventHandler');
	Addon:CastStop();
end

function Addon:SpellcastStopEventHandler()
	Addon:debug_print('SpellcastStopEventHandler');
	Addon:CastStop();
end

function Addon:SpellcastFailedEventHandler()
	Addon:debug_print('SpellcastFailedEventHandler');
	Addon:CastStop();
end

function Addon:SpellcastFailedQuietEventHandler()
	Addon:debug_print('SpellcastFailedQuietEventHandler');
	Addon:CastStop();
end

function Addon:SpellcastSucceededEventHandler()
	Addon:debug_print('SpellcastSucceededEventHandler');
	Addon:CastStop();
end

function Addon:ChannelStartEventHandler()
	Addon:debug_print('ChannelStartEventHandler');
	Addon:ChannelStart();
end

function Addon:ChannelStopEventHandler()
	Addon:debug_print('ChannelStopEventHandler');
	Addon:ChannelStop();
end

function Addon:CastStart()
	PlayerInfo.casting = true;
end

function Addon:CastStop()
	PlayerInfo.casting = false;
end

function Addon:ChannelStart()
	PlayerInfo.channeling = true;
end

function Addon:ChannelStop()
	PlayerInfo.channeling = false;
	Addon:CastStop();
end

--[[ Workhorse functions ]]--

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

	if PlayerStealthed then
		Addon:debug_print('resummon after leave stealth');
		if StealthPetId then
			Addon:debug_print('resummon petId = ' .. tostring(StealthPetId));
			Addon:SummonPet(StealthPetId);
		elseif self:IsDetectDismount() and (not C_PetJournal.GetSummonedPetGUID()) then
			Addon:debug_print('summon dismount pet');
			Addon:CheckAndSummonDismountPet();
		end
		StealthPetId = nil;
	end
end

function Addon:HandleMountEvent()
	--  self:debug_print('HandleMountEvent');

	if PlayerMounted and (not IsMounted()) then
		Addon:debug_print('dismount');
		PlayerMounted = false;
		if Addon:IsDetectDismount() and (not Addon:IsHunterMode()) then
			Addon:CheckAndSummonDismountPet();
		end
		if IsPetActive() and Addon:IsHunterMode() then
			Addon:SummonHunterPet();
		end
	elseif (not PlayerMounted) and IsMounted() then
		Addon:debug_print('mount');
		PlayerMounted = true;
	end

	local mountSpellId = Addon:FindMountSpellId()
	Addon:SummonMountPetById(mountSpellId)
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

			if (not isFiltered) and isUsable and isCollected and self.db.profile.pairs[mountSpellId] then
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
		local petId = self.db.profile.pairs[button.spellID]

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

--[[ exports ]]--

_G[AddonName] = Addon

--[[ Frame for events ]]--
local frame = CreateFrame("FRAME", AddonName .. "Frame");
--frame:RegisterEvent("UNIT_AURA");
frame:RegisterEvent("PLAYER_LOGIN")
local function EventHandler(self, event, ...)
	--	if event=="UNIT_AURA" then
	--		Addon:UnitAuraEventHandler(event, ...)
	--	else
	if event=="ADDON_LOADED" and select(1,...)=="Blizzard_Collections" then
		self:UnregisterEvent("ADDON_LOADED")
		MountJournal:HookScript("OnShow",function(self) Addon:UpdateMountJournalOverlays() end);

		Addon:Hook_MountJournal_UpdateMountList()
		Addon:Hook_MountJournalMountButton_UpdateTooltip()

	elseif event=="PLAYER_LOGIN" then
		if IsAddOnLoaded("Blizzard_Collections") then
			-- for those addons that force a load in their login (sigh)
			EventHandler(self,"ADDON_LOADED","Blizzard_Collections")
		else
			self:RegisterEvent("ADDON_LOADED")
		end
	end
	--	end

end
frame:SetScript("OnEvent", EventHandler);

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
