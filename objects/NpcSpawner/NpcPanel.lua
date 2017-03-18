require "/scripts/npcspawnutil.lua"
require "/scripts/util.lua"

function init(virtual)
  	if not virtual then
    	object.setInteractive(true)
  	end
  
    dCompare("compareTest:  ",nil,nil)
    sb.logInfo("NpcPanel: init")
    storage.npcSpecies = storage.npcSpecies or "human"
    storage.npcSeed = storage.npcSeed or 0
    storage.npcLevel = storage.npcLevel or 1
    storage.npcType = storage.npcType or "CAFguard"
    storage.npcParam = storage.npcParam or {}
  	storage.parentSpawner = storage.parentSpawner or nil
    storage.panelUniqueId = (storage.panelUniqueId or entity.uniqueId())
   
    local pos  = entity.position()
  
    --handler for messages coming from the spawner with the spawner's unique id
    --called from spawner object after panel is created. stores the id of the parent spawner
     dLog("get NPC DATA")
    message.setHandler("getNpcData",function(_, _)
      return getNpcData()
    end)
    dLog("set NPC DATA")
    message.setHandler("setNpcData", function(_,_, args)
      setNpcData(args)
    end)

end

function containerCallback()
  object.setConfigParameter("checkEquipmentSlots", true)
end

--function onInteraction(args)
--  local interactionConfig = world.getObjectParameter(pane.containerEntityId(),"uiConfig")
--  sb.logInfo("NpcPanel: onInteraction")
--  --world.containerOpen(storage.panelUniqueId)
--  return {"ScriptConsole", interactionConfig}
--end
function update(dt)
  --if we have not done so, send our uniqueId to the panel that we spawned
  --we have to do this here because it doesn't work in the init function unfortunately. we don't have an id assigned yet there apparently
  --storage.npcSeed = dt
  if not storage.uniqueId then
    storage.uniqueId = sb.makeUuid()
    world.setUniqueId(entity.id(), storage.uniqueId)
    self.panelID = findPanel()
    if self.panelID then
      sb.logInfo("SPAWNER: Sending Uuid to panel")
      world.sendEntityMessage(self.panelID, "setParentSpawner", storage.uniqueId)
    end
  end


  --if we do not have a living NPC spawned, spawn a new one
  if storage.spawned == false then
    self.weapon = nil
    local level = storage.npcLevel or math.random(20)
    if self.spawnTimer < 0 then
      local position = self.absPosition or object.toAbsolutePosition({ 0.0, 2.0 });
      self.absPosition = position

      local npcId = world.spawnNpc(position, storage.npcSpecies,storage.npcType, storage.npcLevel, storage.npcSeed, storage.npcParam)

      --assign our new NPC a special unique id
      storage.spawnedID = sb.makeUuid()
      world.setUniqueId(npcId, storage.spawnedID)

      storage.spawned = true 
      if self.needsEquipCheck then
        return containerCallback
      end
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

function setParentSpawner(spawnerId)
  storage.parentSpawner = spawnerId
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
  dLog(newArgs, " new parameters ")
  --world.spawnNpc(pos, args.npcSpecies,args.npcType, args.npcSeed ,args.npcLevel,args.npcParam)
  world.sendEntityMessage(storage.parentSpawner, "setNpcData", newArgs)
end

function logENV()
  for i,v in pairs(_ENV) do
    if type(v) == "function" then
      sb.logInfo("%s", i)
    elseif type(v) == "table" then
      for j,k in pairs(v) do
        sb.logInfo("%s.%s (%s)", i, j, type(k))
      end
    end
  end
end


