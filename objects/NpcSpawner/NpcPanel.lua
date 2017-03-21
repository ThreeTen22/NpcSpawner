require "/scripts/npcspawnutil.lua"
require "/scripts/util.lua"

function init(virtual)
  	if not virtual then
    	object.setInteractive(true)
  	end
    local newSelf = {}
    newSelf.options = {thisIsATest = true, thisIsAlsoATest = false, thisIsAnotherParameter = {"OH BOY1","OH BOY2"}}
    newSelf.options = { clearEverything = true }
    dLog(newSelf.options, "OPTIONS")

    sb.logInfo("NpcPanel: init")
    storage.npcSpecies = storage.npcSpecies
    storage.npcSeed = storage.npcSeed
    storage.npcLevel = storage.npcLevel
    storage.npcType = storage.npcType
    storage.npcParam = storage.npcParam or {}
    storage.panelUniqueId = (storage.panelUniqueId or entity.uniqueId())
    storage.spawned = storage.spawned or false
    storage.spawnedID = storage.spawnedID or nil
    storage.randomize = storage.randomize or true

    self.config = getUserConfig("npcSpawnerPlus")
    self.speciesList = root.assetJson("/interface/windowconfig/charcreation.config:speciesOrdering")
    self.npcTypeList = config.getParameter("npcTypeList")
    appendToListIfUnique(self.speciesList, self.config.additionalSpecies)
    appendToListIfUnique(self.npcTypeList, self.config.additionalNpcTypes)
    
    --handler for messages coming from the spawner with the spawner's unique id
    --called from spawner object after panel is created. stores the id of the parent spawner

    self.absPosition = nil
    self.spawnTimer = 1
    self.maxSpawnTime = 2
    self.needsEquipCheck = false
    self.randomize = false
    randomItUp(self.randomize)
     dLog("get NPC DATA")
    message.setHandler("getNpcData",function(_, _)
      return getNpcData()
    end)
    dLog("set NPC DATA")
    message.setHandler("setNpcData", function(_,_, args)
      setNpcData(args)
    end)

end

--function onInteraction(args)
--  local interactionConfig = world.getObjectParameter(pane.containerEntityId(),"uiConfig")
--  sb.logInfo("NpcPanel: onInteraction")
--  --world.containerOpen(storage.panelUniqueId)
--  return {"ScriptConsole", interactionConfig}
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

      randomItUp(self.randomize)
      local npcId = world.spawnNpc(entity.position(), storage.npcSpecies,storage.npcType, storage.npcLevel, storage.npcSeed, storage.npcParam)

      world.callScriptedEntity(npcId, "status.addEphemeralEffect","beamin")
      --assign our new NPC a special unique id
      storage.spawnedID = sb.makeUuid()
      world.setUniqueId(npcId, storage.spawnedID)
      storage.spawned = true 
      if self.needsEquipCheck then
        return containerCallback
      end
      local variant = root.npcVariant(storage.npcSpecies,storage.npcType, storage.npcLevel, storage.npcSeed, storage.npcParam)
      dLogJson(variant, "VARIANT", true)
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

function setParentSpawner(spawnerId)
  sb.logInfo("NpcPanel: recieved the id of the parent spawner")

  if not storage.panelUniqueId then
    storage.panelUniqueId = sb.makeUuid()
    object.setUniqueId(storage.panelUniqueId)
    dCompare("uniqueIds - ",entity.uniqueId(), storage.panelUniqueId)
    dLog("regid: ", entity.id())
  end
end


function getNpcData()
  dLog("Gettin NPC DATA")
  local args = {}
    args.npcSpecies = storage.npcSpecies
    args.npcSeed = storage.npcSeed
    args.npcType = storage.npcType
    args.npcLevel = storage.npcLevel
    args.npcParam = storage.npcParam
  return args
end

function setNpcData(args)
  dLog(args, "setting npcData")
  storage.npcSpecies = args.npcSpecies
  storage.npcSeed = args.npcSeed
  storage.npcType = args.npcType
  storage.npcLevel = args.npcLevel
  storage.npcParam = args.npcParam

  local newArgs = copy(args)
  --world.spawnNpc(pos, args.npcSpecies,args.npcType, args.npcSeed ,args.npcLevel,args.npcParam)
  killNpc()
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
  dLog("setting Gear")
  if spawnedID == 0 then return end

    world.callScriptedEntity(spawnedID, "setNpcItemSlot","primary",weaponID)
    world.callScriptedEntity(spawnedID, "setNpcItemSlot","alt",altID)
    world.callScriptedEntity(spawnedID, "setNpcItemSlot","back",backID)
    --world.callScriptedEntity(spawnedID, "setNpcItemSlot","backCosmetic",backID)
    world.callScriptedEntity(spawnedID, "setNpcItemSlot","head",headID)
    --world.callScriptedEntity(spawnedID, "setNpcItemSlot","headCosmetic",chestID)

    world.callScriptedEntity(spawnedID, "setNpcItemSlot","chest",chestID)
    --world.callScriptedEntity(spawnedID, "setNpcItemSlot","chestCosmetic",chestID)

    world.callScriptedEntity(spawnedID, "setNpcItemSlot","legs",legsID)
    --world.callScriptedEntity(spawnedID, "setNpcItemSlot","legsCosmetic",legsID)

  dLog("endSettingGear Gear")
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

function containerCallback()
  --if storage.spawnedID and world.loadUniqueEntity(storage.spawnedID) ~= 0 then
  --  dLog("NPC Spawner Callback")
  --  setGear()
  --else
  --  self.needsEquipCheck = true
  --  storage.spawned = false
  --  --update(0)
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