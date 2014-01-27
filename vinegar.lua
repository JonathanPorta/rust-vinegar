----
-- Vinegar - Building modification plugin with interrogation.
-- Written by Jonathan Porta (rurd4me) http://jonathanporta.com
-- Repository - https://github.com/JonathanPorta/rust-vinegar
---

PLUGIN.Title = "Vinegar"
PLUGIN.Description = "Building modification plugin for admins and users."
PLUGIN.Author = "Jonathan Porta (rurd4me) http://jonathanporta.com"
PLUGIN.Version = "0.2"

function PLUGIN:Init()

	-- List of users with Vinegar/prod enabled.
	self.vinegarUsers = {}
	self.prodUsers = {}
 
 	-- Get a reference to the oxmin plugin
	local oxminPlugin = cs.findplugin("oxmin")
	if (not oxminPlugin) then
		error("Oxmin plugin was not found!")
		return
	end

	-- Register Flag for Vinegar usage.
	local FLAG_VINEGAR = oxmin.AddFlag("canvinegar")
	local FLAG_PROD = oxmin.AddFlag("canprod")
 
	-- Register main chat command
	oxminPlugin:AddExternalOxminChatCommand(self, "vinegar", {FLAG_VINEGAR}, self.ToggleVinegar)
	oxminPlugin:AddExternalOxminChatCommand(self, "prod", {FLAG_PROD}, self.ToggleProd)

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
end


function PLUGIN:ToggleProd(netuser, args)

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

	steamID = self:NetuserToSteamID(netuser)
	
	if(self.vinegarUsers[steamID]) then
		self.vinegarUsers[steamID] = false
		rust.SendChatToUser(netuser, "Vinegar off. You are safe to hit buildings without consequence.")
	else
		self.vinegarUsers[steamID] = true
		rust.SendChatToUser(netuser, "Vinegar on. You will now damage buildings.")
	end
end

-- *******************************************
-- PLUGIN:OnTakeDamage()
-- Called when an entity take damage
-- *******************************************
local allStructures = util.GetStaticPropertyGetter(Rust.StructureMaster, 'AllStructures')
local getStructureMasterOwnerId = util.GetFieldGetter(Rust.StructureMaster, "ownerID", true)

function PLUGIN:ModifyDamage(takedamage, damage)
	--print("vinegar.lua - PLUGIN:ModifyDamage(takedamage, damage)")


	--local char = takedamage:GetComponent("Character")
	--local deployable = takedamage:GetComponent("DeployableObject")
	local structureComponent = takedamage:GetComponent("StructureComponent")

	--if (deployable) then
		--print("trying to print deployable next")
		--print(deployable)
	--end

	if(structureComponent) then
		-- A structure has been attacked!
		local structureMaster = structureComponent._master
		local attacker = damage.attacker
		local damageToTake = 0

		-- TODO: This user to player to net to steam crap is messy.
		if(attacker) then
			local attackerClient = damage.attacker.client
			if attackerClient then
				local attackerUser = attackerClient.netUser
				if(attackerUser) then
					-- Attacker is another player!
					-- Find the structure owner.
					structureOwnerId = getStructureMasterOwnerId(structureMaster)
					structureOwnerSteamId = rust.CommunityIDToSteamID(structureOwnerId)

					-- Figure out if the attacker is allowed to cause damage.
					attackerSteamId = self:NetuserToSteamID(attackerUser)
					if(self.vinegarUsers[attackerSteamId]) then
						-- vinegar is on, but who's stuff are we messing with?
						if(structureOwnerSteamId == attackerSteamId) then
							--destroying your own stuff? Ok.
							damageToTake = 1000
						else
							-- Only admins can destroy other's things for now!
							oxminPluginInstance = cs.findplugin("oxmin")
							if(oxminPluginInstance.HasFlag(oxminPluginInstance, attackerUser, oxmin.AddFlag("godmode"), true)) then
								damageToTake = 1000
							else
								rust.Notice(attackerUser, "This is not yours!")
							end
						end
					end
					-- Prod Implementation
					if(self.prodUsers[attackerSteamId]) then
						if(self.data.Users[""..structureOwnerId]) then
							local details = self.data.Users[""..structureOwnerId]
							rust.Notice(attackerUser, "This is owned by "..details.Name.."!")
						else
							rust.Notice(attackerUser, "Sorry, don't know who owns this...")
						end
					end
				end
			end
		end
		damage.amount = damageToTake
		return damage
	end	
end

function PLUGIN:NetuserToSteamID(netuser)
	userID = rust.GetUserID(netuser)
	steamID = rust.CommunityIDToSteamID(tonumber(userID))
	return steamID
end