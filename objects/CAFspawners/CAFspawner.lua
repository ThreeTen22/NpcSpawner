function init(virtual)
  if not virtual then
    object.setInteractive(true)
  end
  sb.logInfo("CAFSpawner: init")

  --auto-place the config panel. if the panel cannot be placed, the update will catch that and destroy the spawner.
  local pos = entity.position()
  pos[2] = pos[2] + 2

  storage.spawned = storage.spawned or false    --boolean flag. true if an NPC is currently spawned. false otherwise
  storage.spawnedID = storage.spawnedID or nil  --the id of the currently spawned NPC
  
  self.panelID = findPanel()
  if not self.panelID then 
    world.placeObject("CAFspawnerPanel", pos) 
    sb.logInfo("CAFSpawner: panelID Found")
  end

  storage.uniqueId = storage.uniqueId or nil    --this object's unique id. used for giving to the spawned npc
  storage.npcSpecies = storage.npcSpecies or "human"
  storage.seedValue = storage.seedValue or 0
  storage.type = storage.type or "CAFguard"
  storage.npcParams = storage.npcParams or nil

  self.maxSpawnTime = 5   --time between checks to see if a new NPC should be spawned
  self.maxGearTime = 8    --time between NPC gear change refreshes
  self.spawnTimer = self.maxSpawnTime   --spawn timer var that actively gets decremented
  self.checkGearTimer = self.maxGearTime    --gear timer var that actively gets decremented
  self.weapon = nil   --we keep a seperate var for the weapon so that we can handle switching between ranged and melee npc behavior

  self.speciesOptions = root.assetJson("/player.config").species
  self.typeOptions = config.getParameter("typeOptions")

  self.absPosition = nil
  --self.npcParameter = util.randomFromList(config.getParameter("spawner.npcParameterOptions"))

  --handler (listener) for messsages from the panel object sending this spawner the species of the NPC to be spawned
  message.setHandler("setSpecies", function(_, _, params)
    setSpecies(params)
  end)
  --handler (listener) for messsages from the panel object sending this spawner the seed value of the NPC to be spawned
  message.setHandler("setSeedValueSpawner", function(_, _, params)
    setSeedValueSpawner(params)
  end)
  --handler (listener) for messsages from the panel object sending this spawner the type of the NPC to be spawned
  message.setHandler("setType", function(_, _, params)
    setType(params)
  end)

  message.setHandler("createLife", function(_, _, params)
    createLife(params)
    end)

  message.setHandler("setNpcData", function(_, _, args)
    setNpcData(args)
  end)
end

function onInteraction(args)
  return {"ScriptConsole", interactionConfig}
end

function setNpcData(args)
  local okCheck = 0
  if args.npcSpecies then
    okCheck = okCheck+1
    storage.npcSpecies = args.npcSpecies
  end
  if args.npcSeed then
    okCheck = okCheck+1
    storage.seedValue = args.npcSeed
  end
  if args.npcType then
    okCheck = okCheck+1
    storage.type = args.npcType
  end
  if args.npcParams then
    storage.npcParams = args.npcParams
  end
  if okCheck == 3 then
    killNpc()
  else
    sb.logInfo(string.format("CAFSpawner: setNpcData: one or more args was nil - okCheck: %s", okCheck))
  end
end

function findPanel()
  local pos = entity.position()
  pos[2] = pos[2] + 2
  local objList = world.entityQuery(pos, 0)
  for i,j in ipairs(objList) do
    if world.entityName(j) == "CAFspawnerPanel" then return j end
  end
  return nil
end

function update(dt)
  --if we have not done so, send our uniqueId to the panel that we spawned
  --we have to do this here because it doesn't work in the init function unfortunately. we don't have an id assigned yet there apparently
  --storage.seedValue = dt
  if not storage.uniqueId then
    storage.uniqueId = sb.makeUuid();
    world.setUniqueId(entity.id(), storage.uniqueId)
    self.panelID = findPanel()
    if self.panelID then
      sb.logInfo("SPAWNER: Sending Uuid to panel")
      world.sendEntityMessage(self.panelID, "setParentSpawner", storage.uniqueId)
    end
  end
  if not findPanel() then 
    world.breakObject(entity.id()) 
  end

  local position = object.toAbsolutePosition({ 0.0, 2.0 });
  --if we do not have a living NPC spawned, spawn a new one
  if storage.spawned == false then
    self.weapon = nil
    local level = 10
    if self.spawnTimer < 0 then
      local position = object.toAbsolutePosition({ 0.0, 2.0 });
      self.absPosition = position
      local npcId = world.spawnNpc(position, storage.npcSpecies, storage.type, level, storage.seedValue, storage.npcParams)
      --sb.logInfo("spawning,  seed value"..storage.seedValue)
      -- local portrait = world.entityPortrait(npcId, "full")
      -- for _, y in pairs(portrait) do
      --   for a, b in pairs(y) do
      --     world.logInfo(tostring(a) .. " -> " .. tostring(b))
      --   end
      -- end
      --assign our new NPC a special unique id
      storage.spawnedID = sb.makeUuid();
      world.setUniqueId(npcId, storage.spawnedID)
      storage.spawned = true 
      self.spawnTimer = self.maxSpawnTime
    else
      self.spawnTimer = self.spawnTimer - dt
    end
  else
    self.checkGearTimer = self.checkGearTimer - dt

    --if our spawned NPC has died or disappeared since last tick, set spawned to false. otherwise check to see if it's time to update gear
    if storage.spawnedID and not world.findUniqueEntity(storage.spawnedID) then
      storage.spawned = false
    elseif self.checkGearTimer < 0 then
      --setGear()
      self.checkGearTimer = self.maxGearTime
    end
  end

end 

function setGear()
  local id = entity.id()
  local spawnedID = world.loadUniqueEntity(storage.spawnedID)
  local weaponID = world.containerItemAt(id, 0)
  local altID = world.containerItemAt(id, 1)
  local backID = world.containerItemAt(id, 2)
  local headID = world.containerItemAt(id, 3)
  local chestID = world.containerItemAt(id, 4)
  local legsID = world.containerItemAt(id, 5)

  --function calls to the NPC character. Updates all the NPC's gear.
  world.callScriptedEntity(spawnedID, "getWeapon", weaponID)
  world.callScriptedEntity(spawnedID, "getAlt", altID)
  world.callScriptedEntity(spawnedID, "getBack", backID)
  world.callScriptedEntity(spawnedID, "getHeadArmor", headID)
  world.callScriptedEntity(spawnedID, "getChestArmor", chestID)
  world.callScriptedEntity(spawnedID, "getLegArmor", legsID)

  -- world.callScriptedEntity(spawnedID, "logSeed")
  --this re-init stuff seems a little wonky, but needs to be done to manage combat behavior of the NPC when we are changing their weapon from ranged to melee and vice versa.
  -- If we do not already have a weapon and if there IS a weapon in the chest to be switched to, set our current weapon to it and re-initialize the NPC.
  if self.weapon == nil then
    if weaponID ~= nil then
      self.weapon = weaponID
      world.callScriptedEntity(spawnedID, "reInit")
    end
  --if we DO have a weapon and there is not a new one in the chest, return
  elseif weaponID == nil then return
  --if we DO have a weapon and there IS one in the chest and they are not the same, update the weapon and re-initialize the NPC
  elseif self.weapon["name"] ~= weaponID["name"] then
    self.weapon = weaponID
    world.callScriptedEntity(spawnedID, "reInit")
  end
end

function die()
  killNpc()
  if self.panelID then 
    world.breakObject(self.panelID, true) 
  end
end

function killNpc()
   if storage.spawned == true then
    local spawnedID = world.loadUniqueEntity(storage.spawnedID)
    world.callScriptedEntity(spawnedID, "suicide")
    storage.spawned = false
  end
end

--updates the species of the npc. This species is gotten from the panel objects UI. If the species is different than the current species, kill the current NPC.
function setSpecies(species)
  if species then
      --world.logInfo("The spawner recieved the message. Race is being changed to "..self.speciesOptions[species])
      storage.npcSpecies = species
      --killNpc()
  else
    sb.logInfo("the species recieved was null")
  end
end

--updates the seed value of the npc. See setSpecies()
function setSeedValueSpawner(seedValue)
  sb.logInfo("setSeedValueSpawner seedValue : "..seedValue)
  if seedValue then
      --world.logInfo("The spawner recieved the message. Seed value is being changed to "..seedValue)
      storage.seedValue = seedValue
      killNpc()
  else
    sb.logInfo("the seedValue recieved was null")
  end
end

--updates the type of the npc. See setSpecies()
function setType(type)
  if type then
      --world.logInfo("The spawner recieved the message. Type is being changed to "..self.typeOptions[type])
      storage.type = type
      --killNpc()
  else
    sb.logInfo("the type recieved was null")
  end
end

function createLife(seed)
  local level = 10
  local param = nil
  local parameters = root.getConfiguration("myConfigParameters")
  --local parameters = {}
  --parameters.damageTeam = 1.0
  --parameters.damageTeamType = "friendly"
  local testParam = {seed = nil}
  sb.logInfo("    ")
  sb.logInfo("    ")
  sb.logInfo("  ---------- ONE ----------  ")
  sb.logInfo("%s", sb.printJson(parameters))

  local position = object.toAbsolutePosition({ 0.0, 2.0 });

  local seedNum = testParam.seed;



    sb.logInfo("    ")
    sb.logInfo("    ")
   -- sb.logInfo("  ---------- TWO ----------  ")
   -- sb.logInfo("%s", sb.print(seedNum))
   -- sb.logInfo("%s", sb.print(storage.npcSpecies))
   -- sb.logInfo("%s", sb.print(position))
   -- sb.logInfo("%s", sb.print(self.absPosition))
    --sb.logInfo("%s", sb.printJson(humanoidIdentity))
    sb.logInfo("    ")
    sb.logInfo("    ")
    sb.logInfo("  ---------- THREE ----------  ")
    --local npcJSON = world.spawnNpc(storage.npcSpecies, storage.type, level, parameters)
    local spawnNPC = world.spawnNpc(position, storage.npcSpecies, storage.type, level, nil, parameters);
    --sb.logInfo("%s", sb.printJson(spawnNPC))
  --local npcJSONTwo = world.spawnNpc(storage.npcSpecies, storage.type, level, nil, humanoidIdentity)

  --local npcJSONThree = world.spawnNpc(storage.npcSpecies, storage.type, level, nil, humanoidIdentity)

    --local npcChangedJSON = root.npcVariant(position, storage.npcSpecies, storage.type, level, nil, parameters);
    --sb.logInfo("%s", sb.printJson(npcChangedJSON))
    --local jsoned = sb.printJson(npcJSON)--
    --sb.logInfo("%s", jsoned) 
    --jsoned = sb.printJson(npcChangedJSON)--
    --local humanIdentity = sb.jsonQuery(npcJSON, "humanoidIdentity", nil)
    --sb.logInfo("humanIdentity Info:  ")
    --sb.logInfo("%s", sb.printJson(humanIdentity)) --
    --local curHairDirective = sb.jsonQuery(humanIdentity, "hairDirectives", nil)
    --sb.logInfo("curHairDir Info:  ")
    --sb.logInfo("%s", sb.printJson(curHairDirective)) --
      --local newNPC = world.spawnNpc(position, storage.npcSpecies, storage.type, level, humanIdentity)
    return spawnNPC
end
