require "/scripts/npcspawnutil.lua"
require "/scripts/util.lua"

function init(virtual)
    dLog(virtual ,"NpcPanel: init")
    storage.npcSpecies = storage.npcSpecies
    storage.npcSeed = storage.npcSeed or math.random(0,20000)
    storage.npcLevel = storage.npcLevel or math.max(world.threatLevel(), 1)
    storage.npcType = storage.npcType 
    storage.npcParam = storage.npcParam
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

    self.absPosition = nil
    self.spawnTimer = 1
    self.maxRespawnTime = 10
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

      --randomItUp(self.randomize))
      local npcId = world.spawnNpc(entity.position(), storage.npcSpecies,storage.npcType, storage.npcLevel, storage.npcSeed, storage.npcParam)

      world.callScriptedEntity(npcId, "status.addEphemeralEffect","beamin")
      --assign our new NPC a special unique id
      storage.spawnedID = sb.makeUuid()
      world.setUniqueId(npcId, storage.spawnedID)
      storage.spawned = true
      self.spawnTimer = math.floor(self.maxRespawnTime)
    else
      self.spawnTimer = self.spawnTimer - dt
    end
  else
    --if our spawned NPC has died or disappeared since last tick, set spawned to false. otherwise check to see if it's time to update gear
    if storage.spawnedID and world.loadUniqueEntity(storage.spawnedID) == 0 then
      storage.spawned = false
      self.spawnTimer = self.maxRespawnTime
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
  self.spawnTimer = self.maxRespawnTime
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
  self.spawnTimer = 1
end

function detachNpc()
  storage.spawnedID = nil
  object.smash()
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

--[[
function onInteraction(args)
  Guess what kids?
  If your object is a container, this function doesn't even get called.
  
  Also guess what?
  The containerCallback that would make everything amazing only calls on the object and not the pane.
  
  Guess what objects can't do (or anything else now that I think about it)?
  directly message the pane.
  
  So what does that mean?
  It means I still need to poll with the pane menu, and that makes me a sad panda.
end
--]]
