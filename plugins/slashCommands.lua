--[[

    Slash command module for MountMiniMe

--]]
local AddonName, Addon = ...
local SlashCommands = Addon:NewModule('SlashCommands', 'AceConsole-3.0')

local L = LibStub('AceLocale-3.0'):GetLocale(AddonName)

local function printCommand(cmd, desc)
  print((' - |cFF33FF99%s|r: %s'):format(cmd, desc))
end

function SlashCommands:OnEnable()
  self:RegisterChatCommand('mountminime', 'OnCmd')
  self:RegisterChatCommand('mmm', 'OnCmd')
end

function SlashCommands:OnCmd(args)
  local cmd = string.split(' ', args):lower() or args:lower()

  if cmd == 'add' or cmd == 'set' then
    Addon:AddMountPair()
  elseif cmd == 'remove' or cmd == 'clear' or cmd == 'del' or cmd == 'delete' then
    Addon:ClearMountPair()
  elseif cmd == 'pet' then
    Addon:SummonMountPet()
  else
    self:PrintHelp()
  end
end

function SlashCommands:PrintHelp(cmd)
  Addon:Print('Commands (/mmm, /mountminime)')

  printCommand('add/set', L.AddDesc)
  printCommand('remove/clear/del(ete)', L.ClearDesc)
  printCommand('pet', L.SummonDesc)
end
