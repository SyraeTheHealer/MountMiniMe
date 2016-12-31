--[[
	Localization.lua
		Translations for Dominos

	English: Default language
--]]

local L = LibStub('AceLocale-3.0'):NewLocale('MountMiniMe', 'enUS', true)

--system messages
L.NewPlayer = 'Created new profile for %s'
L.Updated = 'Updated to v%s'

--profiles
L.ProfileCreated = 'Created new profile "%s"'
L.ProfileLoaded = 'Set profile to "%s"'
L.ProfileDeleted = 'Deleted profile "%s"'
L.ProfileCopied = 'Copied settings from "%s"'
L.ProfileReset = 'Reset profile "%s"'
L.CantDeleteCurrentProfile = 'Cannot delete the current profile'
L.InvalidProfile = 'Invalid profile "%s"'

--Slash commands
L.AddDesc = 'Adds the current mount and companion as a Mount Mini-me pair'
L.ClearDesc = 'Clears the current mount and companion from the Mount Mini-me pairs'
L.SummonDesc = 'Summons the mini-me companion for the current mount'

--minimap button stuff
L.AddTip = '<Left Click> to add a mini-me'
L.ClearTip = '<Shift Left Click> to clear a mini-me'
L.SummonPetTip = '<Alt Left Click> to re-summon a mini-me pair\'s pet'
L.ShowOptionsTip = '<Right Click> to show the options menu'

L.DismountedAddTip = '<Left Click> to add a dismounted mini-me'
L.DismountedClearTip = '<Shift Left Click> to clear a dismounted mini-me'

--Messages
L.NotMountedError = 'You are not mounted'
L.NoPetSummoned = 'You do not have a companion summoned'
L.NoPetForMount = '%s does not have a mini-me'
L.PairAdded = '%s is now %s\'s mini-me'
L.PairCleared = '%s is no longer %s\'s mini-me'
L.DismountedPairAdded = '%s is now your dismounted mini-me'
L.DismountedPairCleared = 'Dismounted mini-me cleared'