--[[ MountMiniMe.lua ]]--

local AddonName, AddonTable = ...
local Addon = LibStub('AceAddon-3.0'):NewAddon(AddonTable, AddonName, 'AceEvent-3.0', 'AceConsole-3.0')
local L = LibStub('AceLocale-3.0'):GetLocale(AddonName)

local CURRENT_VERSION = GetAddOnMetadata(AddonName, 'Version')
local CONFIG_ADDON_NAME = AddonName .. '_Config'

local MountCollection = {}

--[[ Startup ]]--

function Addon:OnInitialize()

  --register database events
  self.db = LibStub('AceDB-3.0'):New(AddonName .. 'DB', self:GetDefaults(), UnitClass('player'))
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

--[[ Mount pairing functions ]]--

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

function Addon:AddMountPair()

  if not IsMounted() then
    self:Print(L.NotMountedError)
    return
  end

  local petId = C_PetJournal.GetSummonedPetGUID()

  if not petId then
    self:Print(L.NoPetSummoned)
    return
  end

  local mountSpellId = self:FindMountSpellId()

  if mountSpellId then
    self.db.profile.pairs[mountSpellId] = petId

    self:Print(format(L.PairAdded, self:FindPetName(petId), self:FindMountName()))

    self:UpdateMountJournalOverlays()    
  end

end

function Addon:ClearMountPair()
  
  if not IsMounted() then
    self:Print(L.NotMountedError)
    return
  end

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
      C_PetJournal.SummonPetByGUID(petId)
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

--[[ Event handling ]]--

function Addon:UnitAuraEventHandler(event, ...)
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
