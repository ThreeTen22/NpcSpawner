require "/scripts/npcspawnutil.lua"
require "/scripts/util.lua"

function init()
    dLog("NpcPanel: init")
    object.setInteractive(false)
    local initialArgs = config.getParameter("npcArgs")
    if jsize(initialArgs) == 0 then
      storage.npcSpecies = storage.npcSpecies
      storage.npcSeed = storage.npcSeed or math.random(0,20000)
      storage.npcLevel = storage.npcLevel or math.max(world.threatLevel(), 1)
      storage.npcType = storage.npcType
      storage.npcParam = storage.npcParam
      storage.spawned = storage.spawned or false
      storage.spawnedID = storage.spawnedID

      local speciesList = root.assetJson("/interface/windowconfig/charcreation.config:speciesOrdering")
      local baseConfig = root.assetJson("/interface/scripted/NpcMenu/modConfig.config:init")
      local npcTypeList = shallowCopy(baseConfig.npcTypeList)
      speciesList = npcUtil.mergeUnique(speciesList, baseConfig.additionalSpecies)
      randomItUp(speciesList, npcTypeList)
    
      local args = {
        npcSpecies = storage.npcSpecies,
        npcSeed = storage.npcSeed,
        npcLevel = storage.npcLevel,
        npcType = storage.npcType,
        npcParam = storage.npcParam
      }
      object.setConfigParameter("npcArgs", args)
    else
      local args = config.getParameter("npcArgs")
      for k,v in pairs(args) do 
        storage[k] = copy(v)
      end
    end
    local timerConfig = root.assetJson("/interface/scripted/NpcMenu/modConfig.config:spawnTimers", {spawnTimer = 1, maxRespawnTime = 10})
    self.spawnTimer = timerConfig.spawnTimer
    self.maxRespawnTime = timerConfig.maxRespawnTime

    message.setHandler("getNpcData",simpleHandler(getNpcData))
    message.setHandler("setNpcData", simpleHandler(setNpcData))
    message.setHandler("detachNpc", simpleHandler(detachNpc))

    message.setHandler("removeItemAt", function(_,_, index)
      world.containerTakeAt(entity.id(), index-1)
    end)

    object.setInteractive(true)
end

function update(dt)
  if not storage.uniqueId then
    storage.uniqueId = sb.makeUuid()
    world.setUniqueId(entity.id(), storage.uniqueId)
  end


  --if we do not have a living NPC spawned, spawn a new one
  if storage.spawned == false then
    if self.spawnTimer < 0 then

      --randomItUp(self.randomize))
      local pos = entity.position()

      if string.find(object.name(), "floor",-6,true) then
        pos[2] = pos[2] + 8
      end
      local npcId = world.spawnNpc(pos, storage.npcSpecies,storage.npcType, storage.npcLevel, storage.npcSeed, storage.npcParam)

      world.callScriptedEntity(npcId, "status.addEphemeralEffect","beamin")
      --assign our new NPC a special unique id
      storage.spawnedID = sb.makeUuid()
      world.setUniqueId(npcId, storage.spawnedID)
      storage.spawned = true
      self.spawnTimer = math.floor(self.maxRespawnTime)
      --logVariant()
    else
      self.spawnTimer = self.spawnTimer - dt
    end
  else
    --if our spawned NPC has died or disappeared since last tick, set spawned to false.
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
  if (not storage.spawnedID) then storage.spawned = false; return end
  local loadedEnitity = world.loadUniqueEntity(storage.spawnedID)
  if loadedEnitity ~= 0 then
    world.callScriptedEntity(loadedEnitity, "npc.setDropPools",{})
    world.callScriptedEntity(loadedEnitity, "npc.setPersistent",false)
    world.sendEntityMessage(loadedEnitity,  "recruit.beamOut")
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

function randomItUp(speciesList,typeList,override)
  if (not storage.npcLevel) or override then storage.npcLevel = math.random(1, 10) end
  if (not storage.npcSpecies) or override then 
    storage.npcSpecies = util.randomFromList(speciesList or {"penguin"})
  end
  if (not storage.npcType) or override then
    storage.npcType = util.randomFromList(typeList or {"nakedvillager"})
  end
  if (not storage.npcSeed) or override then
    storage.npcSeed = math.random(1, 20000)
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
