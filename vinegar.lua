----
-- Vinegar - Building modification plugin with interrogation.
-- Written by Jonathan Porta (rurd4me) http://jonathanporta.com
-- Repository - https://github.com/JonathanPorta/rust-vinegar
---

PLUGIN.Title = "Vinegar"
PLUGIN.Description = "Building modification plugin for admins and users."
PLUGIN.Author = "Jonathan Porta (rurd4me) http://jonathanporta.com"
PLUGIN.Version = "0.6"

function PLUGIN:Init()

	-- Read saved config
	self.configFile = util.GetDatafile("vinegar")
	local txt = self.configFile:GetText()
	if (txt ~= "") then
		self.config = json.decode(txt)
	else
		print("Vinegar config file missing. Falling back to default settings.")
		self.config = {}
		self.config.damage = 1000
		self.config.vinegarForAll = true
		self:Save()
	end

	-- List of users with Vinegar/prod enabled.
	self.vinegarUsers = {}
	self.prodUsers = {}
 
 	-- Get a reference to the oxmin plugin
	self.oxminPlugin = cs.findplugin("oxmin")
	if (not self.oxminPlugin) then
		error("Oxmin plugin was not found!")
		return
	end

	-- Register Flag for Vinegar usage.
	local FLAG_VINEGAR = oxmin.AddFlag("canvinegar")
	local FLAG_PROD = oxmin.AddFlag("canprod")
 
	-- Register main chat command
	if(self.config.vinegarForAll) then
		-- If we want everyone to be able to use vinegar
		print("Vinegar enabled for all users.")
		self.oxminPlugin:AddExternalOxminChatCommand(self, "vinegar", {}, self.ToggleVinegar)
	else
		-- If we are restricting to admins and flag holders
		print("Vinegar enabled for all flagged users only.")
		self.oxminPlugin:AddExternalOxminChatCommand(self, "vinegar", {FLAG_VINEGAR}, self.ToggleVinegar)
	end
	self.oxminPlugin:AddExternalOxminChatCommand(self, "prod", {FLAG_PROD}, self.ToggleProd)

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
	
	print("Vinegar plugin loaded - default damage set to: "..self.config.damage)
end

function PLUGIN:Save()
	print("Saving config to file.")
	self.configFile:SetText(json.encode(self.config))
	self.configFile:Save()
end

function PLUGIN:ToggleProd(netuser, args)

	-- Toggles prod on/off for user.
	steamID = self:NetuserToSteamID(netuser)
	
	if(self.prodUsers[steamID]) then
		self.prodUsers[steamID] = false
		rust.SendChatToUser(netuser, "Prod off.")
	else
		self.prodUsers[steamID] = true
		rust.SendChatToUser(netuser, "Prod on.")
	end
	
end

function PLUGIN:ToggleVinegar(netuser, args)

	-- Toggles vinegar on/off for user.
	steamID = self:NetuserToSteamID(netuser)
	if(args[1]) then
		rust.SendChatToUser(netuser, "Setting damage amount to: "..args[1])
		self.config.damage = tonumber(args[1])
		self:Save()
	else
		if(self.vinegarUsers[steamID]) then
			self.vinegarUsers[steamID] = false
			rust.SendChatToUser(netuser, "Vinegar off. You are safe to hit buildings without consequence.")
		else
			self.vinegarUsers[steamID] = true
			rust.SendChatToUser(netuser, "Vinegar on. You will now damage buildings.")
		end
	end
end

-- lua rust bind lookups
local getStructureMasterOwnerId = util.GetFieldGetter(Rust.StructureMaster, "ownerID", true)
local NetCullRemove = util.FindOverloadedMethod(RustFirstPass.NetCull._type, "Destroy", bf.public_static, {UnityEngine.GameObject})

function RemoveObject(object)
    local objs = util.ArrayFromTable(cs.gettype("System.Object"), {object})
    cs.convertandsetonarray( arr, 0, object , UnityEngine.GameObject._type )
    NetCullRemove:Invoke(nil, objs) 
end

function PLUGIN:ModifyDamage(takedamage, damage)
	--print("vinegar.lua - PLUGIN:ModifyDamage(takedamage, damage)")
	
	local structureComponent = takedamage:GetComponent("StructureComponent")

	if(structureComponent) then
		-- A structure has been attacked!
		-- Find the structureMaster obj
		local structureMaster = structureComponent._master
		-- Find the culprit
		local attackerNetuser = self:GetDamageEventAttackerNetuser(damage)

		if(attackerNetuser) then
			-- Find the structure owner.
			local structureOwnerId = getStructureMasterOwnerId(structureMaster)
			local structureOwnerSteamId = rust.CommunityIDToSteamID(structureOwnerId)

			-- Figure out if the attacker is allowed to cause damage.
			if(self:CanDamage(attackerNetuser, structureOwnerSteamId)) then
				damage.amount = self.config.damage
				if(takedamage.health <= 0 or takedamage.health - damage.amount <= 0) then
					RemoveObject(takedamage.gameObject)
				end
				return damage
			end

			-- do some prodding!
			if(self:CanProd(attackerNetuser)) then
				self:DoProd(attackerNetuser, structureOwnerId)
			end
		end
	end	
end

function PLUGIN:DoProd(attackerNetuser, ownerId)
	-- Prod Implementation
	local ownerDetails = self:GetUserDetailsByCommunityId(ownerId)
	if(ownerDetails) then
		rust.SendChatToUser(attackerNetuser, "This is owned by "..ownerDetails.Name.."!")
	else
		rust.SendChatToUser(attackerNetuser, "Sorry, don't know who owns this...")
	end
end

function PLUGIN:CanProd(attackerNetuser)
	-- Is this person allowed to prod?
	local attackerSteamId = self:NetuserToSteamID(attackerNetuser)
	if(self.prodUsers[attackerSteamId]) then
		return true
	end
	return false
end

function PLUGIN:CanDamage(attackerNetuser, ownerSteamId)
	-- return true if attacker is allowed to damage this owner's things
	local attackerSteamId = self:NetuserToSteamID(attackerNetuser)
	if(self.vinegarUsers[attackerSteamId]) then
		-- vinegar is on, but who's stuff are we messing with?
		if(ownerSteamId == attackerSteamId) then
			-- destroying your own stuff? Proceed.
			return true
		else
			-- Only admins can destroy other's things for now!
			if(not self.oxminPluginInstance) then
				self.oxminPlugin = cs.findplugin("oxmin")
			end
			if(self.oxminPlugin.HasFlag(self.oxminPlugin, attackerNetuser, oxmin.AddFlag("godmode"), true)) then
				return true
			end
		end
	end
	-- we didn't meet any of the conditions, no destruction for you.
	return false
end

----
-- User lookup utility functions
----

function PLUGIN:NetuserToSteamID(netuser)
	local userID = rust.GetUserID(netuser)
	local steamID = rust.CommunityIDToSteamID(tonumber(userID))
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