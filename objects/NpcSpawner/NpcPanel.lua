require "/scripts/npcspawnutil.lua"
require "/scripts/util.lua"

function init(virtual)
    dLog(virtual ,"NpcPanel: init")
    storage.npcSpecies = storage.npcSpecies
    storage.npcSeed = storage.npcSeed or math.random(0,20000)
    storage.npcLevel = storage.npcLevel or math.max(world.threatLevel(), 1)
    storage.npcType = storage.npcType 
    storage.npcParam = storage.npcParam
    storage.panelUniqueId = (storage.panelUniqueId or entity.uniqueId())
    storage.spawned = storage.spawned or false
    storage.spawnedID = storage.spawnedID or nil
    storage.keepStorageInfo = storage.keepStorageInfo or false
    self.speciesList = root.assetJson("/interface/windowconfig/charcreation.config:speciesOrdering")
    local baseConfig = root.assetJson("/interface/scripted/NpcMenu/modConfig.config:init")
    local userConfig = getUserConfig("npcSpawnerPlus")
    local mSpeciesConfig = mergeUnique(baseConfig.additionalSpecies, userConfig.additionalSpecies)
    self.speciesList = mergeUnique(self.speciesList, mSpeciesConfig)
    self.npcTypeList = mergeUnique(baseConfig.npcTypeList, userConfig.additionalNpcTypes)
    randomItUp()
    
    local args = {
      npcSpecies = storage.npcSpecies,
      npcSeed = storage.npcSeed,
      npcLevel = storage.npcLevel,
      npcType = storage.npcType,
      npcParam = storage.npcParam
    }
    object.setConfigParameter("npcArgs", args)
    
    --if storage.keepStorageInfo then retainObjectInfo() end

    --handler for messages coming from the spawner with the spawner's unique id
    --called from spawner object after panel is created. stores the id of the parent spawner

    self.absPosition = nil
    self.spawnTimer = 1
    self.maxSpawnTime = 2
    self.needsEquipCheck = false
    self.randomize = false
    self.needToUpdateParameter = false
    --randomItUp(self.randomize)
     --dLog("get NPC DATA")
    message.setHandler("getNpcData",function(_, _)
      return getNpcData()
    end)
    --dLog("set NPC DATA")
    message.setHandler("setNpcData", function(_,_, args)
      setNpcData(args)
    end)

    message.setHandler("detachNpc", function(_,_)
      detachNpc()
    end)

    message.setHandler("sayMessage", function(_,_, args)
      sayMessage()
    end)
    if not virtual then
      object.setInteractive(true)
    end
end

--function onInteraction(args)
--  dLog("TEST !@ IS THIS HITTING?")
--  local config = config.getParameter("uiconfig")
--  dLogJson(args,"ON INTERACTION",true)
--  object.setConfigParameter("npcArgs", args)
--  return {"ScriptConsole", config}
--end

function update(dt)
  if not storage.uniqueId then
    storage.uniqueId = sb.makeUuid()
    world.setUniqueId(entity.id(), storage.uniqueId)
    local position = self.absPosition or entity.position()
    self.absPosition = position
  end


  --if we do not have a living NPC spawned, spawn a new one
  if storage.spawned == false then
    if self.spawnTimer < 0 then

      --randomItUp(self.randomize)
      dLog(storage.npcSpecies)
      dLog(storage.npcType)
      dLog(storage.npcLevel)
      dLog(storage.npcSeed)
      dLog(storage.npcParam)
      if storage.npcParam and storage.npcParam.scriptConfig then storage.npcParam.scriptConfig.spawnedBy = entity.position() end
      local npcId = world.spawnNpc(entity.position(), storage.npcSpecies,storage.npcType, storage.npcLevel, storage.npcSeed, storage.npcParam)

      world.callScriptedEntity(npcId, "status.addEphemeralEffect","beamin")
      --assign our new NPC a special unique id
      logVariant()
      storage.spawnedID = sb.makeUuid()
      world.setUniqueId(npcId, storage.spawnedID)
      storage.spawned = true 
      if self.needsEquipCheck then
        return containerCallback
      end

      self.spawnTimer = math.floor(self.maxSpawnTime)
    else
      self.spawnTimer = self.spawnTimer - dt
    end
  else
    --if our spawned NPC has died or disappeared since last tick, set spawned to false. otherwise check to see if it's time to update gear
    if storage.spawnedID and world.loadUniqueEntity(storage.spawnedID) == 0 then
      storage.spawned = false
      self.spawnTimer = self.maxSpawnTime
    end
  end

end 

function logVariant()
  local variant = root.npcVariant(storage.npcSpecies,storage.npcType, storage.npcLevel, storage.npcSeed, storage.npcParam)
  dLogJson(variant, "spawnedVariant", true)
end


function die()
  killNpc()
end

function killNpc()
  self.spawnTimer = self.maxSpawnTime
  sb.logInfo("killNPC: "..sb.print(storage.spawnedID))
  if (not storage.spawnedID) then storage.spawned = false; return end
  local loadedEnitity = world.loadUniqueEntity(storage.spawnedID)
  if loadedEnitity ~= 0 then
    world.sendEntityMessage(loadedEnitity, "recruit.beamOut")
  end
  storage.spawned = false
end


function getNpcData()
  --dLog("Gettin NPC DATA")
  local args = {}
    args.npcSpecies = storage.npcSpecies
    args.npcSeed = storage.npcSeed
    args.npcType = storage.npcType
    args.npcLevel = storage.npcLevel
    args.npcParam = storage.npcParam
  return args
end

function setNpcData(args)
  storage.npcSpecies = args.npcSpecies
  storage.npcSeed = args.npcSeed
  storage.npcType = args.npcType
  storage.npcLevel = args.npcLevel
  storage.npcParam = args.npcParam
  killNpc()
  object.setConfigParameter("npcArgs", args)
end

function detachNpc()
  storage.spawnedID = nil
  object.smash()
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
  --dLog("setting Gear")
  if spawnedID == 0 then return end
  --Desabled because it does not take into account sheathed weapons.
    --world.callScriptedEntity(spawnedID, "setNpcItemSlot","primary",weaponID)
    --world.callScriptedEntity(spawnedID, "setNpcItemSlot","alt",altID)
    world.callScriptedEntity(spawnedID, "setNpcItemSlot","back",backID)
    world.callScriptedEntity(spawnedID, "setNpcItemSlot","head",headID)
    world.callScriptedEntity(spawnedID, "setNpcItemSlot","chest",chestID)
    world.callScriptedEntity(spawnedID, "setNpcItemSlot","legs",legsID)

  --Weapon slots are calculated everytime the npc is created/recreated.  Therefore if a weapon conifguration is changed, 
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

function containerCallback()
  --if storage.spawnedID and world.loadUniqueEntity(storage.spawnedID) ~= 0 then
  --  dLog("NPC Spawner Callback")
  --  setGear()
  --else
  --  self.needsEquipCheck = true
  --  storage.spawned = false
  --  update(0)
  --end
end

function randomItUp(override)
  if (not storage.npcLevel) or override then storage.npcLevel = math.random(1, 10) end
  if (not storage.npcSpecies) or override then 
    storage.npcSpecies = util.randomFromList(self.speciesList)
    storage.npcSpecies = storage.npcSpecies or "human"
  end
  if (not storage.npcType) or override then
    storage.npcType = util.randomFromList(self.npcTypeList)
  end
  if not storage.npcSeed then
    storage.npcSeed = math.random(20000)
  end
end