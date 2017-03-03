
function init()
  self.gettingSpecies = nil
  self.gettingSeedValue = nil
  self.gettingType = nil
  self.gettingPosition = nil
	--these variables store the results of the messages we send to the parent panel obj
  sb.logInfo("CAFSpawner: init")
	self.sendingSpecies = nil
	self.sendingSeedValue = nil
  self.sendingType = nil

  self.sendingData = nil

  self.currentSpecies = "human"
  self.currentSeedValue = 0
  self.currentType = "CAFguard"
  self.currentPosition = nil
	--self.sliderVal = 0

	self.speciesInitialized = false;
	self.seedValueInitialized = false;
  self.typeInitialized = false;
  self.positionInitialized = false

	self.raceButtons = {}

  self.seedInput = 0

  --LIST VARS--
  self.speciesList = root.assetJson("/interface/windowconfig/charcreation.config").speciesOrdering
  self.techList = "techScrollArea.techList"


  --CATEGORY VARS--
  --`int` widget.getSelectedOption(`String` widgetName)
  ----Returns the index of the selected option in a ButtonGroupWidget.

  --`int` widget.getSelectedData(`String` widgetName)
  ----Returns the data of the selected option in a ButtonGroupWidget. Nil if no option is selected.

  self.categoryWidget = "sgSelectCategory"
  --self.buttonDataOptions = config.getParameter("rgNPCModOptions")
  ------------

  self.worldSize = 2000

  self.currentSize = 0
  self.targetSize = 0
  self.minTargetSize = -1000
  self.targetSizeIncrement = 1
  self.manualInput = false
  self.maxStepSize = self.worldSize
  -- updateGUI()
  self.portraitNeedsUpdate = false
  --logReport(testTwo)

  self.firstRun = true

  widget.setSliderRange("sldTargetSize",0, self.worldSize)
  widget.setSliderEnabled("sldTargetSize", true)
  widget.setSliderValue("sldTargetSize",0)
  
  local currentRatio = self.currentSize / self.worldSize
  
  widget.setProgress("prgCurrentProgress", currentRatio)
  
  widget.setProgress("prgAvailable", 0.0)
 -- setList({list = self.speciesList,  listType = "species"})
end


-------LIST FUNCTIONS-----------

--args:
  --list
  --listType
function setList(args)
  widget.clearListItems(self.techList)
  dLogJson(args,"setList - ARGS")
  for _,listName in pairs(args.list) do

    local listItem = widget.addListItem(self.techList)

    if args.listType == "species" then
      widget.setText(string.format("%s.%s.techName", self.techList, listItem), listName)
      widget.setData(string.format("%s.%s", self.techList, listItem), {name = listName, listType = args.listType})
    end
  end
end

--listArgs:
    --name
    --listType
function listItemSelected()
  local listItem = widget.getListSelected(self.techList)
  local listArgs = widget.getData(string.format("%s.%s", self.techList, listItem))
  dLog(listArgs.name, "listArgs.name:  ")
  dLogJson(listArgs.listType, "listArgs.listType:  ")

  if listArgs.listType == "species" then
    self.currentSpecies = listArgs.name
  end
  self.portraitNeedsUpdate = true
end

-------END LIST FUNCTIONS---------


-------CATEGORY FUNCTIONS--------

--callback when category button is selected--
--args:
  --button : ? (widget.getSelectedOption?)
  --indx buttonlabel.data (widget.getSelectedData)
function selectGenCategory(button, data)
  local  dataList = config.getParameter("rgNPCModOptions")
  local selectedOption = "NONE"
  dLog("selectGenCategory")
  dLogJson(button, "")
  for _,v in ipairs(dataList) do
    if v == data then
      selectedOption = data
      break
    end
  end
  dLog(selectedOption, "selectGenCategory - selectedOption:  ")
end

function updateCategoryIcons(category)

end

-------END CATEGORY FUNCTIONS---------

function update(dt)
  --Cannot send entity messages during init, so will do it here
  if self.firstRun then
    self.firstRun = false
    self.gettingPosition = world.sendEntityMessage(pane.sourceEntity(), "getPosition")
    self.gettingSpecies = world.sendEntityMessage(pane.sourceEntity(), "getSpecies")
    self.gettingSeedValue = world.sendEntityMessage(pane.sourceEntity(), "getSeedValue")
    self.gettingType = world.sendEntityMessage(pane.sourceEntity(), "getType")
    setList({list = self.speciesList,  listType = "species"})
  end

  --initializing the species from the panel object
  if not self.positionInitialized and self.gettingPosition:finished() and self.gettingPosition:result() then
    local result = self.gettingPosition:result()
    self.currentPosition = result
    self.positionInitialized = true
  end

  if not self.speciesInitialized and self.gettingSpecies:finished() and self.gettingSpecies:result() then
  	local result = self.gettingSpecies:result()
    sb.logInfo("speciesInitInUpdate")
    sb.logInfo(sb.print(result))
  	--world.logInfo("UI: the species index has been initialized from panel object. Changed to: " .. tostring(result))
  	--self.raceButtons[result]:select();
    self.currentSpecies = tostring(result)
  	self.speciesInitialized = true
  end

  --initializing the seed value from the panel object
  if not self.seedValueInitialized and self.gettingSeedValue:finished() and self.gettingSeedValue:result() then
  	local result = self.gettingSeedValue:result()
  	--world.logInfo("UI: the seed value has been initialized from panel object. Changed to: " .. tostring(result))
  	--self.slider.value = result
   
    if type(result) == "string" then 
      self.manualInput = true
      self.seedInput = result
      self.targetSize = 0
      if tonumber(result) then
        if tonumber(result) <= self.worldSize then
          self.targetSize = tonumber(result)
          widget.setSliderValue("sldTargetSize", self.targetSize)
        end
      end 
      widget.setText("seedValue", self.seedInput)
    else
      self.manualInput = false
      self.seedInput = result
      self.targetSize = result
      widget.setSliderValue("sldTargetSize", self.targetSize)
    end
  	self.seedValueInitialized = true
  end

  --initializing the type from the panel object
  if not self.typeInitialized and self.gettingType:finished() and self.gettingType:result() then
    local result = self.gettingType:result()
    self.currentType = tostring(result)
    --  --world.logInfo("UI: the type has been initialized from panel object. Changed to: " .. tostring(result))
    --  self.typeButtons[result]:select();
    self.typeInitialized = true
  end

  --main loop after everyting has been loaded in
  if self.typeInitialized and self.speciesInitialized and self.seedValueInitialized then
     --updateGUI()
     if self.portraitNeedsUpdate then
      self.portraitNeedsUpdate = false
      local arg = {
        level = 10.0,
        curSpecies = self.currentSpecies,
        curType = self.currentType,
        curSeed = 0,
        curPosition = self.currentPosition
      }
        
        if self.manualInput then
          arg.curSeed = self.seedInput
        else
          arg.curSeed = self.targetSize
        end
      setPortrait(arg)
     end
  end
end

function updateGUI() 
  local targetRatio = self.targetSize / self.worldSize
  widget.setProgress("prgPreviewProgress", targetRatio)
  widget.setSliderValue("sldTargetSize", self.targetSize)
end

function seedValue() 
  if self.typeInitialized and self.speciesInitialized and self.seedValueInitialized then 
    self.manualInput = true
    self.seedInput = widget.getText("seedValue")
    sb.logWarn("typedKey?")
     self.portraitNeedsUpdate = true
  end
end

function clampSize(newSize)
  return math.min(math.min(math.max(math.max(newSize, self.minTargetSize), self.currentSize), self.currentSize + self.maxStepSize), self.worldSize)
end

function updateTargetSize()

  self.manualInput = false
  self.targetSize = widget.getSliderValue("sldTargetSize")
  --self.targetSize = clampSize(widget.getSliderValue("sldTargetSize"))
  --widget.setSliderValue("sldTargetSize", self.targetSize)
  widget.setText("lblSliderAmount", tostring(self.targetSize))
  --sb.logWarn("updateTargetSize?")
  self.portraitNeedsUpdate = true
end

function increaseTargetSize()
 --self.targetSize = self.targetSize + 1
  --widget.setText("seedValue", tostring(self.targetSize + 1))
  self.manualInput = false
  world.sendEntityMessage(pane.sourceEntity(),"createLife",self.targetSize)
  self.portraitNeedsUpdate = true
end

function decreaseTargetSize()
  self.targetSize = self.targetSize - 1
  self.manualInput = false
  widget.setText("lblSliderAmount", tostring(self.targetSize - 1))
  self.portraitNeedsUpdate = true
  --self.sendingSeedValue = world.sendEntityMessage(pane.sourceEntity(), "setSeedValuePanel", self.targetSize)
  
end



function acceptBtn()
  local args = {
  npcSpecies = self.currentSpecies,
  npcType = self.currentType,
  npcSeed = nil,
  npcParams = replaceItemOverrides(nil)
}
  
  if self.manualInput then
    args.npcSeed = self.seedInput
  else
    args.npcSeed = self.targetSize
    --self.sendingSeedValue = world.sendEntityMessage(pane.sourceEntity(), "setSeedValuePanel", self.targetSize)
  end
    self.sendingData = world.sendEntityMessage(pane.sourceEntity(), "setNpcData", args)
end


function replaceItemOverrides(args)
  local params = config.getParameter("itemOverrideTemplate")
  local item = config.getParameter("itemTemplate").item[1]
  dLogJson(params, "Params: ")
  local insertPosition = params.items.override[1][2][1]
  --debug--
  insertPosition.chest = config.getParameter("itemTemplate").item
  insertPosition.chest[1].name = "hikerchest"
  insertPosition.legs = config.getParameter("itemTemplate").item
  insertPosition.legs[1].name = "hikerlegs"
  dLogJson(params, "replaceItemOverrides: Params: ")
  return params
end

function setPortrait(args)

--widget.setVisible(`String` widgetName, `bool` visible)
  dLogJson(args)
  --local parameters = root.getConfiguration("myNakedParameters")
  local params = replaceItemOverrides(args)
  dLogJson(params,"setPortraitParams")
  local variant = root.npcVariant(args.curSpecies,args.curType, args.level,args.curSeed)
 -- dLogJson(variant, "Variant:")

 -- dLogJson(newparams, "newparams")

  local npcPort = root.npcPortrait("full", args.curSpecies,args.curType, args.level, args.curSeed, params)
  --local spawn = world.spawnNpc(args.curPosition,args.curSpecies, "nakedvillager", args.level, args.curSeed, newparams)
  -- dLogJson(npcPort,"npcPort:")
   

   local names = {
    "portraitSlot01",
    "portraitSlot02",
    "portraitSlot03",
    "portraitSlot04",
    "portraitSlot05",
    "portraitSlot06",
    "portraitSlot07",
    "portraitSlot08",
    "portraitSlot09",
    "portraitSlot10",
    "portraitSlot11",
    "portraitSlot12"
  }


  local justpics = {}
  local num = 0
  local imgDirective = ""

  for _,v in pairs(names) do
    widget.setVisible(v, false)
  end


  for _,v in ipairs(npcPort) do
    num = num+1
    widget.setImage(names[num], v.image)
    widget.setVisible(names[num], true)
  end


 -- widget.setVisible("charPreview", false)

 -- widget.setData("charPreview", arg)
 --widget.setVisible("charPreview", true)
end

function copy(v)
  if type(v) ~= "table" then
    return v
  else
    local c = {}
    for k,v in pairs(v) do
      c[k] = copy(v)
    end
    setmetatable(c, getmetatable(v))
    return c
  end
end

function dLog(item, prefix)
  local p = prefix or ""
  sb.logInfo(p.."  %s",item)
end

function dOut(input)
  return sb.print(input)
end

function dLogJson(input, prefix)
  local p = prefix or ""
  if p ~= "" then
    sb.logInfo(prefix)
  end
  sb.logInfo("%s", sb.printJson(input))
end

function valuesToKeys(list)
  local newList = {}
  local vName = ""
  for k,v in pairs(list) do
    vName = tostring(v)
    newList.vName = {}
  end
end



--function spawnNpcModified(args, output)
--  args = parseArgs(args, {
--    position = "self",
--    species = npc and npc.species() or "human",
--    type = npc and npc.npcType() or "villager",
--    level = entityLevel(),
--    damageTeamType = entity.damageTeam().type,
--    damageTeam = entity.damageTeam().team,
--    seed = nil,
--    parameters = {}
--  })
--
--  local position = BData:getPosition(args.position)
--  local species = args.species
--  local npcType = args.type
--  local level = BData:getNumber(args.level)
--  local damageTeamType = args.damageTeamType
--  local damageTeam = args.damageTeam
--  local seed = BData:getNumber(args.seed)
--
--  local parameters = copy(BData:getTable(args.parameters))
--  parameters.damageTeam = damageTeam
--  parameters.damageTeamType = damageTeamType
--
--  if not position or not species or not npcType or not level then
--    return false
--  end
--
--  local entityId = world.spawnNpc(position, species, npcType, level, seed, parameters)
--  world.callScriptedEntity(entityId, "status.addEphemeralEffect", "beamin")
--  return true
--end