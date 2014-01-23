----
-- Vinegar - Building modification plugin.
-- Written by Jonathan Porta (rurd4me) http://jonathanporta.com
-- Repository - https://github.com/JonathanPorta/rust-vinegar
---

PLUGIN.Title = "Vinegar"
PLUGIN.Description = "Building modification plugin for admins and users."
PLUGIN.Author = "Jonathan Porta (rurd4me) http://jonathanporta.com"
PLUGIN.Version = "0.1"

function PLUGIN:Init()

	-- List of users with Vinegar enabled.
	self.users = {}
 
 	-- Get a reference to the oxmin plugin
	local oxminPlugin = cs.findplugin("oxmin")
	if (not oxminPlugin) then
		error("Oxmin plugin was not found!")
		return
	end

	-- Register Flag for Vinegar usage.
	local FLAG_VINEGAR = oxmin.AddFlag("canvinegar")
 
	-- Register main chat command
	oxminPlugin:AddExternalOxminChatCommand(self, "vinegar", {FLAG_VINEGAR}, self.DoCommand)
end


function PLUGIN:DoCommand(netuser, args)

	--print("Vinegar DoCommand")
	--vardump(args)
	self:Toggle(netuser)
	
end

function PLUGIN:Toggle(netuser)

	--print("vinegar.lua - function PLUGIN:Toggle(netuser)")
	--print("self.users")
	--vardump("self.users")

	steamID = self:NetuserToSteamID(netuser)
	
	if(self.users[steamID]) then
		self.users[steamID] = false
		rust.SendChatToUser(netuser, "Vinegar off. You are safe to hit buildings without consequence.")
	else
		self.users[steamID] = true
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

					--Figure out if the attacker is allowed to cause damage.
					attackerSteamId = self:NetuserToSteamID(attackerUser)
					if(self.users[attackerSteamId])then
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