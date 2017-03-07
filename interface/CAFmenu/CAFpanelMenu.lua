require "/scripts/util.lua"
function init()
  --self.gettingSpecies = nil
  --self.gettingSeedValue = nil
  --self.gettingType = nil
  --self.gettingPosition = nil
  self.gettingNpcData = nil
	--these variables store the results of the messages we send to the parent panel obj
  sb.logInfo("CAFPanelMenu: init")
	self.sendingSpecies = nil
	self.sendingSeedValue = nil
  self.sendingType = nil

  self.npcDataInit = false

  self.sendingData = nil

  self.currentSpecies = "human"
  self.currentSeed = 0
  self.currentType = "CAFguard"
  self.currentPosition = nil
  self.currentIdentity = {}
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
  self.tabGroupWidget = "rgTabs"
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


  self.testDirective = "?replace;735e3a=2d1606;d9c189=7d3c1c;a38d59=4d240b?replace;951500=848008;be1b00=a8a614;dc1f00=e3e13a"
  self.testDirective2 = "?replace;735e3a=2d1606;d9c189=7d3c1c;a38d59=4d240b"
  local result = string.find(self.testDirective, self.testDirective2, 1, true)

  dLog(result, "string.find result - ")

  widget.setSliderRange("sldTargetSize",0, self.worldSize)
  widget.setSliderEnabled("sldTargetSize", true)
  widget.setSliderValue("sldTargetSize",0)
  
  local currentRatio = self.currentSize / self.worldSize
  
  widget.setProgress("prgCurrentProgress", currentRatio)
  
  widget.setProgress("prgAvailable", 0.0)



  --testFunction()
   -- setList({list = self.speciesList,  listType = "species"})
end


function replaceDirectives(directive, directiveJson)
  local returnString = ""
  local splitDirectives = util.split(directive,"?replace")
  --dLogJson(splitDirectives, "replaceDirectives: split: ")
  dLogJson(directiveJson, "directiveJson")
  for _,v in ipairs(splitDirectives) do
    --dLogJson(v, "replaceDirectives: v: ")
    if not (v == "") then
      --dLog("entered iPairLoop:  ")
      --dLog(string.match(v, "(%w+)=(%w+)"), "string Match:  ")
      --test if its correct directiveGroup
        local k = string.match(v, "(%w+)=(%w+)")
        if directiveJson[k] then
           -- dLogJson(directiveJson[k], "matchJsonValue:")
            returnString = returnString..createDirective(directiveJson)
        else
            returnString = returnString.."?replace"..v
        end
     -- dLog(returnString, "returnString:  ")
    end
  end
  dLog(returnString, "returnString:  ")
  return returnString
end

function createDirective(directiveJson)
  local prefix = "?replace"
  for k,v in pairs(directiveJson) do
    prefix = string.format("%s;%s=%s",prefix,k,v)
  end
  return prefix
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

    if result.npcParams then
      self.currentIdentityOverrides = copy(result.npcParams)
      if not self.currentIdentityOverrides.identity then
        self.currentIdentityOverrides.identity = {}
      end
      if not self.currentIdentityOverrides.items then
        self.currentIdentityOverrides.items = {}
      end
    else
      self.currentIdentityOverrides = {identity = {}, items = {}}
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
    widget.setSelectedOption(self.categoryWidget, 1)
    widget.setVisible(self.categoryWidget, true)
    widget.setVisible(self.tabGroupWidget, true)
    widget.setVisible(self.scrollArea, true)
    --widget.setSelectedOption(self.tabGroupWidget, self.tabSelectedOption)
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
  npcLevel = self.currentLevel,
  npcParams = self.currentIdentityOverrides
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

  dLog(variant.humanoidIdentity.bodyDirectives, "bodyDirectives: ")
  dLog(self.currentIdentityOverrides.identity.bodyDirectives, "overrideBodyDirectives")

  dLog(variant.humanoidIdentity.hairDirectives, "hairDirectives: ")
  dLog(self.currentIdentityOverrides.identity.hairDirectives, "overrideeHairDirectives")
  dLog(variant.humanoidIdentity.emoteDirectives,"emoteDirectives: ")


  local npcPort = root.npcPortrait("full", args.curSpecies,args.curType, args.level, args.curSeed, self.currentIdentityOverrides)


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
  local gender = self.currentIdentity.gender
  local genderIndx = 1
  local returnInfo = {}
  local title = {}
  local imgPath = {}
  if not gender then dLog("getSpeciesOptions:  nil gender") end
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

  elseif option == "fhair" then
    local hairInfo = {}
    
    hairInfo.facialHairGroup = genderPath[genderIndx].facialHairGroup or "facialHairGroup"
    hairInfo.facialHair = genderPath[genderIndx].facialHair

    for _,v in ipairs(hairInfo.facialHair) do
      table.insert(title, v)
      table.insert(imgPath, string.format("/humanoid/%s/%s/%s.png",species,hairInfo.facialHairGroup,v))
    end
    returnInfo.title = title
    returnInfo.imgPath = imgPath
    returnInfo.facialHairGroup = hairInfo.facialHairGroup

    return returnInfo

  elseif option == "hcolor" then
    dLog("getSpeciesOptions:  endered hcolor")
    local hairColors = copy(speciesJson.hairColor)
    local curHairDirective = self.currentIdentityOverrides.identity.hairDirectives or self.currentIdentity.hairDirectives
    dLog(curHairDirective, "getSpeciesOptions:  curHairDirective ->")
    local newDirective = nil
    local hexDirectives = {}
    local firstRun = true
    
    for _,v in ipairs(hairColors) do
      local nameString  = ""
      if type(v) == "string" then
          return nil 
      end
      for _,vv in pairs(v) do
        if firstRun then 
          nameString = string.format("%s",vv)
          firstRun = false
        end
        nameString = string.format("%s,%s",nameString,vv)
      end
      newDirective = replaceDirectives(curHairDirective,v)
      --local hashString = util.hashString(completeDirective)

      hexDirectives[nameString] = newDirective
      table.insert(title,nameString)
      firstRun = true
    end
    returnInfo.title = title
    returnInfo.hexDirectives = hexDirectives
    returnInfo.curHairDirective = curHairDirective
    return returnInfo

  elseif option == "bcolor" then
      local colors = copy(speciesJson.bodyColor)
      local curDirective = self.currentIdentityOverrides.identity.bodyDirectives or self.currentIdentity.bodyDirectives
      
      returnInfo.colors = colors
      returnInfo.curDirective = curDirective
      
    return getColorInfo(returnInfo)
  else
    dLog("")
  end
end


function getColorInfo(args)
  args = parseArgs(args, {
    colors = nil,
    curDirective = nil,
    hexDirectives = {}
    })
    dLog(args.curDirective, "PARSED DIRECTIVE : ")
    dLog(self.currentIdentity.bodyDirectives, "CURRENT BCOLOR DIRECTIVE : ")
    local returnInfo = {}
    local newDirective = ""
    local firstRun = true
    local title = {}
    local indx = 1
    
    for _,v in ipairs(args.colors) do
      local nameString  = ""
            if type(v) == "string" then
                return nil 
            end
        for _,vv in pairs(v) do
              if firstRun then 
                nameString = string.format("%s",vv)
                firstRun = false
              end
              nameString = string.format("%s,%s",nameString,vv)
        indx = indx + 1
        --if indx > 3 then break end
        end
          
        newDirective = replaceDirectives(args.curDirective,v)
          
      --local hashString = util.hashString(completeDirective)

      args.hexDirectives[nameString] = newDirective
      table.insert(title,nameString)
      firstRun = true
    end
    returnInfo.title = title
    returnInfo.hexDirectives = copy(args.hexDirectives)
    returnInfo.curDirective = args.curDirective
    return returnInfo
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
  local listOption = widget.getSelectedOption(self.tabGroupWidget)
  dLog(listOption, "listOption: ")
  local args = {}
  if data == "tab1" then
    if self.categoryWidgetData == "Generate" then
      args.list = copy(self.speciesList)
      args.listType = "species"
      args.currentSelection = self.currentSpecies
      return setList(args)

    elseif self.categoryWidgetData == "Refine" then

      local data = getSpeciesOptions(self.currentSpecies, "hair")
      args = {list = data.title, 
              imgPath = data.imgPath, 
              hairGroup = data.hairGroup, 
              currentSelection = self.currentIdentityOverrides.identity.hairType,
              listType = "hair"}
      return setList(args)
    end
  end
  if data == "tab2" then
    if self.categoryWidgetData == "Generate" then
      args.list = copy(self.typeList)
      args.listType = "npcType"
      args.currentSelection = self.currentType
      return setList(args)

    elseif self.categoryWidgetData == "Refine" then

      local data = getSpeciesOptions(self.currentSpecies, "fhair")
      args = {list = data.title, 
              imgPath = data.imgPath,
              facialHairGroup = data.facialHairGroup,
              currentSelection = self.currentIdentityOverrides.identity.facialHairType,
              listType = "fhair"}
      return setList(args)
    end
  end
  if data == "tab3" then
    if self.categoryWidgetData == "Generate" then 
      return setList(nil)

    elseif self.categoryWidgetData == "Refine" then

      local data = getSpeciesOptions(self.currentSpecies, "hcolor")
      if data then 
        args = {list = data.title, 
                hexDirectives = data.hexDirectives,
                currentSelection = data.curHairDirective,
                listType = "hcolor"}
      else 
        args = {
                list = {""},
                listType = "hcolor"
        }
      end
        return setList(args)
    
    end
  end

  if data == "tab4" then
    if self.categoryWidgetData == "Generate" then
      return setList(nil)
    elseif self.categoryWidgetData == "Refine" then

      local data = getSpeciesOptions(self.currentSpecies, "bcolor")
      if data then 
        args = {list = data.title, 
                hexDirectives = data.hexDirectives,
                currentSelection = data.curDirective,
                listType = "bcolor"}
        return setList(args)
      end
    end
  end

  if data == "tab5" then
    if self.categoryWidgetData == "Generate" then
      return setList(nil)
    end
  end
  return setList(nil)
 -- dLog(args, "selectTab Failed - > args: ")
end


--args:
  --list
  --listType
function setList(args)
  dLogJson("setList - ARGS")
  --table.sort(args.list)
  widget.clearListItems(self.techList)
  if not args then return end
  local indx = 1
  if (self.categoryWidgetData ~= "Generate") then
    local defaultArgs = {
    listType = args.listType,
    clearConfig = true
    }

    local defaultListItem = widget.addListItem(self.techList)
      widget.setText(string.format("%s.%s.techName", self.techList, defaultListItem), "No Override")
      widget.setData(string.format("%s.%s", self.techList, defaultListItem), defaultArgs)
  end
  if #args.list < 2 then return end
  for _,v in pairs(args.list) do

      local listItem = widget.addListItem(self.techList)
      local newArgs = parseArgs(args, {
          name = v,
          listType = nil,
          hairGroup = nil,
          facialHairGroup = nil,
          directive = nil,
          clearConfig = false
        })
      if args.hexDirectives then
        newArgs.directive = args.hexDirectives[v]
        --args.hexDirectives = nil
      end


      --newArgs.name = v
      --newArgs.listType = args.listType
      --newArgs.hairGroup = args.hairGroup or nil
      --newArgs.facialHairGroup = arg.facialHairGroup or nil

      widget.setText(string.format("%s.%s.techName", self.techList, listItem), v)
      widget.setData(string.format("%s.%s", self.techList, listItem), newArgs)
      --if args.hexDirectives then
      --  indx = indx+1
      --  if newArgs.directive == args.currentSelection then
      --    widget.setListSelected(self.techList, listItem)
      --    break
      --  end
      --end
      if v == args.currentSelection then 
        indx = indx+1
        sb.logInfo("setList:  entered setListSelected")
        widget.setListSelected(self.techList, listItem)
      end
      
  end
end


function listItemSelected()
  local listItem = widget.getListSelected(self.techList)
  if not listItem then return end
  --sb.logInfo(string.format("%s.%s", self.techList, listItem))
  local listArgs = widget.getData(string.format("%s.%s", self.techList, listItem))
  dLogJson(listArgs, "listItemSelected : listArgs:")
  if not listArgs then return end

  if listArgs.listType == "species" then
    self.currentSpecies = tostring(listArgs.name)
  end

  if listArgs.listType == "npcType" then
    self.currentType = tostring(listArgs.name)
  end

  if listArgs.listType == "hair" then
    if listArgs.clearConfig then 
      self.currentIdentityOverrides.identity["hairType"] = nil
    else
      self.currentIdentityOverrides.identity.hairType = listArgs.name
    end
  end

  if listArgs.listType == "fhair" then
    if listArgs.clearConfig then 
      dLog("listArgs.fhair : clearConfig:  entered ClearConfig")
      --self.currentIdentityOverrides.identity["facialHairGroup"] = nil
      self.currentIdentityOverrides.identity["facialHairType"] = nil
    else
      --self.currentIdentityOverrides.identity.facialHairGroup = listArgs.facialHairGroup
      self.currentIdentityOverrides.identity.facialHairType = listArgs.name
    end
  end

  if listArgs.listType == "hcolor" then
    if listArgs.clearConfig then
      self.currentIdentityOverrides.identity["hairDirectives"] = nil
    else
      self.currentIdentityOverrides.identity.hairDirectives = listArgs.directive
    end
  end

  if listArgs.listType == "bcolor" then
    if listArgs.clearConfig then
      self.currentIdentityOverrides.identity["bodyDirectives"] = nil
      self.currentIdentityOverrides.identity["emoteDirectives"] = nil
    else
      self.currentIdentityOverrides.identity.bodyDirectives = listArgs.directive
      self.currentIdentityOverrides.identity.emoteDirectives = listArgs.directive
      dLog(listArgs.directive, "listArgDirective")
      dLog(self.currentIdentity.hairDirectives, "listingCurrentHairDirective")
      if listArgs.directive and (self.currentIdentity.hairDirectives ~= "") then
      local substring = string.match(self.currentIdentity.hairDirectives, "(%w+)=")
       if (string.find(listArgs.directive, substring, 1, true) ~= nil) then
         self.currentIdentityOverrides.identity.hairDirectives = listArgs.directive
       end
      end
    end
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

  local tabNames = {"lblTab01","lblTab02","lblTab03","lblTab04","lblTab05"}

  self.categoryWidgetData = data

  if data == "Generate" then
    changeTabLabels(tabNames, "Generate")
    widget.setVisible(self.scrollArea, true)
    widget.setSliderEnabled("sldTargetSize", true)
    self.currentIdentityOverrides.identity = {}
  elseif data == "Refine" then
    changeTabLabels(tabNames, "Refine")
    widget.setVisible(self.scrollArea, true)
    widget.setSliderEnabled("sldTargetSize", false)
  end
  dLog(data, "selectGenCategory - selectedOption:  ")
    local indx = widget.getSelectedOption(self.tabGroupWidget)
    local tabData = widget.getSelectedData(self.tabGroupWidget)
    if indx and tabData then
      return selectTab(indx, tabData)
    end
  
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