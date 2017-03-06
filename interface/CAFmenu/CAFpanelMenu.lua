require "/scripts/util.lua"
function init()
  --self.gettingSpecies = nil
  --self.gettingSeedValue = nil
  --self.gettingType = nil
  --self.gettingPosition = nil
  self.gettingNpcData = nil
	--these variables store the results of the messages we send to the parent panel obj
  sb.logInfo("CAFPanekMenu: init")
	self.sendingSpecies = nil
	self.sendingSeedValue = nil
  self.sendingType = nil

  self.npcDataInit = false

  self.sendingData = nil

  self.currentSpecies = "human"
  self.currentSeed = 0
  self.currentType = "CAFguard"
  self.currentPosition = nil
  self.currentIdentity = nil
  self.currentIdentityOverrides = nil

  self.currentLevel = 10
	--self.sliderVal = 0

	self.speciesInitialized = false;
	self.seedValueInitialized = false;
  self.typeInitialized = false;
  self.positionInitialized = false

	self.raceButtons = {}

  self.seedInput = 0

  --LIST VARS--
  self.scrollArea = "techScrollArea"
  self.techList = "techScrollArea.techList"

  self.tabData = nil
  self.tabSelectedOption = -1
  self.tabRadioGroup = "rgTabs"
  self.npcTypeConfigList = "npcTypeList"
  
  self.speciesList = root.assetJson("/interface/windowconfig/charcreation.config").speciesOrdering


  self.typeList = config.getParameter(self.npcTypeConfigList)

  --CATEGORY VARS--
  --`int` widget.getSelectedOption(`String` widgetName)
  ----Returns the index of the selected option in a ButtonGroupWidget.

  --`int` widget.getSelectedData(`String` widgetName)
  ----Returns the data of the selected option in a ButtonGroupWidget. Nil if no option is selected.

  self.categoryWidget = "sgSelectCategory"

  self.categoryWidgetData = "Generate"

  --OVERI
  --self.buttonDataOptions = config.getParameter("rgNPCModOptions")
  ------------
  ---OVERRIDE VARS----
  self.manualInput = false
  self.overrideTextBox = "tbOverrideBox"
  self.overrideText = ""


  self.worldSize = 2000

  self.currentSize = 0
  self.targetSize = 0
  self.minTargetSize = 0
  self.targetSizeIncrement = 1

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


  --testFunction()
   -- setList({list = self.speciesList,  listType = "species"})
end


function finalizeOverride()
  dLog("FinalizingOverride")
  self.overrideText = widget.getText(self.overrideTextBox)

  local parsedStrings = parseOverride(self.overrideText, "")
  dLogJson(parsedStrings, "ParsedStrings:  ")

  if parsedStrings[1] ~= "nil" then
    self.currentSpecies = parsedStrings[1]
  end
  if parsedStrings[2] ~= "nil" then
    self.currentType = parsedStrings[2]
  end
  if parsedStrings[3] ~= "nil" then
    self.currentLevel = parsedStrings[3]
  end
  if parsedStrings[4] ~= "nil" then
    self.seedInput = parsedStrings[4]
  end

  self.manualInput = true
  self.portraitNeedsUpdate = true
  return
end

function parseOverride(txt, char)
  local parsedStrings = {}

  for str in string.gmatch(txt, "%w*") do
    if str ~= "" then
      table.insert(parsedStrings, str)
    end
  end

  return parsedStrings

end

function setNpcName()
  dLog("setNpcName")
end

function update(dt)
  --Cannot send entity messages during init, so will do it here
  if self.firstRun then
    dLog("Update :  FirstRun")
    self.firstRun = false
    self.gettingNpcData = world.sendEntityMessage(pane.sourceEntity(), "getNpcData")
    
  end

  --initializing the seed value from the panel object
  if not self.npcDataInit and self.gettingNpcData:finished() and self.gettingNpcData:result() then
  	local result = self.gettingNpcData:result()
  	--world.logInfo("UI: the seed value has been initialized from panel object. Changed to: " .. tostring(result))
  	--self.slider.value = result
    self.npcDataInit = true

    if result.npcSpecies then
      self.currentSpecies = tostring(result.npcSpecies)
    end

    if result.npcType then
      self.currentType = tostring(result.npcType)
    end

    if type(result.seedValue) == "string" then 
      self.manualInput = true
      self.seedInput = result.seedValue
      self.targetSize = 0
      if tonumber(result.seedValue) then
        if tonumber(result.seedValue) <= self.worldSize then
          self.targetSize = tonumber(result.seedValue)
          widget.setSliderValue("sldTargetSize", self.targetSize)
        end
      end 
      widget.setText("seedValue", self.seedInput)
    else
      self.manualInput = false
      self.seedInput = result.seedValue
      self.targetSize = result.seedValue
      widget.setSliderValue("sldTargetSize", self.targetSize)
    end
    widget.setSelectedOption(self.tabRadioGroup, self.tabSelectedOption)
  end

  --main loop after everyting has been loaded in
  if self.npcDataInit then
     --updateGUI()
    if self.portraitNeedsUpdate then
      self.portraitNeedsUpdate = false
      local arg = {
        level = self.currentLevel,
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

function acceptBtn()
  local args = {
  npcSpecies = self.currentSpecies,
  npcType = self.currentType,
  npcSeed = nil,
  npcParams = nil
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
  args = parseArgs(args, {
    head = nil,
    chest = "hikerchest",
    legs = "hikerlegs",
    back = nil
  })
  local params = config.getParameter("itemOverrideTemplate")
  local item = config.getParameter("itemTemplate").item[1]
  dLogJson(params, "Params: ")
  local insertPosition = params.items.override[1][2][1]
  --debug--
  insertPosition.chest = config.getParameter("itemTemplate").item
  insertPosition.chest[1].name = args.chest
  insertPosition.legs = config.getParameter("itemTemplate").item
  insertPosition.legs[1].name = args.legs
  dLogJson(params, "replaceItemOverrides: Params: ")
  return params
end

function setPortrait(args)

  local variant = root.npcVariant(args.curSpecies,args.curType, args.level, args.curSeed)
  self.currentIdentity = copy(variant.humanoidIdentity)

  widget.setText("tbNameBox", variant.humanoidIdentity.name)

  local npcPort = root.npcPortrait("full", args.curSpecies,args.curType, args.level, args.curSeed, params)


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
    "portraitSlot12",
    "portraitSlot13",
    "portraitSlot14",
    "portraitSlot15"
  }


  local num = 0

  for _,v in pairs(names) do
    widget.setVisible(v, false)
  end


  for _,v in ipairs(npcPort) do
    num = num+1
    widget.setImage(names[num], v.image)
    widget.setVisible(names[num], true)
  end

end

-------TEST FUNCTIONS-----------
--not useful in any way, used to test things

function testFunction()
    local config = root.npcConfig("villager")
    dLogJson(config, "config:")
end


function getSpeciesOptions(species, option)
  local speciesJson = getAsset("/species/"..species..".species") or nil

  if not speciesJson then dLog("getSpeciesOptions:  nil AssetFile") end

    --dLogJson(speciesJson, "speciesJSON: ")

  local genderPath = speciesJson.genders

    dLogJson(genderPath, "genderPath: ")

  local gender = self.currentIdentity.gender

    dLog(gender,  "gender: ")

  local genderIndx = 1
  local returnInfo = {}

  local title = {}
  local imgPath = {}

  if not gender then dLog("getSpeciesOptions:  nil gender") end

  dLogJson(genderPath[1]["name"], "genderPath[1]['name']: ")

  if genderPath[1]["name"] == gender then
    genderIndx = 1
  else
    genderIndx = 2
  end

  if option == "hair" then
    local hairInfo = {}
    
    hairInfo.hairGroup = genderPath[genderIndx].hairGroup or "hair"
    hairInfo.hair = genderPath[genderIndx].hair

    for _,v in ipairs(hairInfo.hair) do
      table.insert(title, v)
      table.insert(imgPath, string.format("/humanoid/%s/%s/%s.png",species,hairInfo.hairGroup,v))
    end
    returnInfo.title = title
    returnInfo.imgPath = imgPath
    returnInfo.hairGroup = hairInfo.hairGroup
    return returnInfo
  end 
end

function getAsset(assetPath)
  local asset = root.assetJson(assetPath)
  return asset
end
-------LIST FUNCTIONS-----------


--callback when tab is selected--
--args:
  --button : ? (widget.getSelectedOption?)
  --indx buttonlabel.data (widget.getSelectedData)
function selectTab(button, data)
  dLog("selectTab :")
  local listOption = widget.getSelectedOption(self.tabRadioGroup)
  dLog(listOption, "listOption: ")
  local args = {}
  if data == "tab1" then
    if self.categoryWidgetData == "Generate" then
      args.list = copy(self.speciesList)
      args.listType = "species"
      args.currentSelection = self.currentSpecies
    elseif self.categoryWidgetData == "Refine" then
      local data = getSpeciesOptions(self.currentSpecies, "hair")
      args = {list = data.title, imgPath = data.imgPath, hairGroup = data.hairGroup, listType = "hair"}
    end

    return setList(args)
  end
  if data == "tab2" then
    if self.categoryWidgetData == "Generate" then
      args.list = copy(self.typeList)
      args.listType = "npcType"
      args.currentSelection = self.currentType
      return setList(args)
    end
  end
  if data == "tab3" then
    if self.categoryWidgetData == "Generate" then
      return setList(nil)
    end
  end

  if data == "tab4" then
    if self.categoryWidgetData == "Generate" then
      return setList(nil)
    end
  end
  dLog(args, "selectTab Failed - > args: ")
end


--args:
  --list
  --listType
function setList(args)
  dLogJson(args,"setList - ARGS")
  --table.sort(args.list)
  widget.clearListItems(self.techList)

  if not args then return end

  for _,v in pairs(args.list) do

      local listItem = widget.addListItem(self.techList)
      local newArgs = {}

      newArgs.name = v
      newArgs.listType = args.listType
      newArgs.hairGroup = args.hairGroup

      widget.setText(string.format("%s.%s.techName", self.techList, listItem), v)
      widget.setData(string.format("%s.%s", self.techList, listItem), newArgs)

      if v == args.currentSelection then 
        sb.logInfo("setList:  entered setListSelected")
        widget.setListSelected(self.techList, listItem)
      end

  end
end

--args:
    --name
    --listType
function listItemSelected()
  local listItem = widget.getListSelected(self.techList)
  if not listItem then return end
  sb.logInfo(string.format("%s.%s", self.techList, listItem))
  local listArgs = widget.getData(string.format("%s.%s", self.techList, listItem))
  dLog(listArgs.name, "listArgs.name:  ")
  dLog(listArgs.listType, "listArgs.listType:  ")

  if listArgs.listType == "species" then
    self.currentSpecies = tostring(listArgs.name)
  end
  if listArgs.listType == "npcType" then
    self.currentType = tostring(listArgs.name)
  end
  self.manualInput = false
  self.portraitNeedsUpdate = true
end

-------END LIST FUNCTIONS---------


-------CATEGORY FUNCTIONS--------

function changeTabLabels(tabs, option)
  tabs = tabs or "nil"
  option = option or "nil"

  local tabOptions = config.getParameter("tabOptions")[option]
  local indx = 1
  
  if tabOptions then
    for _,v in ipairs(tabs) do
      widget.setText(v, tabOptions[indx])
      indx = indx+1
    end
  end
end

--callback when category button is selected--
--args:
  --button : ? (widget.getSelectedOption?)
  --indx buttonlabel.data (widget.getSelectedData)
function selectGenCategory(button, data)
  local  dataList = config.getParameter("rgNPCModOptions")
  local selectedOption = "NONE"
  local tabNames = {"lblTab01","lblTab02","lblTab03","lblTab04"}

  dLog("selectGenCategory")
  dLog(button, "button:  ")

  for _,v in ipairs(dataList) do
    if v == data then
      selectedOption = data
      break
    end
  end

  self.categoryWidgetData = data

  if data == "Generate" then
    changeTabLabels(tabNames, "Generate")
    widget.setVisible(self.scrollArea, true)
    widget.setSelectedOption(self.tabRadioGroup, -1)
    widget.setSliderEnabled("sldTargetSize", true)
    return
  elseif data == "Refine" then
    changeTabLabels(tabNames, "Refine")
    --widget.setVisible(self.scrollArea, false)
    widget.setSliderEnabled("sldTargetSize", false)
  end

  dLog(selectedOption, "selectGenCategory - selectedOption:  ")
end

-------END CATEGORY FUNCTIONS---------

function dLog(item, prefix)
  local p = prefix or ""
  if type(item) ~= "string" then
    sb.logInfo("%s %s",p, dOut(item))
  else 
    sb.logInfo("%s %s",p,item)
  end
end

function dOut(input)
  return sb.print(input)
end

function dLogJson(input, prefix)
  if prefix ~= nil then
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

function keysToList(keyList)
  local newList = {}
  local count = 0
  for k,_ in pairs(keyList) do
    count = count + 1
    table.insert(newList,tostring(k))
  end
  return newList
  end