require "/scripts/npcSpawner/npcspawnutil.lua"
require "/scripts/util.lua"
require "/scripts/npcSpawner/loggingutil.lua"
require "/objects/spawner/colonydeed/timer.lua"

function init()
    object.setInteractive(false)

    local initialArgs = config.getParameter("npcArgs")
    if jsize(initialArgs) ~= 0 then
      local args = config.getParameter("npcArgs")
      for k,v in pairs(args) do 
        self[k] = copy(v)
      end
    end
  
    self.timers = TimerManager:new()

    self.healingTimer = Timer:new("healingTimer", {
      timeCallback = world.time,
      delay = "deedConfig.maxRespawnTime",
      completeCallback = respawnTenant
    })

    self.timers:manage(self.healingTimer)


    self.healthCheckTimer = Timer:new("healthCheckTimer", {
      delay = "deedConfig.checkHealthTimer",
      completeCallback = healthCheck,
      loop = true
    })
    
    self.timers:runWhile(self.healthCheckTimer, function ()
      return isOccupied() and not isHealing()
    end)

    message.setHandler("getNpcData",simpleHandler(getNpcData))
    message.setHandler("setNpcData", simpleHandler(setNpcData))
    message.setHandler("detachNpc", simpleHandler(detachNpc))
    if jsize(initialArgs) == 0 then
      randomItUp()
    end
    object.setInteractive(true)
end

function update(dt)
  if not storage.uniqueId then
    storage.uniqueId = sb.makeUuid()
    world.setUniqueId(entity.id(), storage.uniqueId)
  else
    update = mainUpdate
  end
end 

function mainUpdate(dt)
  self.timers:update(dt)
end

function healthCheck()
  if storage.spawnedID and (not world.findUniqueEntity(storage.spawnedID):result()) then
    self.healingTimer:start()
  end
end

function isHealing()
  return self.healingTimer:active()
end

function isOccupied()
  return storage.spawnedID
end

function die()
  killNpc()
end

function killNpc(id)
  if not storage.spawnedID then return end
  local loadedEnitity = world.loadUniqueEntity(storage.spawnedID)
  if loadedEnitity ~= 0 then
    world.callScriptedEntity(loadedEnitity, "npc.setDropPools",{})
    world.sendEntityMessage(loadedEnitity,  "recruit.beamOut")
  end
end

function respawnTenant()
  --randomItUp(self.randomize
  storage.spawnedID = sb.makeUuid() 
  if world.loadUniqueEntity(storage.spawnedID) ~= 0 then
    self.healingTimer:start(1)
    return
  end
  local pos = entity.position()
  pos[2] = pos[2] + 4
  local npcId = world.spawnNpc(pos, self.npcSpecies,self.npcType, self.npcLevel, self.npcSeed, self.npcParam)
  world.callScriptedEntity(npcId, "status.addEphemeralEffect","beamin")
  world.setUniqueId(npcId, storage.spawnedID)
  --assign our new NPC a special unique id
end

function getNpcData()
  local args = {}
    args.npcSpecies = self.npcSpecies
    args.npcSeed = self.npcSeed
    args.npcType = self.npcType
    args.npcLevel = self.npcLevel
    args.npcParam = self.npcParam
  return args
end

function setNpcData(args)
  if args then
    self.npcSpecies = args.npcSpecies
    self.npcSeed = args.npcSeed
    self.npcType = args.npcType
    self.npcLevel = args.npcLevel
    self.npcParam = args.npcParam
  end

  object.setConfigParameter("npcArgs", {
    npcSpecies = self.npcSpecies,
    npcSeed = self.npcSeed,
    npcType = self.npcType,
    npcLevel = self.npcLevel,
    npcParam = self.npcParam})
  if not storage.spawnedID then 
    storage.spawnedID = sb.makeUuid() 
  end
  respawnNpc()
end

function respawnNpc()
  killNpc()
  self.healingTimer:start(1)
end

function detachNpc()
  --local id = world.loadUniqueEntity(storage.spawnedID)
  storage.spawnedID = nil
  object.smash(false)
end

function randomItUp(speciesList,typeList,override)
  speciesList = speciesList or root.assetJson("/interface/windowconfig/charcreation.config:speciesOrdering")
  typeList = typeList or {"villager"}
  if (not self.npcLevel) or override then self.npcLevel = 1 end
  if (not self.npcSpecies) or override then 
    self.npcSpecies = tostring(speciesList[math.random(1, #speciesList)])
  end
  if (not self.npcType) or override then
    self.npcType = typeList[math.random(1, #typeList)]
  end
  if (not self.npcSeed) or override then
    self.npcSeed = math.random(1, 20000)
  end
  setNpcData()
  killNpc()
  self.healingTimer:start(1)
end

function logVariant()
  local variant = root.npcVariant(self.npcSpecies,self.npcType, self.npcLevel, self.npcSeed, self.npcParam)
  dLogJson(variant, "spawnedVariant", true)
end



--[[  Guess what kids?
  If your object is a container, this function doesn't get called, ever.

  function onInteraction(args)
   return {"ScriptPane","/interface/scripted/NpcMenu/NpcPanelMenu.config"}
  end

  Also guess what?
  The containerCallback doesnt forward to the the pane.
  function containerCallback(...)
    dLogJson({...}, "containerCallback:  ")
  end

  Guess what objects can't do (or anything else now that I think about it)?
  directly message the pane.
  
  So what does that mean?
  It means I still need to poll with the pane menu, and that makes me a sad panda.
  --]]