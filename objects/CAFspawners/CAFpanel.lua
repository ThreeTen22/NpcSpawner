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


    message.setHandler("createLife", function(_, _, param)
      createLife(param)
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


  --getSpeciesParams()

  return {"ScriptPane", interactionConfig}
end

function update(dt)
end 

-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
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
  world.sendEntityMessage(storage.parentSpawner, "setNpcData", args)
end

function getSpeciesParams()
  logENV()
  local things = config.getParameter("configToQuery")

  for k,v in pairs(things) do
    dLogJson(root.assetJson(tostring(v)), tostring(k))
  end

  local charCreationConfig = root.assetJson("/interface/windowconfig/charcreation.config").speciesOrdering
  dlog("charCreationJSON:")
  dLogJson(charCreationConfig)


  --local novakid = root.assetJson("/species/novakid.species")
  --local fenerox = root.assetJson("/species/fenerox.species")
  local variant = root.npcVariant("human", "villager", (sb.makeRandomSource():randf(1,1)))
  dLogJson(variant, "VARIANT:")



  dLogJson(root.npcConfig("villager"), "NPC VILLAGER CONFIG:")
  --logReport(novakid)
  --logReport(fenerox)
  local portrait = root.npcPortrait("full","human", "villager", (sb.makeRandomSource():randf(1,1)), variant.seed)
  dLogJson(portrait, "PORTRAIT:")

  --parseSpeciesInfo
  --set species ""
  --set gender "identity/genders"
  --set body/hair color
  --set personality - (humanoid.config)
  --set name root.generateName(`String` assetPath, [`unsigned` seed])

end

--function logReport(js) 
--dLogJson(js)
--if js == nil then 
--  dlog("cannot Report!")
--  return 
--end

--local genders = js.genders
--  if genders then 
--    dlog("genders OK!") 
--  end
--  local maleOut = genders[1].pants[2]
--  local femaleOut = genders[2].hair
--  dlog(dout(maleOut), js.kind.." - "..genders[1].name)
--  dlog(dout(femaleOut), js.kind..genders[2].name)
--
--end

--function dlog(item, prefix)
--  local p = prefix or ""
--  sb.logInfo(p.."  ".."%s",item)
--end
--
--function dout(input)
--  return sb.print(input)
--end

--function dLogJson(input, prefix)
--  local p = prefix or ""
--  if p ~= "" then
--    sb.logInfo(prefix)
--  end
--  sb.logInfo("%s", sb.printJson(input))
--end

--function valuesToKeys(list)
--  local newList = {}
--  local vName = ""
--  for k,v in pairs(list) do
--    vName = tostring(v)
--    newList.vName = {}
--  end
--end


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


function setParentSpawner(spawnerId)
  storage.parentSpawner = spawnerId
  sb.logInfo("CAFPanel: recieved the id of the parent spawner")
end

function setSpecies(species)
  storage.npcSpecies = species
	if storage.parentSpawner then
		--world.logInfo("PANEL: sending raceChange message to the spawner obj. Message is: "..tostring(speciesIndex))
    --after getting the species from the UI panel, pass it on to the spawner
		world.sendEntityMessage(storage.parentSpawner, "setSpecies", storage.npcSpecies)
	else
		sb.logInfo("The panel object did not pass on the species index because the parentSpawner was not found or is null.")
	end
end

function setSeedValuePanel(seedValue)
  storage.seedValue = seedValue
  sb.logInfo("setSeedPanelHit"..seedValue)
  if storage.parentSpawner then
    --world.logInfo("PANEL: sending seed value message to the spawner obj. Message is: "..tostring(seedValue))
    world.sendEntityMessage(storage.parentSpawner, "setSeedValueSpawner", storage.seedValue)
  else
    sb.logInfo("The panel object did not pass on the seed value because the parentSpawner was not found or is null.")
  end
end

function setType(type)
  storage.type = type
  if storage.parentSpawner then
    --world.logInfo("PANEL: sending type change message to the spawner obj. Message is: "..tostring(type))
    world.sendEntityMessage(storage.parentSpawner, "setType", storage.type)
  else
    sb.logInfo("The panel object did not pass on the type because the parentSpawner was not found or is null.")
  end
end

function getSpecies()
  if storage.npcSpecies ~= nil then
    --world.logInfo("PANEL: Species requested. The speciesIndex is: " .. tostring(storage.speciesIndex))
    return storage.npcSpecies
  else
    sb.logInfo("PANEL: Species requested. The speciesIndex was nil.")
    return 1
  end
end

function getSeedValue()
  if storage.seedValue ~= nil then
    --world.logInfo("PANEL: Seed value requested. The seed value is: " .. tostring(storage.seedValue))
    return storage.seedValue
  else
    sb.logInfo("PANEL: Seed value requested. The seed value was nil.")
    return 0
  end
end

function getType()
  if storage.type ~= nil then
    --world.logInfo("PANEL: Type requested. The type is: " ..storage.type)
    return storage.type
  else
    sb.logInfo("PANEL: Type requested. The type was nil.")
    return 0
  end
end

function createLife(seed)
  world.sendEntityMessage(storage.parentSpawner,"createLife",seed)
end

