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
    storage.npcParams = storage.npcParams or {}
  	storage.parentSpawner = storage.parentSpawner or nil
    storage.panelUniqueId = storage.panelUniqueId or entity.uniqueId() or sb.makeUuid()
    object.setUniqueId(storage.panelUniqueId)

    local pos  = entity.position()
  
    --handler for messages coming from the spawner with the spawner's unique id
    --called from spawner object after panel is created. stores the id of the parent spawner
 	  message.setHandler("setParentSpawner", function(_, _, params)
      setParentSpawner(params)
    end)

    message.setHandler("getNpcData",function(_, _)
      return getNpcData()
    end)
    
    message.setHandler("setNpcData", function(_,_, args)
      setNpcData(args)
    end)

end

function containerCallback()
  dLog("container has been called back!")

end

function containerInteracted()
  dLog("container has been called back!")
  world.setObjectParameter(pane.containerEntityId(), "checkEquipmentSlots", true)
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
end


function getNpcData()
 local args = {
      npcSpecies = storage.npcSpecies,
      npcSeed = storage.npcSeed,
      npcType = storage.npcType,
      npcParams = storage.npcParams,
      npcLevel = storage.npcLevel
    }
  return args
end

function setNpcData(args)

  storage.npcSpecies = args.npcSpecies
  storage.npcSeed = args.npcSeed
  storage.npcType = args.npcType
  storage.npcParams = args.npcParams
  storage.npcLevel = args.npcLevel

  local newArgs = copy(args)

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


