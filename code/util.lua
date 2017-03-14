local AddonName, AddonTable = ...
local Addon = _G[AddonName]

--[[ Utility methods ]]--

function Addon:UpdatePlayerInfo()
	self:SetPlayerInfo({combat = UnitAffectingCombat("player") or UnitAffectingCombat("pet"), dead = UnitIsDead("player"), feigning = Addon:IsFeigning(), casting = false, channeling = false});
end

function Addon:SetPlayerInfo(info)
	if info.combat then
		AddonTable.PlayerInfo.combat = info.combat;
	end
	if info.dead then
		AddonTable.PlayerInfo.dead = info.dead;
	end
	if info.feigning then
		AddonTable.PlayerInfo.feigning = info.feigning;
	end
	if info.casting then
		AddonTable.PlayerInfo.casting = info.casting;
	end
	if info.channeling then
		AddonTable.PlayerInfo.channeling = info.channeling;
	end

	Addon:debug_print('PlayerInfo:');
	Addon:debug_tprint(AddonTable.PlayerInfo, 1);
end

function Addon:FindMountSpellId()
	-- No use trying to find a mount if we're not mounted
	if not IsMounted() then
		return nil
	end

	local buffs, i = {}, 1;
	local name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i);
	while name do
		if AddonTable.MountCollection[spellId] then
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
--	self:debug_print('latencyHome ' .. latencyHome);
--	self:debug_print('latencyWorld ' .. latencyWorld);
	local latency = math.max(latencyHome, latencyWorld);
	if latency == 0 then
		latency = 100;
	end
	return latency;
end

function Addon:IsStealthed()
	local stealthForm = IsStealthed();

	if AddonTable.DEBUG and (not stealthForm) then
		stealthForm = (GetShapeshiftFormID() ~= nil);
	end

	return stealthForm;
end

function Addon:IsFeigning()
	return UnitIsFeignDeath('player');
end

function Addon:CanSummonPet()

	if IsFlying()
	or (UnitAffectingCombat("player") or UnitAffectingCombat("pet") or AddonTable.PlayerInfo.combat)
	or (UnitIsDeadOrGhost("player") or AddonTable.PlayerInfo.dead)
	or (UnitIsFeignDeath("player") or AddonTable.PlayerInfo.feigning)
	or AddonTable.PlayerInfo.casting
	or AddonTable.PlayerInfo.channeling
	or AddonTable.PlayerInfo.looting
	or AddonTable.PlayerInfo.controlLost
	or AddonTable.PlayerInfo.sitting
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
--	Addon:debug_print('IsPetSpellId - ' .. tostring(spellId) .. tostring(PetSpellIds[spellId]));
	return AddonTable.PetSpellIds[spellId];
end

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
	if AddonTable.SummonTimerId then
--		Addon:debug_print("cancelling summon timer");
		Addon:CancelTimer(AddonTable.SummonTimerId);
		AddonTable.SummonTimerId = nil;
	end
	if AddonTable.DismissTimerId then
--		Addon:debug_print("cancelling dismiss timer");
		Addon:CancelTimer(AddonTable.DismissTimerId);
		AddonTable.DismissTimerId = nil;
	end
--	if CallSummonPetByGUIDTimerId then
--		Addon:CancelTimer(CallSummonPetByGUIDTimerId);
--		CallSummonPetByGUIDTimerId = nil;
--	end
	
end

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
--			Addon:debug_print('pet GUID - ' .. tostring(petGUID));
			
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
--	self:debug_print('ResummonPet');
--	self:debug_print('hunter mode = ' .. tostring(self:IsHunterMode()));

	if not IsMounted() and (not self:IsDetectDismount() and not self:IsHunterMode()) then
		self:Print(L.NotMountedError)
		return
	end
	
	if IsMounted() then
--		self:debug_print('Resummon mount pet');
		local mountSpellId = self:FindMountSpellId()
		Addon:SummonPet(Addon:FindPetIdForMountSpellId(mountSpellId));
	else
		if IsPetActive() and self:IsHunterMode() then
--			self:debug_print('Resummon hunter pet');
			local hunterPetName = Addon:FindHunterPetName();
			Addon:SummonPet(Addon:FindPetIdForHunterPetName(hunterPetName));
		else
			
			local petId = self:FindPetIdForCharacterName(UnitFullName("player"));
			if Addon:IsPerCharDismount() and petId then
--				self:debug_print('Per-char summon dismount pet: petId = ' .. tostring(petId));
				self:SummonPet(petId);
			else
				petId = self:GetDismountPetId();
--				self:debug_print('Resummon dismount pet: petId = ' .. tostring(petId));
				self:SummonPet(petId);
			end
		end
	end
	
end

function Addon:AddPerCharDismountPet(petId)
	if not petId then
		return;
	end
	
	Addon:SetPetIdForCharacterName(UnitFullName("player"), petId);
end

--Summoning
function Addon:CheckAndSummonDismountPet()
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
			self:SummonPet(petId);
		end
	elseif dismountOp == 'dismiss' then
		self:debug_print('dismount dismiss');
		self:DismissPet();
	end
end

function Addon:RepeatingSummonPet()
	if AddonTable.DesiredPetId and not Addon:IsCurrentPet(AddonTable.DesiredPetId) then
--		Addon:debug_print('RepeatingSummonPet');
		Addon:SummonPet(AddonTable.DesiredPetId);
	end
end

function Addon:SummonPet(petId)
	if AddonTable.PlayerStealthed or Addon:IsStealthed() then
		Addon:debug_print('summon - stealthed, no call');
		return;
	end

--	if PetChangeInProgress then
--		Addon:debug_print('summon - pet change in progress');
--	end
	AddonTable.PetChangeInProgress = true;

	Addon:CancelTimers();

	AddonTable.DesiredPetId = petId;
	
	local currentPetId = C_PetJournal.GetSummonedPetGUID()
--	Addon:debug_print('Current pet: ' .. tostring(currentPetId));
	if Addon:IsCurrentPet(AddonTable.DesiredPetId) then
--		Addon:debug_print('Requested pet is already active');
		return;
	elseif not Addon:IsCurrentPet(AddonTable.DesiredPetId) then
--		Addon:debug_print('Summoning desired pet: ' .. tostring(DesiredPetId));
		if self:CanSummonPet() then
			self:CallSummonPetByGUID(petId);
			AddonTable.PetChangeInProgress = false;
		else
--			self:debug_print('Cannot summon now');
--			self:debug_print('PlayerInfo:');
--			self:debug_tprint(PlayerInfo, 1);
			
			local delay = AddonTable.SummonDelay;
			if delay == nil then
				delay = AddonTable.DefaultSummonDelay;
			end
			Addon:debug_print("SummonPet - summon delay = " .. tostring(delay));
			AddonTable.SummonTimerId = self:ScheduleTimer("SummonPet", delay, petId);
		end
	end
	
end

function Addon:CallSummonPetByGUID(petId)
	self:debug_print('CallSummonPetByGUID')
	if petId then
		local delay = (self:GetLatencyMillis()/1000.0) + AddonTable.SummonDelay;
		self:debug_print('summon delay ' .. delay);
--		if CallSummonPetByGUIDTimerId then
--			self:debug_print('Cancelling CallSummonPetByGUIDTimerId');
--			Addon:CancelTimer(CallSummonPetByGUIDTimerId);
--			CallSummonPetByGUIDTimerId = nil;
--		end		
		AddonTable.CallSummonPetByGUIDTimerId = self:ScheduleTimer("CallSummonPetByGUID_Callback", delay, petId);
	end
end

function Addon:CallSummonPetByGUID_Callback(petId)
	self:debug_print('CallSummonPetByGUID_Callback: petId = ' .. tostring(petId))
	if petId and not Addon:IsCurrentPet(petId) then
		self:debug_print('summoning pet ' .. tostring(petId));
		C_PetJournal.SummonPetByGUID(petId);
	else
		self:debug_print('petId is nil or already summoned: ' .. tostring(petId));
	end
	AddonTable.SummonDelay = AddonTable.DefaultSummonDelay;
--	if CallSummonPetByGUIDTimerId then
--		self:debug_print('Cancelling CallSummonPetByGUIDTimerId');
--		Addon:CancelTimer(CallSummonPetByGUIDTimerId);
--		CallSummonPetByGUIDTimerId = nil;
--	end		
end

--Dismissing
function Addon:DismissPet()
	self:debug_print('DismissPet');

	if AddonTable.PetChangeInProgress then
		Addon:debug_print('dismiss - pet change in progress');
	end
	AddonTable.PetChangeInProgress = true;
	
	AddonTable.DesiredPetId = nil;

	Addon:CancelTimers();

	if not C_PetJournal.GetSummonedPetGUID() then
		Addon:debug_print('No pet is active');
		return;
	end
	
	if self:CanSummonPet() then
		self:CallDismissCompanion();
		AddonTable.PetChangeInProgress = false;
	else
		self:debug_print('Cannot dismiss now');
		self:debug_print('PlayerInfo:');
		self:debug_tprint(PlayerInfo, 1);
		
		AddonTable.DismissTimerId = self:ScheduleTimer("DismissPet", AddonTable.DefaultSummonDelay);
	end

end

function Addon:CallDismissCompanion()
	self:debug_print('CallDismissCompanion')
	local delay = self:GetLatencyMillis()/1000.0;
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


--[[ Debug ]]--
function Addon:debug_print(message)
	if AddonTable.DEBUG and message then
		print(message)
	end
end

-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
function Addon:debug_tprint (tbl, indent)
	if AddonTable.DEBUG and tbl then
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

