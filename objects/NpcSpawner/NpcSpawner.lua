require "/scripts/util.lua"
require "/scripts/npcspawnutil.lua"
function init(virtual)
  if not virtual then
    object.setInteractive(true)
  end
  sb.logInfo("NpcSpawner: init")  

  --auto-place the config panel. if the panel cannot be placed, the update will catch that and destroy the spawner.
  local pos = entity.position()
  pos[2] = pos[2] + 2

  storage.spawned = storage.spawned or false    --boolean flag. true if an NPC is currently spawned. false otherwise
  storage.spawnedID = storage.spawnedID or nil  --the id of the currently spawned NPC
  
  self.panelID = findPanel()
  if not self.panelID then 
    world.placeObject("NpcSpawnerPanel", pos) 
    sb.logInfo("NpcSpawner: panelID Found")
  end

  storage.uniqueId = storage.uniqueId or nil    --this object's unique id. used for giving to the spawned npc
  storage.npcSpecies = storage.npcSpecies or "human"
  storage.seedValue = storage.seedValue or 0
  storage.type = storage.type or "CAFguard"
  storage.level = storage.level or 10
  storage.npcParams = storage.npcParams or {}

  self.maxSpawnTime = 5   --time between checks to see if a new NPC should be spawned
  self.maxGearTime = 8    --time between NPC gear change refreshes
  self.spawnTimer = self.maxSpawnTime   --spawn timer var that actively gets decremented
  self.checkGearTimer = self.maxGearTime    --gear timer var that actively gets decremented
  self.weapon = nil   --we keep a seperate var for the weapon so that we can handle switching between ranged and melee npc behavior

  self.speciesOptions = root.assetJson("/interface/windowconfig/charcreation.config").speciesOrdering
  self.typeOptions = world.getObjectParameter(pane.containerEntityId(),"typeOptions",{})

  self.absPosition = nil
  --self.npcParameter = util.randomFromList(world.getObjectParameter(pane.containerEntityId(),"spawner.npcParameterOptions"))

  --handler (listener) for messsages from the panel object sending this spawner the species of the NPC to be spawned

  message.setHandler("setNpcData", function(_, _, args)
    setNpcData(args)
  end)
  
end

function onInteraction(args)
  return {"ScriptConsole", interactionConfig}
end

function setNpcData(args)

  if args.npcSpecies then
    storage.npcSpecies = args.npcSpecies
  end
  if args.npcSeed then
    storage.seedValue = args.npcSeed
  end
  if args.npcType then
    storage.type = args.npcType
  end
  if args.npcLevel then
    storage.level = args.npcLevel
  end
  if args.npcParams then
    storage.npcParams = args.npcParams
  end
  if storage.spawned then
     killNpc()
  else
    sb.logInfo(string.format("NpcSpawner: setNpcData: one or more args was nil - okCheck: %s", okCheck))
  end

end

function findPanel()
  local pos = entity.position()
  pos[2] = pos[2] + 2
  local objList = world.entityQuery(pos, 0)
  for i,j in ipairs(objList) do
    if world.entityName(j) == "NpcSpawnerPanel" then return j end
  end
  return nil
end

function update(dt)
  --if we have not done so, send our uniqueId to the panel that we spawned
  --we have to do this here because it doesn't work in the init function unfortunately. we don't have an id assigned yet there apparently
  --storage.seedValue = dt
  if not storage.uniqueId then
    storage.uniqueId = sb.makeUuid()
    world.setUniqueId(entity.id(), storage.uniqueId)
    self.panelID = findPanel()
    if self.panelID then
      sb.logInfo("SPAWNER: Sending Uuid to panel")
      world.sendEntityMessage(self.panelID, "setParentSpawner", storage.uniqueId)
    end
  end
  sb.logInfo("Finding Panel")
  sb.logInfo("Panel Not Found")
  if not findPanel() then 
    world.breakObject(entity.id()) 
  end

  --if we do not have a living NPC spawned, spawn a new one
  if storage.spawned == false then
    self.weapon = nil
    local level = 10
    if self.spawnTimer < 0 then
      local position = object.toAbsolutePosition({ 0.0, 2.0 });
      self.absPosition = position

      local newParam = copy(storage.npcParams)

      
      --local npcId = world.spawnNpc(position, storage.npcSpecies, storage.type, level, storage.seedValue, storage.npcParams)
      local npcId = world.spawnNpc(position, storage.npcSpecies,storage.type, storage.level, storage.seedValue, newParam)
      --sb.logInfo("spawning,  seed value"..storage.seedValue)
      -- local portrait = world.entityPortrait(npcId, "full")
      -- for _, y in pairs(portrait) do
      --   for a, b in pairs(y) do
      --     world.logInfo(tostring(a) .. " -> " .. tostring(b))
      --   end
      -- end
      --assign our new NPC a special unique id
      storage.spawnedID = sb.makeUuid()
      world.setUniqueId(npcId, storage.spawnedID)

      storage.spawned = true 
      self.spawnTimer = self.maxSpawnTime
    else
      self.spawnTimer = self.spawnTimer - dt
    end
  else
    self.checkGearTimer = self.checkGearTimer - dt

    --if our spawned NPC has died or disappeared since last tick, set spawned to false. otherwise check to see if it's time to update gear
    if storage.spawnedID and world.loadUniqueEntity(storage.spawnedID) == 0 then
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
  if spawnedID == 0 then return end

  if weaponID then
    world.callScriptedEntity(spawnedID, "npc.setItemSlot","primary",weaponID)
  end
  if altID then
    world.callScriptedEntity(spawnedID, "npc.setItemSlot","alt",altID)
  end
  if backID then
    world.callScriptedEntity(spawnedID, "npc.setItemSlot","back",backID)
  end

  if headID then
    world.callScriptedEntity(spawnedID, "npc.setItemSlot","head",headID)
  end

  if chestID then
    world.callScriptedEntity(spawnedID, "npc.setItemSlot","chest",chestID)
  end

  if legsID then
    world.callScriptedEntity(spawnedID, "npc.setItemSlot","legs",chestID)
  end

 -- if spawnedID then
 --   world.callScriptedEntity(spawnedID, "npc.setDisplayNametag", true)
 -- end

  -- world.callScriptedEntity(spawnedID, "logSeed")
  --this re-init stuff seems a little wonky, but needs to be done to manage combat behavior of the NPC when we are changing their weapon from ranged to melee and vice versa.
  -- If we do not already have a weapon and if there IS a weapon in the chest to be switched to, set our current weapon to it and re-initialize the NPC.
  if self.weapon == nil then
    if weaponID ~= nil then
      self.weapon = weaponID
      world.callScriptedEntity(spawnedID, "Init")
    end
  --if we DO have a weapon and there is not a new one in the chest, return
  elseif weaponID == nil then return
  --if we DO have a weapon and there IS one in the chest and they are not the same, update the weapon and re-initialize the NPC
  elseif self.weapon["name"] ~= weaponID["name"] then
    self.weapon = weaponID
    world.callScriptedEntity(spawnedID, "Init")
  end
end

function die()
  killNpc()
  if self.panelID then 
    world.breakObject(self.panelID, true) 
  end
end

function killNpc()
  sb.logInfo("killNPC: "..sb.print(storage.spawnedID))
  if (not storage.spawnedID) then storage.spawned = false; return end
  local loadedEnitity = world.loadUniqueEntity(storage.spawnedID)
  if loadedEnitity ~= 0 then
    world.callScriptedEntity(loadedEnitity, "suicide")
  end
  storage.spawned = false
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
    return spawnNPC
end


--Works!
function spawnTestItem()
  local itemParam = world.getObjectParameter(pane.containerEntityId(),"templateOverride",{})
  if not itemParam then return end
  local item = world.spawnItem("spawnerwizard", self.absPosition, 1, itemParam)
end
