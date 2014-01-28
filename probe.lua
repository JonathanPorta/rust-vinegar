----
-- Probe - Interogate structures, items and sleepers to find out who owns them.
-- Written by Jonathan Porta (rurd4me) http://jonathanporta.com
-- Repository - https://github.com/JonathanPorta/rust-vinegar
---

PLUGIN.Title = "Probe"
PLUGIN.Description = "Interogate structures, items and sleepers to find out who owns them."
PLUGIN.Author = "Jonathan Porta (rurd4me) http://jonathanporta.com"
PLUGIN.Version = "0.1"

function PLUGIN:Init()

	-- Read saved config
	self.configFile = util.GetDatafile("probe")
	local txt = self.configFile:GetText()
	if (txt ~= "") then
		self.config = json.decode(txt)
	else
		print("Probe config file missing. Falling back to default settings.")
		self.config = {}
		self.config.probeForAll = true
		self:Save()
	end

	-- List of users with probe enabled.
	self.probeUsers = {}
 
 	-- Get a reference to the oxmin plugin
	local oxminPlugin = cs.findplugin("oxmin")
	if (not oxminPlugin) then
		error("Oxmin plugin was not found!")
		return
	end

	-- Register Flag for Probe usage.
	local FLAG_PROBE = oxmin.AddFlag("canprobe")
 
	-- Register main chat command
	if(self.config.probeForAll) then
		-- If we are restricting to admins and flag holders
		print("Probe enabled for all flagged users only.")
		oxminPlugin:AddExternalOxminChatCommand(self, "probe", {FLAG_PROBE}, self.ToggleProbe)
	else
		-- If we want everyone to be able to use probe
		print("Probe enabled for all users.")
		oxminPlugin:AddExternalOxminChatCommand(self, "probe", {}, self.ToggleProbe)
	end

	-- Read in Oxmin's stash of user infos.
	-- From oxmin.lua
	self.dataFile = util.GetDatafile("oxmin")
	local txt = self.dataFile:GetText()
	if (txt ~= "") then
		self.data = json.decode(txt)
	else
		self.data = {}
		self.data.Users = {}
	end
	
	print("Probe plugin loaded.")
end

function PLUGIN:Save()
	print("Saving config to file.")
	self.configFile:SetText(json.encode(self.config))
	self.configFile:Save()
end

function PLUGIN:ToggleProbe(netuser, args)

	-- Toggles Probe on/off for user.
	steamID = self:NetuserToSteamID(netuser)
	
	if(self.probeUsers[steamID]) then
		self.probeUsers[steamID] = false
		rust.SendChatToUser(netuser, "Probe off.")
	else
		self.probeUsers[steamID] = true
		rust.SendChatToUser(netuser, "Probe on.")
	end
	
end

function PLUGIN:ModifyDamage(takedamage, damage)
	
	-- lua rust bind lookups
	local getStructureMasterOwnerId = util.GetFieldGetter(Rust.StructureMaster, "ownerID", true)
	local getDeployableOwnerId = util.GetFieldGetter(Rust.DeployableObject, "ownerID", true)

	local deployable = takedamage:GetComponent("DeployableObject")
	local structureComponent = takedamage:GetComponent("StructureComponent")

	if (deployable) then
		-- A Deployable has been attacked!
		-- Find the culprit
		local attackerNetuser = self:GetDamageEventAttackerNetuser(damage)

		if(attackerNetuser) then
			if(self:CanProbe(attackerNetuser)) then
				-- find the deployable owner
				local deployableOwnerId = getDeployableOwnerId(deployable)
				-- do some probing!
				self:DoProbe(attackerNetuser, deployableOwnerId)
				print("after probe 1") 
				-- Going to return here so we can probe without killing sleepers or items.
				damage.amount = 0
				return damage
			end
		end
	end

	if(structureComponent) then
		-- A structure has been attacked!
		-- Find the structureMaster obj
		local structureMaster = structureComponent._master
		-- Find the culprit
		local attackerNetuser = self:GetDamageEventAttackerNetuser(damage)

		if(attackerNetuser) then
			-- Find the structure owner.
			structureOwnerId = getStructureMasterOwnerId(structureMaster)
			structureOwnerSteamId = rust.CommunityIDToSteamID(structureOwnerId)

			-- Figure out if the attacker is allowed to Probe
			if(self:CanProbe(attackerNetuser)) then
				self:DoProbe(attackerNetuser, structureOwnerId)
				print("after probe 2") 
				-- Should we be disabling the damage here? i am not sure.
			end			
		end
	end	
end

function PLUGIN:DoProbe(attackerNetuser, ownerId)
	-- Probe Implementation
	local ownerDetails = self:GetUserDetailsByCommunityId(ownerId)
	if(ownerDetails) then
		rust.Notice(attackerNetuser, "This is owned by "..ownerDetails.Name.."!")
	else
		rust.Notice(attackerNetuser, "Sorry, don't know who owns this...")
	end
end

function PLUGIN:CanProbe(attackerNetuser)
	-- Is this person allowed to probe?
	local attackerSteamId = self:NetuserToSteamID(attackerNetuser)
	if(self.probeUsers[attackerSteamId]) then
		return true
	end
	return false
end

----
-- User lookup utility functions
----

function PLUGIN:NetuserToSteamID(netuser)
	userID = rust.GetUserID(netuser)
	steamID = rust.CommunityIDToSteamID(tonumber(userID))
	return steamID
end

function PLUGIN:GetUserDetailsByCommunityId(communityId)
	--return user details, or nil if not found.
	local details = self.data.Users[""..communityId] --Is there a better way to change to string?
	if(details) then
		return details
	end
	return nil
end

function PLUGIN:GetDamageEventAttackerNetuser(damage)
	-- Get netuser of an attacking user. If attacker is not a user, return nil
	local attacker = damage.attacker

	if(attacker) then
		local attackerClient = damage.attacker.client
		if attackerClient then
			local attackerNetuser = attackerClient.netUser
			if(attackerNetuser) then
				return attackerNetuser
			end
		end
	end
	return nil
end