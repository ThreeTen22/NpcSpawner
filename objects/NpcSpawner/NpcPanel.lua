require "/scripts/npcspawnutil.lua"
require "/scripts/util.lua"

function init(virtual)
  	if not virtual then
    	object.setInteractive(true)
  	end
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
 	  message.setHandler("setParentSpawner", function(_, _, params)
      setParentSpawner(params)
    end)
     dLog("get NPC DATA")
    message.setHandler("getNpcData",function(_, _)
      return getNpcData()
    end)
    dLog("set NPC DATA")
    message.setHandler("setNpcData", function(_,_, args)
      setNpcData(args)
    end)

    getUserInformation()
end

function containerCallback()
  dLog("container has been called back!")

end

function containerInteracted()
  dLog("container has been called back!")
  object.setConfigParameter("checkEquipmentSlots", true)
  dLog(world.getObjectParameter(pane.containerEntityId(), "checkEquipmentSlots:  "))
end

function onInteraction(args)
  local interactionConfig = world.getObjectParameter(pane.containerEntityId(),"uiConfig")
  sb.logInfo("NpcPanel: onInteraction")
  --world.containerOpen(storage.panelUniqueId)
  return {"ScriptConsole", interactionConfig}
end

function update(dt)
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
      args.npcParam = storage.npcParam
      args.npcLevel = storage.npcLevel
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


