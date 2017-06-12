local AddonName = ...
local Addon = _G[AddonName]

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
--	self:debug_print('dismiss stealth = ' .. tostring(enable));
	self.db.profile.options.stealth.dismiss = enable;
end

--Dismount
function Addon:IsDetectDismount()
	return self.db.profile.options.dismount.enabled;
end

function Addon:SetDetectDismount(enable)
--	self:debug_print('detect dismount = ' .. tostring(enable));
	self.db.profile.options.dismount.enabled = enable;
end

function Addon:GetDismountOperation()
	return self.db.profile.options.dismount.operation;
end

function Addon:SetDismountOperation(value)
--	self:debug_print('dismount op = ' .. tostring(value));
	self.db.profile.options.dismount.operation = value;
end

function Addon:GetDismountPetId()
	return self.db.profile.options.dismount.petId;
end

function Addon:SetDismountPetId(petId)
--	self:debug_print('dismount petId = ' .. tostring(petId));
	self.db.profile.options.dismount.petId = petId;
end

--Hunter mode
function Addon:IsHunterMode()
	return self.db.profile.options.hunterMode.enabled;
end

function Addon:SetHunterMode(enable)
--	self:debug_print('hunter mode = ' .. tostring(enable));
	self.db.profile.options.hunterMode.enabled = enable;
end

function Addon:GetHunterModeOperation()
	return self.db.profile.options.hunterMode.operation;
end

function Addon:SetHunterModeOperation(value)
--	self:debug_print('hunter mode op = ' .. tostring(value));
	self.db.profile.options.hunterMode.operation = value;
end

--Shapeshift mode
function Addon:IsShapeshiftMode()
  return self.db.profile.options.shapeshiftMode.enabled;
end

function Addon:SetShapeshiftMode(enable)
--  self:debug_print('shapeshift mode = ' .. tostring(enable));
  self.db.profile.options.shapeshiftMode.enabled = enable;
end

function Addon:GetShapeshiftModeOperation()
  return self.db.profile.options.shapeshiftMode.operation;
end

function Addon:SetShapeshiftModeOperation(value)
--  self:debug_print('shapeshift mode op = ' .. tostring(value));
  self.db.profile.options.shapeshiftMode.operation = value;
end

--Per-character dismount
function Addon:IsPerCharDismount()
	return self.db.profile.options.perCharDismount.enabled;
end

function Addon:SetPerCharDismount(enable)
--	self:debug_print('per-char dismount = ' .. tostring(enable));
	self.db.profile.options.perCharDismount.enabled = enable;
	
	if enable then
		local petId = self:FindPetIdForCharacterName(UnitFullName("player"));
		if petId == nil then
			Addon:AddPerCharDismountPet(Addon:GetDismountPetId());
		end
	end
end

--Summon pet delays
function Addon:GetDelayDismount()
	return self.db.profile.options.summonDelays.dismountDelay;
end

function Addon:SetDelayDismount(delay)
	self.db.profile.options.summonDelays.dismountDelay = delay;
end

function Addon:GetDelayCombat()
	return self.db.profile.options.summonDelays.combatDelay;
end

function Addon:SetDelayCombat(delay)
	self.db.profile.options.summonDelays.combatDelay = delay;
end

function Addon:GetDelayStealth()
	return self.db.profile.options.summonDelays.stealthDelay;
end

function Addon:SetDelayStealth(delay)
	self.db.profile.options.summonDelays.stealthDelay = delay;
end

function Addon:GetDelayLoot()
	return self.db.profile.options.summonDelays.lootDelay;
end

function Addon:SetDelayLoot(delay)
	self.db.profile.options.summonDelays.lootDelay = delay;
end
