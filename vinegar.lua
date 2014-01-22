PLUGIN.Title = "Testing"
PLUGIN.Description = "A test plugin"

function PLUGIN:Init()
 self:AddChatCommand("test", self.cmdTest)
 self:AddChatCommand("structures", self.structures)
end

function PLUGIN:cmdTest(netuser, cmd, args)
	rust.Notice(netuser, "Testing!")
	local kit = {
		{item="Wood Foundation", qty="250"},
		{item="Wood Pillar", qty="250"},
		{item="Wood Wall", qty="250"},
		{item="Wood Ceiling", qty="250"},
		{item="Wood Doorway", qty="250"},
		{item="Wood Ramp", qty="250"},
		{item="Metal Foundation", qty="250"},
		{item="Metal Pillar", qty="250"},
		{item="Metal Wall", qty="250"},
		{item="Metal Ceiling", qty="250"},
		{item="Metal Doorway", qty="250"},
		{item="Metal Ramp", qty="250"},
	}

	for k, v in pairs(kit) do
		local cmd = "inv.giveplayer \"" .. util.QuoteSafe( netuser.displayName ) .. "\" \"" .. util.QuoteSafe( v['item'] ) .. "\" " .. tostring(v['qty'])
		print("Running Command:", cmd)		
		rust.RunServerCommand(cmd)
	end
end

-- *******************************************
-- PLUGIN:OnTakeDamage()
-- Called when an entity take damage
-- *******************************************
  local allStructures = util.GetStaticPropertyGetter(Rust.StructureMaster, 'AllStructures')
  local getStructureMasterOwnerId = util.GetFieldGetter(Rust.StructureMaster, "ownerID", true)

function PLUGIN:ModifyDamage(takedamage, damage)
	print("PLUGIN:ModifyDamage")
	--print("VARDUMP: takedamage")
	--vardump(takedamage)

	--print("VARDUMP: damage")
	--vardump(damage)

	--for i=0, allStructures().Count-1
	--do
	--	print("ownerID: ")
	--	print(getStructureMasterOwnerId(allStructures()[i]))
	--end

	local char = takedamage:GetComponent("Character")
	local deployable = takedamage:GetComponent("DeployableObject")
	local structureComponent = takedamage:GetComponent("StructureComponent")

	if (deployable) then
		--print("trying to print deployable next")
		--print(deployable)
	end

	if (structureComponent) then
		structureMaster = structureComponent._master
		print("sm for sc:")
		vardump(structureMaster)
		
		print("SM ownerID:")
		print(getStructureMasterOwnerId(structureMaster))

		--print("structureMaster._owner:")
		--testy = structureMaster._owner
		--vardump(testy)

		--print("damage.attacker:")
		--vardump(damage.attacker)

		--print("damage.attacker.client")
		--vardump(damage.attacker.client)

		--print("damage.attacker.client.netUser")
		--vardump(damage.attacker.client.netUser)
		
		local attacker = damage.attacker
		if(attacker) then
			local attackerClient = damage.attacker.client
			if attackerClient then
				local attackerUser = attackerClient.netUser
				if(attackerUser) then
					--print("Attacked by a user!")
					--rust.Notice(attackerUser, "You are attacking a structure!")
					--rust.SendChatToUser(attackerUser, "You are attacking a structure!")

					structureOwnerId = getStructureMasterOwnerId(structureMaster)
					structureOwnerSteamId = rust.CommunityIDToSteamID(structureOwnerId)

					attackerUserId = rust.GetUserID(attackerUser)
					attackerSteamId = rust.CommunityIDToSteamID(tonumber(attackerUserId))
					
					if(structureOwnerSteamId == attackerSteamId) then
						--rust.Notice(attackerUser, "Breaking your own shit.")
						--rust.SendChatToUser(attackerUser, "Breaking your own shit.")
					else
						rust.Notice(attackerUser, "Breaking someone else's shit. Don't be a douchebag, douchebag.")
						rust.SendChatToUser(attackerUser, "Breaking someone else's shit. Don't be a douchebag, douchebag.")
					end
				end
			end
		end

		damage.amount = 1000
		return damage
	end	

	if (char) then
		local netplayer = char.networkViewOwner
		if (netplayer) then
			local netuser = rust.NetUserFromNetPlayer(netplayer)
			if (netuser) then
				if (self:HasFlag( netuser, FLAG_GODMODE, true )) then
					damage.amount = 0
					return damage
				end
			end
		end
	end
end

function PLUGIN:OnStructureDecay(structure)
	print("Structure Decayed...")
	print(getStructureMasterOwnerId(structure))
end


function vardump(value, depth, key)
  local linePrefix = ""
  local spaces = ""
  
  if key ~= nil then
    linePrefix = "["..key.."] = "
  end
  
  if depth == nil then
    depth = 0
  else
    depth = depth + 1
    for i=1, depth do spaces = spaces .. "  " end
  end
  
  if type(value) == 'table' then
    mTable = getmetatable(value)
    if mTable == nil then
      print(spaces ..linePrefix.."(table) ")
    else
      print(spaces .."(metatable) ")
        value = mTable
    end		
    for tableKey, tableValue in pairs(value) do
      vardump(tableValue, depth, tableKey)
    end
  elseif type(value)	== 'function' or 
      type(value)	== 'thread' or 
      type(value)	== 'userdata' or
      value		== nil
  then
    print(spaces..tostring(value))
  else
    print(spaces..linePrefix.."("..type(value)..") "..tostring(value))
  end
end



--local GetStructureMasterOwnerIDField = field_get( Rust.StructureMaster, "ownerID", true )
--local AllStructures = static_property_get( Rust.StructureMaster, "AllStructures")

function PLUGIN:structures(netUser)
	print("Rust.StructureMaster:")
	vardump(Rust.StructureMaster)
	print("Rust:")
	vardump(Rust)
	
	print("rust:")
	vardump(rust)

	print("JSON: Rust.StructureMaster:")
	vardump(json.encode(Rust.StructureMaster))
	print(json.encode(Rust.StructureMaster))

	print("JSON: Rust:")
	vardump(json.encode(Rust))
	print(json.encode(Rust))
	print("JSON: rust:")
	vardump(json.encode(rust))
    -- Get the array that holds all StructureMaster objects in the world.
  
    -- Loop all the strucutres
    --for i=0, AllStructures().Count-1
   -- do
        -- Print the ID attached to this structure
        --print(self:GetStructureOwnerID(AllStructures()[i]))
		--print("All Structures: ")
		--vardump(AllStructures()[i])
    --end
end


-- Get the ID for this structure
function PLUGIN:GetStructureOwnerID(structure)
    --return GetStructureMasterOwnerIDField(structure)
end