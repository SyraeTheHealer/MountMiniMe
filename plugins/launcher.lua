--[[




    This handles the creation and configuration of the minimap/DataBroker button




--]]

local AddonName, AddonTable = ...
local Addon = _G[AddonName]
local Launcher = Addon:NewModule('Launcher')
local DBIcon = LibStub('LibDBIcon-1.0')

function Launcher:OnInitialize()
  DBIcon:Register(AddonName, self:CreateDataBrokerObject(), self:GetSettings())
end

function Launcher:Load()
  self:Update()
end

function Launcher:Update()
  DBIcon:Refresh(AddonName, self:GetSettings())
end

function Launcher:GetSettings()
  return Addon.db.profile.minimap
end

function Launcher:CreateDataBrokerObject()
  local L = LibStub('AceLocale-3.0'):GetLocale(AddonName)
  local iconPath = ([[Interface\Addons\%s\%s]]):format(AddonName, AddonName)

  return LibStub('LibDataBroker-1.1'):NewDataObject(AddonName, {
    type = 'launcher',

    icon = iconPath,

    OnClick = function(self, button)
      if button == 'LeftButton' then
        if IsShiftKeyDown() then
          Addon:ClearMountPair()
        elseif IsAltKeyDown() then
          Addon:ResummonPet()
        else
          Addon:AddMountPair()
        end
      elseif button == 'RightButton' then
        Addon:ShowOptions()
      end

    end,

    OnTooltipShow = function(tooltip)
      if not tooltip or not tooltip.AddLine then return end

      tooltip:AddLine(GetAddOnMetadata(AddonName, "Title"))

      if IsMounted() then
        tooltip:AddLine(L.AddTip)
        tooltip:AddLine(L.ClearTip)
        tooltip:AddLine(L.SummonPetTip)
      elseif IsPetActive() and Addon:IsHunterMode() then
        tooltip:AddLine(L.HunterModeAddTip)
        tooltip:AddLine(L.HunterModeClearTip)
        tooltip:AddLine(L.HunterModeSummonPetTip)
      elseif AddonTable.PlayerShapeshifted and Addon:IsShapeshiftMode() then
        tooltip:AddLine(L.ShapeshiftModeAddTip)
        tooltip:AddLine(L.ShapeshiftModeClearTip)
        tooltip:AddLine(L.ShapeshiftModeSummonPetTip)
      else
        if Addon:IsPerSpecDismount() then
          local _, specName = GetSpecializationInfo(GetSpecialization());
          tooltip:AddLine(format(L.DismountedSpecAddTip, specName))
          tooltip:AddLine(format(L.DismountedSpecClearTip, specName))
          tooltip:AddLine(format(L.DismountedSpecSummonPetTip, specName))
        else
          tooltip:AddLine(L.DismountedAddTip)
          tooltip:AddLine(L.DismountedClearTip)
          tooltip:AddLine(L.DismountedSummonPetTip)
        end
      end
      if Addon:IsConfigAddonEnabled() then
        tooltip:AddLine(L.ShowOptionsTip)
      end
    end
  })
end
