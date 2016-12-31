--[[ MountMiniMe.lua ]]--

local AddonName, AddonTable = ...
local Addon = LibStub('AceAddon-3.0'):NewAddon(AddonTable, AddonName, 'AceEvent-3.0', 'AceConsole-3.0', 'AceTimer-3.0')
local L = LibStub('AceLocale-3.0'):GetLocale(AddonName)

local DEBUG = false;

local CURRENT_VERSION = GetAddOnMetadata(AddonName, 'Version')
local CONFIG_ADDON_NAME = AddonName .. '_Config'

local MountCollection = {}
--local CurrentPetId, LastPetId
local StealthPetId, PlayerStealthed, PlayerMounted

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
end

function Addon:OnEnable()
  self:Load()
  
--  CurrentPetId = C_PetJournal.GetSummonedPetGUID();
--  self:debug_print('CurrentPetId = ' .. tostring(CurrentPetId))
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
        }
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
end

--[[ Mount pairing functions ]]--

function Addon:AddMountPair()

  if (not IsMounted()) and (not self:IsDetectDismount()) then
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
    self:debug_print('Adding dismount pet: petId = ' .. tostring(petId));
    self:Print(format(L.DismountedPairAdded, self:FindPetName(petId)))
    self:SetDismountPetId(petId);
  end
end

function Addon:ClearMountPair()
  
  if not IsMounted() and (not self:IsDetectDismount()) then
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
    self:debug_print('Clearing dismount pet');
    self:Print(L.DismountedPairCleared)
    self:SetDismountPetId(nil);
  end    
end

function Addon:SummonMountPet()
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
--      LastPetId = currentPetId
--      CurrentPetId = petId
--      self:debug_print('LastPetId = ' .. tostring(LastPetId))
--      self:debug_print('CurrentPetId = ' .. tostring(CurrentPetId))
--      C_PetJournal.SummonPetByGUID(petId)
--      self:CallSummonPetByGUID(petId);
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

function Addon:DismissPet()
  self:debug_print('DismissPet');
  self:CallDismissCompanion();
end

function Addon:CallDismissCompanion()
  self:debug_print('CallDismissCompanion');
  
  local delay = self:GetLatencyMillis()/1000.0;
  self:debug_print('dismiss delay ' .. delay);
  self:ScheduleTimer("CallDismissCompanion_Callback", delay);
end

function Addon:CallDismissCompanion_Callback()
  self:debug_print('CallDismissCompanion_Callback');
  DismissCompanion("CRITTER");
--  self:CallSummonPetByGUID(C_PetJournal.GetSummonedPetGUID());
end

function Addon:SummonPet(petId)
  self:debug_print('SummonPet');
  self:CallSummonPetByGUID(petId);
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

--[[ Event handling ]]--

function Addon:UnitAuraEventHandler(event, ...)

  local stealthForm = self:IsStealthed();

  if stealthForm or ((not stealthForm) and PlayerStealthed) then
    self:HandleStealthEvent(stealthForm);
  else
    self:HandleMountEvent();
  end

end

function Addon:HandleStealthEvent(stealthForm)
  self:debug_print('HandleStealthEvent');
  
  self:debug_print('stealthForm = ' .. tostring(stealthForm) .. ', PlayerStealthed = ' .. tostring(PlayerStealthed));
  
  local currentPetId = C_PetJournal.GetSummonedPetGUID();
  if stealthForm and self:IsDismissOnStealth() and currentPetId then
    self:debug_print('hiding pet for stealth: stealthForm = ' .. tostring(stealthForm) .. ', dismiss = ' .. tostring(self:IsDismissOnStealth()) .. ', currentPetId = ' .. currentPetId)
    StealthPetId = currentPetId;
    PlayerStealthed = true;
    self:debug_print('storing pet id - ' .. tostring(StealthPetId));
--    DismissCompanion("CRITTER");
    self:DismissPet();
  elseif (not stealthForm) and PlayerStealthed then
    self:debug_print('resummon after leave stealth');
    PlayerStealthed = false;
--    self:CallSummonPetByGUID(StealthPetId);
    if StealthPetId then
      self:SummonPet(StealthPetId);
    elseif self:IsDetectDismount() then
      self:CheckAndSummonDismountPet();
    end
    StealthPetId = nil;
  end
  
end

function Addon:HandleMountEvent()
  self:debug_print('HandleMountEvent');

  if PlayerMounted and (not IsMounted()) then
    self:debug_print('dismount');
    PlayerMounted = false;
    if self:IsDetectDismount() then
      self:CheckAndSummonDismountPet();
    end
  elseif (not PlayerMounted) and IsMounted() then
    self:debug_print('mount');
    PlayerMounted = true;
  end
  
  local mountSpellId = self:FindMountSpellId()
  self:SummonMountPetById(mountSpellId)
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
frame:RegisterEvent("UNIT_AURA");
frame:RegisterEvent("PLAYER_LOGIN")
local function EventHandler(self, event, ...)
  if event=="UNIT_AURA" then
    Addon:UnitAuraEventHandler(event, ...)
  else
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
  end

end
frame:SetScript("OnEvent", EventHandler);

--[[ Debug ]]--
function Addon:debug_print(message)
  if DEBUG and message then
    print(message)
  end
end
