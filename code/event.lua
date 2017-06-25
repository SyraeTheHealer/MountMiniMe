local AddonName, AddonTable = ...
local Addon = _G[AddonName]

--[[ Summon/Dismiss related event handling ]]--

--Mount summoning
function Addon:UnitAuraEventHandler()
	local wasPlayerMounted = AddonTable.PlayerMounted;
	AddonTable.PlayerMounted = IsMounted();
	
	if AddonTable.PlayerMounted and (not wasPlayerMounted) then
		Addon:debug_print('mount');
		Addon:HandleMountStart();
	elseif (not AddonTable.PlayerMounted) and wasPlayerMounted then
		Addon:debug_print('dismount');
		Addon:HandleMountEnd();
	end

end

function Addon:HandleMountStart()
	Addon:debug_print('HandleMountStart');
	
	AddonTable.StealthPetId = nil;
	
	local hunterModeOp = self:GetHunterModeOperation();
--	self:debug_print('hunterModeOp' .. tostring(hunterModeOp));
	
	if Addon:IsHunterMode() and IsPetActive() and (hunterModeOp == 'keep') then
--		Addon:debug_print('Hunter op is keep, not summoning mount pet');
		return;
	end
	
  local shapeshiftModeOp = self:GetShapeshiftModeOperation();
  self:debug_print('shapeshiftModeOp = ' .. tostring(shapeshiftModeOp));
  
  if Addon:IsShapeshiftMode() and AddonTable.PlayerShapeshifted and (shapeshiftModeOp == 'keep') then
    Addon:debug_print('Shapeshift op is keep, not summoning mount pet');
    return;
  end
	
	
	local mountSpellId = Addon:FindMountSpellId()
	AddonTable.SummonDelay = AddonTable.DefaultSummonDelay;
	Addon:SummonPet(Addon:FindPetIdForMountSpellId(mountSpellId));	
end

function Addon:HandleMountEnd()
	Addon:debug_print('HandleMountEnd');

	local hunterModeOp = self:GetHunterModeOperation();
--	self:debug_print('hunterModeOp' .. tostring(hunterModeOp));

	if Addon:IsHunterMode() and IsPetActive() and (hunterModeOp == 'keep') then
--		Addon:debug_print('Hunter mode active, not summoning dismount pet');
		return;
	elseif Addon:IsHunterMode() and IsPetActive() and (hunterModeOp == 'summon') then
--		Addon:debug_print('Dismount, hunter mode active, summoning hunter pet');
		AddonTable.SummonDelay = Addon:GetDelayDismount();
		Addon:HandleHunterPetSummon();
		return;
	end
	
  local shapeshiftModeOp = self:GetShapeshiftModeOperation();
  self:debug_print('shapeshiftModeOp ' .. tostring(shapeshiftModeOp));
  self:debug_print('shapeshifted = ' .. tostring(AddonTable.PlayerShapeshifted));

  if Addon:IsShapeshiftMode() and AddonTable.PlayerShapeshifted and (shapeshiftModeOp == 'keep') then
    Addon:debug_print('Shapeshift op is keep, not summoning dismount pet');
    return;
  elseif Addon:IsShapeshiftMode() and AddonTable.PlayerShapeshifted and (shapeshiftModeOp == 'summon') then
    Addon:debug_print('Dismount, Shapeshift op is summon, summoning shapeshift pet');
    AddonTable.SummonDelay = Addon:GetDelayDismount();
    Addon:HandleShapeshiftStart();
    return;
  end
	
	AddonTable.SummonDelay = Addon:GetDelayDismount();
	Addon:CheckAndSummonDismountPet();
end

--Hunter pet summoning
function Addon:UnitPetEventHandler(unitId)
--	Addon:debug_print('UnitPetEventHandler - unitId = ' .. tostring(unitId));
	if not unitId or unitId == "player" then
	
--		Addon:debug_print('UnitPetEventHandler');
		
		local playerHadHunterPet = AddonTable.PlayerHasHunterPet;
		AddonTable.PlayerHasHunterPet = IsPetActive();
		
--		Addon:debug_print('playerHadHunterPet = ' .. tostring(playerHadHunterPet));
--		Addon:debug_print('PlayerHasHunterPet = ' .. tostring(PlayerHasHunterPet));
		
		local hunterModeOp = Addon:GetHunterModeOperation();
--		Addon:debug_print('hunterModeOp' .. tostring(hunterModeOp));
		if IsMounted() and (hunterModeOp == 'summon') then
--			Addon:debug_print('Player is mounted and hunterModeOp is summon');
			return;
		end
		
		if AddonTable.PlayerHasHunterPet and (not playerHadHunterPet) then
--			Addon:debug_print('petGUID = ' .. tostring(UnitGUID("pet")));
		
--			Addon:debug_print('hunter pet summoned');
			Addon:HandleHunterPetSummon();
		elseif (not AddonTable.PlayerHasHunterPet) and playerHadHunterPet then
--			Addon:debug_print('hunter pet dismissed');
			Addon:HandleHunterPetDismiss();
		elseif playerHadHunterPet and AddonTable.PlayerHasHunterPet then
--			Addon:debug_print('hunter pet switch (for handling warlock pets that dont need to be manually dismissed to change)');
			Addon:HandleHunterPetSummon();
		end
	end
end

function Addon:HandleHunterPetSummon(delay)
	Addon:debug_print('HandleHunterPetSummon');

	local hunterPetName = Addon:FindHunterPetName();
	Addon:SummonPet(Addon:FindPetIdForHunterPetName(hunterPetName), delay);	
end

function Addon:HandleHunterPetDismiss()
	Addon:debug_print('HandleHunterPetDismiss');
	
	AddonTable.PlayerHasHunterPet = IsPetActive();
	
	Addon:CheckAndSummonDismountPet();
end

--Stealth summoning
function Addon:UpdateStealthEventHandler()
	Addon:debug_print('UpdateStealthEventHandler');
	
	local wasPlayerStealthed = AddonTable.PlayerStealthed;
	AddonTable.PlayerStealthed = Addon:IsStealthed();
	
	if AddonTable.PlayerStealthed and (not wasPlayerStealthed) then
		Addon:debug_print('stealth start');
		Addon:HandleStealthStart();
	elseif (not AddonTable.PlayerStealthed) and wasPlayerStealthed then
		Addon:debug_print('stealth end');
		Addon:HandleStealthEnd();
	end
end

function Addon:HandleStealthStart()
	Addon:debug_print('HandleStealthStart');

	if Addon:IsDismissOnStealth() then
		local currentPetId = C_PetJournal.GetSummonedPetGUID();
		AddonTable.StealthPetId = currentPetId;
		Addon:debug_print('storing pet id - ' .. tostring(AddonTable.StealthPetId));
		if currentPetId then
			Addon:DismissPet();
		end
	end
end

function Addon:HandleStealthEnd()
	Addon:debug_print('HandleStealthEnd');

	Addon:debug_print('resummon after leave stealth');
	if AddonTable.StealthPetId then
		Addon:debug_print('resummon petId = ' .. tostring(AddonTable.StealthPetId));
		AddonTable.SummonDelay = Addon:GetDelayStealth();
		Addon:SummonPet(AddonTable.StealthPetId);
	elseif self:IsDetectDismount() and (not C_PetJournal.GetSummonedPetGUID()) then
		Addon:debug_print('summon dismount pet');
		AddonTable.SummonDelay = Addon:GetDelayStealth();
		Addon:CheckAndSummonDismountPet();
	end
	AddonTable.StealthPetId = nil;
end


--[[ Event handling ]]--

function Addon:RegenEnabledEventHandler()
	Addon:debug_print('RegenEnabledEventHandler');
	AddonTable.PlayerInfo.combat = false;
	AddonTable.SummonDelay = Addon:GetDelayCombat();
end

function Addon:RegenDisabledEventHandler()
	Addon:debug_print('RegenDisabledEventHandler');
	AddonTable.PlayerInfo.combat = true;
	AddonTable.SummonDelay = Addon:GetDelayCombat();
end

function Addon:LootStartedHandler()
	Addon:debug_print('LootStartedHandler');
	AddonTable.PlayerInfo.looting = true;
	AddonTable.SummonDelay = Addon:GetDelayLoot();
end

function Addon:LootStoppedHandler()
	Addon:debug_print('LootStoppedHandler');
	AddonTable.PlayerInfo.looting = false;
end

function Addon:ControlLostStartedHandler()
	Addon:debug_print('ControlLostStartedHandler');
	AddonTable.PlayerInfo.controlLost = true;
end

function Addon:ControlLostStoppedHandler()
	Addon:debug_print('ControlLostStoppedHandler');
	AddonTable.PlayerInfo.controlLost = false;
end

function Addon:PlayerDeadEventHandler()
	Addon:debug_print('PlayerDeadEventHandler');
	AddonTable.PlayerInfo.dead = true;
end

function Addon:PlayerAliveEventHandler()
	Addon:debug_print('PlayerAliveEventHandler');
	AddonTable.PlayerInfo.dead = false;
end

function Addon:SpellcastSentEventHandler(unitId, spellName, rank, target, lineId)
	if unitId == "player" then
		Addon:debug_print('SpellcastSentEventHandler');
		Addon:CastStart();
	end
end

function Addon:SpellcastStartEventHandler(unitId, spellName, rank, lineId, spellId)
	if unitId == "player" then
--		Addon:debug_print('SpellcastStartEventHandler: unitId = ' .. tostring(unitId));
		Addon:CastStart();
		
--		Addon:debug_print('**** ' .. tostring(spellName) .. ' ' .. tostring(spellId) .. ' ' .. tostring(lineId));
		if Addon:IsPetSpellId(spellName) then
--			Addon:debug_print('**** pet spell id');
			AddonTable.DesiredPetId = Addon:IsPetSpellId(spellName);
	--		Addon:debug_print('**** ' .. tostring(C_PetJournal.GetSummonedPetGUID()));
		end
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
			AddonTable.DesiredPetId = Addon:IsPetSpellId(spellName)
	--		Addon:debug_print('**** ' .. tostring(C_PetJournal.GetSummonedPetGUID()));
		end
	
	--	local spell, rank, displayName, icon, startTime, endTime, isTradeSkill, castID, interrupt = UnitCastingInfo("player");
	--	Addon:debug_print('**** ' .. tostring(displayName));	
	end
	
--	Addon:debug_print('>>>> spellcast succeed ' .. tostring(spellName));
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
	AddonTable.PlayerInfo.casting = true;

AddonTable.DesiredPetId = nil;

--	local currentPetId = C_PetJournal.GetSummonedPetGUID();
--	Addon:debug_print('---> CastStart petId = ' .. tostring(currentPetId))
end

function Addon:CastStop()
	Addon:debug_print('CastStop');
	AddonTable.PlayerInfo.casting = false;
end

function Addon:ChannelStart()
	Addon:debug_print('ChannelStart');
	AddonTable.PlayerInfo.channeling = true;
end

function Addon:ChannelStop()
	Addon:debug_print('ChannelStop');
	AddonTable.PlayerInfo.channeling = false;
	Addon:CastStop();
end

function Addon:CompanionUpdateEvent()
--	Addon:debug_print('CompanionUpdateEvent');
	Addon:CreatePetSpellIdsTable();
	Addon:CreateMountTable();
end

function Addon:SittingStart()
	Addon:debug_print('SittingStart');
	AddonTable.PlayerInfo.sitting = true;
end

function Addon:SittingStop()
--	Addon:debug_print('SittingStop');
	AddonTable.PlayerInfo.sitting = false;
end

function Addon:SitStandOrDescendStart()
	Addon:debug_print('SitStandOrDescendStart called');
	if AddonTable.PlayerInfo.sitting then
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
--	Addon:debug_print('MoveAndSteerStart called');
	Addon:SittingStop();
end

function Addon:MoveBackwardStart()
--	Addon:debug_print('MoveBackwardStart called');
	Addon:SittingStop();
end

function Addon:MoveForwardStart()
--	Addon:debug_print('MoveForwardStart called');
	Addon:SittingStop();
end

function Addon:StrafeLeftStart()
--	Addon:debug_print('StrafeLeftStart called');
	Addon:SittingStop();
end

function Addon:StrafeRightStart()
--	Addon:debug_print('StrafeRightStart called');
	Addon:SittingStop();
end

function Addon:ToggleAutoRun()
--	Addon:debug_print('ToggleAutoRun called');
	Addon:SittingStop();
end

function Addon:TurnLeftStart()
--	Addon:debug_print('TurnLeftStart called');
	Addon:SittingStop();
end

function Addon:TurnRightStart()
--	Addon:debug_print('TurnRightStart called');
	Addon:SittingStop();
end

function Addon:TurnOrActionStart()
--	Addon:debug_print('TurnOrActionStart called');
	Addon:SittingStop();
end

--[[ Shapeshift ]]--
function Addon:ShapeshiftHandler()
  Addon:debug_print('ShapeshiftHandler called');
  
  local wasPlayerShapeshifted = AddonTable.PlayerShapeshifted;
  local index = GetShapeshiftForm();
  
  if index > 0 then
    Addon:debug_print('ShapeshiftHandler index = ' .. tostring(index));
    local id = GetShapeshiftFormID();
    Addon:debug_print('ShapeshiftHandler id = ' .. tostring(id));
    local texture, name, isActive, isCastable, spellID = GetShapeshiftFormInfo(index);
    if name ~= nil then
      Addon:debug_print('ShapeshiftHandler name = ' .. name);
    else
      Addon:debug_print('ShapeshiftHandler name = not found');
    end
    
    
    AddonTable.PlayerShapeshifted = true;
  else
    AddonTable.PlayerShapeshifted = false;
  end
  
--  if AddonTable.PlayerShapeshifted and (not wasPlayerShapeshifted) then
--    Addon:debug_print('shapeshift start');
--    Addon:HandleShapeshiftStart();
--  elseif (not AddonTable.PlayerShapeshifted) and wasPlayerShapeshifted then
--    Addon:debug_print('shapeshift end');
--    Addon:HandleShapeshiftEnd();
--  end


--    local shapeshiftModeOp = Addon:GetShapeshiftModeOperation();
--    Addon:debug_print('shapeshiftModeOp = ' .. tostring(shapeshiftModeOp));
--    if IsMounted() and (shapeshiftModeOp == 'summon') and then
--      Addon:debug_print('Player is mounted and shapeshiftModeOp is summon');
--      return;
--    end
    
    if AddonTable.PlayerShapeshifted and (not wasPlayerShapeshifted) then
--      Addon:debug_print('petGUID = ' .. tostring(UnitGUID("pet")));
    
      Addon:debug_print('shapeshift start');
      Addon:HandleShapeshiftStart();
    elseif (not AddonTable.PlayerShapeshifted) and wasPlayerShapeshifted then
--      Addon:debug_print('hunter pet dismissed');
      Addon:HandleShapeshiftEnd();
    elseif wasPlayerShapeshifted and AddonTable.PlayerShapeshifted then
      Addon:debug_print('shapeshift switch');
      Addon:HandleShapeshiftStart();
    end

end

function Addon:HandleShapeshiftStart(delay)
  Addon:debug_print('HandleShapeshiftStart');

  local shapeshiftName = Addon:FindShapeshiftName();
  Addon:SummonPet(Addon:FindPetIdForShapeshiftName(shapeshiftName), delay); 
end

function Addon:HandleShapeshiftEnd()
  Addon:debug_print('HandleShapeshiftEnd');
  
  if IsMounted() then
    Addon:ResummonPet();
  else
    Addon:CheckAndSummonDismountPet();
  end
end

--[[ Shapeshift ]]--
function Addon:TalentHandler()
  Addon:debug_print('TalentHandler called');
  Addon:CheckAndSummonDismountPet();
end
