local AddonName = ...
local Addon = _G[AddonName]

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
