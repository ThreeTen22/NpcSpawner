require "/scripts/npcspawnutil.lua"
require "/scripts/util.lua"
require "/scripts/loggingutil.lua"
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
    local placeholder = root.assetJson("/interface/scripted/npcmenu/modconfig.config:placeholderTicket")
   
    object.setConfigParameter("breakDropOptions", {{
      {
        [1]=placeholder.name,[2]=1.0,[3]=placeholder.parameters
      },
      {
        [1]=placeholder.name,[2]=1.0,[3]=placeholder.parameters
      },
      {
        [1]=placeholder.name,[2]=2.0,[3]=placeholder.parameters
      }
    }})
    object.setInteractive(true)
end

function update(dt)
  self.timers:update(dt)
  if not storage.uniqueId then
    storage.uniqueId = sb.makeUuid()
    world.setUniqueId(entity.id(), storage.uniqueId)
  end

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
  --randomItUp(self.randomize))
  local pos = entity.position()

  if string.find(object.name(), "floor",-6,true) then
    pos[2] = pos[2] + 8
  end
  local npcId = world.spawnNpc(pos, self.npcSpecies,self.npcType, self.npcLevel, self.npcSeed, self.npcParam)
  world.setUniqueId(npcId, storage.spawnedID)
  world.callScriptedEntity(npcId, "status.addEphemeralEffect","beamin")
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
  self.npcSpecies = args.npcSpecies
  self.npcSeed = args.npcSeed
  self.npcType = args.npcType
  self.npcLevel = args.npcLevel
  self.npcParam = args.npcParam

  object.setConfigParameter("npcArgs", {
    npcSpecies = self.npcSpecies,
    npcSeed = self.npcSeed,
    npcType = self.npcType,
    npcLevel = self.npcLevel,
    npcParam = self.npcParam})
  if not storage.spawnedID then 
    storage.spawnedID = sb.makeUuid() 
  end
  killNpc()
  self.healingTimer:start(1)
end

function detachNpc()
  local id = world.loadUniqueEntity(self.spawnedID)
  if id ~= 0 and path(self.npcParam, "scriptConfig", "crew", "recruitable") == false then
    world.setUniqueId(id, nil)
  end
  object.smash()
end

function randomItUp(speciesList,typeList,override)
  if (not self.npcLevel) or override then self.npcLevel = math.random(1, 10) end
  if (not self.npcSpecies) or override then 
    self.npcSpecies = tostring(speciesList[math.random(1, #speciesList)])
  end
  if (not self.npcType) or override then
    self.npcType = typeList[math.random(1, #typeList)]
  end
  if (not self.npcSeed) or override then
    self.npcSeed = math.random(1, 20000)
  end
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
