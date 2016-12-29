--[[

    This handles the creation and configuration of the minimap/DataBroker button

--]]

local AddonName = ...
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
          Addon:SummonMountPet()
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
      
      tooltip:AddLine(L.AddTip)
      tooltip:AddLine(L.ClearTip)
      tooltip:AddLine(L.SummonPetTip)
      if Addon:IsConfigAddonEnabled() then
        tooltip:AddLine(L.ShowOptionsTip)
      end
      
    end
  })
end
