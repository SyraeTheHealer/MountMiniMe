local AddonName, AddonTable = ...
local Addon = _G[AddonName]

--[[ Init/cleanup functions ]]--

function Addon:CreateMountTable()
	--  self:Print('CreateMountTable')

	for i, mountId in ipairs(C_MountJournal.GetMountIDs()) do
		local creatureName, spellId, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(mountId);
		if isCollected and isUsable then
			AddonTable.MountCollection[spellId] = creatureName
		end
	end
end

function Addon:DestroyMountTable()
  if AddonTable.MountCollection then
    AddonTable.MountCollection = wipe(AddonTable.MountCollection);
  end	
end

function Addon:CreatePetSpellIdsTable()
	local filteredCount, totalCount = C_PetJournal.GetNumPets();
	
	Addon:debug_print('updating PetSpellIds: totalCount = ' .. tostring(totalCount));
	AddonTable.NumPetSpellIds = totalCount;
	local count = 0;
	for i=1,totalCount do
		local petId, speciesId, isOwned, customName, level, favorite, isRevoked, name, icon, petType, a, b, c, d, canBattle = C_PetJournal.GetPetInfoByIndex(i);
		if name then
				AddonTable.PetSpellIds[name] = petId;
				count = count + 1;
		end
	end
	Addon:debug_print('Found ' .. tostring(count) .. ' pet names');
end

function Addon:DestroyPetSpellIdsTable()
  if AddonTable.PetSpellIds then
    AddonTable.PetSpellIds = wipe(AddonTable.PetSpellIds);
  end
end

function Addon:InitTrackingVars()
	AddonTable.PetChangeInProgress = false; 
	AddonTable.NumPetSpellIds = 0;
	AddonTable.StealthPetId = nil;
	AddonTable.PlayerStealthed = self:IsStealthed();
	AddonTable.PlayerMounted = IsMounted();
	AddonTable.PlayerHasHunterPet = IsPetActive();
	AddonTable.DesiredPetId = C_PetJournal.GetSummonedPetGUID();
	
  local index = GetShapeshiftForm();
	AddonTable.PlayerShapeshifted = index > 0; 

	self:debug_print('PlayerStealthed = ' .. tostring(PlayerStealthed));
	self:debug_print('PlayerMounted = ' .. tostring(PlayerMounted));
	self:debug_print('PlayerHasHunterPet = ' .. tostring(PlayerHasHunterPet));

	self:UpdatePlayerInfo();
	
	if AddonTable.PlayerHasHunterPet and self:IsHunterMode() then
		Addon:debug_print('player loaded in and has pet and hunter mode active')
		Addon:HandleHunterPetSummon();
  elseif AddonTable.PlayerShapeshifted and self:IsShapeshiftMode() then
    Addon:debug_print('player loaded in and has shapeshift mode active')
    Addon:HandleShapeshiftStart();
	else
		if AddonTable.PlayerMounted then
			Addon:debug_print('player loaded in mounted');
			Addon:HandleMountStart();
		elseif AddonTable.PlayerStealthed then
			Addon:debug_print('player loaded in stealthed');
			Addon:HandleStealthStart();
		end
	end
end

