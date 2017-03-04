function init(virtual)
  	if not virtual then
    	object.setInteractive(true)
  	end
    sb.logInfo("CAFPanel: init")

    storage.npcSpecies = storage.npcSpecies or "human"
    storage.seedValue = storage.seedValue or 0
    storage.type = storage.type or "CAFguard"
  	storage.parentSpawner = storage.parentSpawner or nil

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

function onInteraction(args)
  local interactionConfig = config.getParameter("uiConfig")
  sb.logInfo("CAFPanel: onInteraction")



  return {"ScriptPane", interactionConfig}
end

function update(dt)
end 

-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
function setParentSpawner(spawnerId)
  storage.parentSpawner = spawnerId
  sb.logInfo("CAFPanel: recieved the id of the parent spawner")
end


function getNpcData()
 local args = {
      npcSpecies = storage.npcSpecies,
      seedValue = storage.seedValue,
      npcType = storage.type
    }
  return args
end

function setNpcData(args)

  storage.npcSpecies = args.npcSpecies
  storage.seedValue = args.npcSeed
  storage.type = args.npcType

  local newArgs = {
    npcSpecies = args.npcSpecies,
    npcSeed = args.npcSeed,
    npcType = args.npcType
  }

  world.sendEntityMessage(storage.parentSpawner, "setNpcData", newArgs)
end



function colorOptionToDirectives(colorOption)
  if not colorOption then return "" end
  local dir = "?replace"
  for k,v in pairs(colorOption) do
    dir = dir .. ";" .. k .. "=" .. v
  end
  return dir
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


