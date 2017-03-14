local AddonName = ...
local Addon = _G[AddonName]

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

			if (not isFiltered) and isUsable and isCollected and Addon:FindPetIdForMountSpellId(mountSpellId) then
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
		else
			if button.minime then
				button.minime:Hide()
			end
		end
	end
end

function Addon:UpdateMountJournalOverlays()
--	Addon:debug_print('UpdateMountJournalOverlays');

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
		local petId = Addon:FindPetIdForMountSpellId(button.spellID);

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
