require "/scripts/util.lua"
require "/scripts/npcspawnutil.lua"

spnPersonality = {}
--itmTradeItem = {}
updateFunc = {}

function init()
  sb.logInfo("NpcPanelMenu: init")
  --self.gettingSpecies = nil
  --self.gettingSeedValue = nil
  --self.gettingType = nil
  --self.gettingPosition = nil
  self.gettingNpcData = nil
	--these variables store the results of the messages we send to the parent panel obj
 
	self.sendingSpecies = nil
	self.sendingSeedValue = nil
  self.sendingType = nil

  self.npcDataInit = false

  self.sendingData = nil

  self.currentSpecies = "human"
  self.currentSeed = 0
  self.currentType = "nakedvillager"

  self.currentIdentity = {}
  self.currentOverride = nil
  self.currentLevel = 10
	--self.sliderVal = 0

	self.speciesInitialized = false;
	self.seedValueInitialized = false;
  self.typeInitialized = false;
  self.positionInitialized = false

	self.raceButtons = {}

  self.seedInput = 0

  self.personalityIndex = 0

  --LIST VARS--
  self.scrollArea = "techScrollArea"
  self.techList = "techScrollArea.techList"

  self.tabData = nil
  self.tabSelectedOption = -1
  self.tabGroupWidget = "rgTabs"
  self.npcTypeConfigList = "npcTypeList"
  
  self.speciesList = root.assetJson("/interface/windowconfig/charcreation.config").speciesOrdering

  self.typeList = world.getObjectParameter(pane.containerEntityId(),self.npcTypeConfigList,{})

  --CATEGORY VARS--
  --`int` widget.getSelectedOption(`String` widgetName)
  ----Returns the index of the selected option in a ButtonGroupWidget.

  --`int` widget.getSelectedData(`String` widgetName)
  ----Returns the data of the selected option in a ButtonGroupWidget. Nil if no option is selected.

  self.categoryWidget = "sgSelectCategory"

  self.categoryWidgetData = "Generate"

  --OVERI
  --self.buttonDataOptions = world.getObjectParameter(pane.containerEntityId(),"rgNPCModOptions")
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

  self.updateIndx = 1



  widget.setSliderRange("sldTargetSize",0, self.worldSize)
  widget.setSliderEnabled("sldTargetSize", true)
  widget.setSliderValue("sldTargetSize",0)
  
  local currentRatio = self.currentSize / self.worldSize
  
  widget.setProgress("prgCurrentProgress", currentRatio)
  
  widget.setProgress("prgAvailable", 0.0)

  --testFunction()
   -- setList({list = self.speciesList,  listType = "species"})

  updateFunc[1] = function(args)
      dLog("Update :  FirstRun")
      self.firstRun = false
      self.gettingNpcData = world.sendEntityMessage(pane.containerEntityId(), "getNpcData")
      self.updateIndx = self.updateIndx + 1
    end

  updateFunc[2] = function(args)
    if not self.npcDataInit and self.gettingNpcData:finished() and self.gettingNpcData:result() then
      self.updateIndx = self.updateIndx + 1 
    end
  end  
  updateFunc[3] = function(args)
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

    if result.npcLevel then
      self.currentLevel = tonumber(result.npcLevel) or 10
    end

    if result.npcParams then
      self.currentOverride = parseArgs(result.npcParams, {
        identity = {},
        items = {}
        })
    end

    if type(result.npcSeed) == "string" then 
      self.currentSeed = result.npcSeed
      widget.setText("seedValue", self.seedInput)
    else
      self.manualInput = false
      self.currentSeed = result.npcSeed
      self.targetSize = result.npcSeed
      widget.setSliderValue("sldTargetSize", self.targetSize)
      widget.setText("seedValue", tostring(result.npcSeed))
    end
    widget.setSelectedOption(self.categoryWidget, -1)
    widget.setVisible(self.categoryWidget, true)
    widget.setVisible(self.tabGroupWidget, true)
    widget.setVisible(self.scrollArea, true)

    --setName
    if self.currentOverride.identity.name then
      widget.setText("tbNameBox", self.currentOverride.identity.name)
    end
    --widget.setSelectedOption(self.tabGroupWidget, self.tabSelectedOption)
    self.updateIndx = self.updateIndx + 1
    return updateNpc(getArgs())
  end
  updateFunc[4] = function(args)
    if self.npcDataInit then
      self.updateIndx = self.updateIndx + 1
    end
  end

  updateFunc[5] = function(args)
    if self.portraitNeedsUpdate then
      self.portraitNeedsUpdate = false
      return updateNpc(getArgs())
    end
  end
  
  
end

--function itmArmorGrid.right()
--dLog(type(itmArmorGrid), "itmArmorGrid: right ")
--end
--

function getArgs()
  local args = {
      curSpecies = self.currentSpecies,
      curSeed =  self.currentSeed,
      curType = self.currentType,
      curLevel = self.currentLevel,
      curId = self.currentIdentity, 
      curOverride = self.currentOverride
    }
  return args
end


function itemGrid(args)
  dLogJson(args,  "itemGrid -")
end

function containerCallback()
  dLog("npcPanel: ContainerCallback")
end

function containerPaneCallback()
  dLog("container has been called back!")

end
--function itmTradeItem.right(...)
--  dLog("itmTradeItem.right")
--end
--function itmTradeItem:right()
--  dLog("itmTradeItem2")
--end

function spnPersonality.up()
  dLog("spinner UP:  ")
  local personalities = getAsset("/humanoid.config:personalities")
  self.personalityIndex = util.wrap(self.personalityIndex + 1, 0, #personalities)
  setPersonality(self.personalityIndex)

end

function spnPersonality.down()
  dLog("spinner DOWN:  ")
  local personalities = getAsset("/humanoid.config:personalities")
  self.personalityIndex = util.wrap(self.personalityIndex - 1, 0, #personalities)
  setPersonality(self.personalityIndex)
end

function setPersonality(index)
  if index ~= 0 then
    widget.setText("lblPersonality", tostring(index))
    local personalities = getAsset("/humanoid.config:personalities")
    local personality = personalities[index]
    --assert(personality, string.format("cannot find personality, bad index?  :  %s", index))
    local identity = self.currentOverride.identity
    identity.personalityIdle = personality[1]
    identity.personalityHeadOffset = personality[3]
    identity.personalityArmIdle = personality[2]
    identity.personalityArmOffset = personality[4]
  else
    widget.setText("lblPersonality", "No Override")
    return clearPersonality()
  end
  self.portraitNeedsUpdate = true
end

function clearPersonality()
  if self.currentOverride.identity then
    local identity = self.currentOverride.identity
    identity.personalityIdle = nil
    identity.personalityHeadOffset = nil
    identity.personalityArmIdle = nil
    identity.personalityArmOffset = nil
    return updateNpc(getArgs())
  end

end


function replaceDirectives(directive, directiveJson)
  local returnString = ""

  if not directive then 
    return createDirective(directiveJson)
  end


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
        if directiveJson[k] or directiveJson[string.upper(k)] or directiveJson[string.lower(k)] then
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

  local parsedStrings = util.split(self.overrideText, " ")
  dLogJson(parsedStrings, "ParsedStrings:  ")
  
  parsedStrings = parseArgs(parsedStrings, {
    "nil",
    "nil",
    "nil",
    "nil"
    })
  if parsedStrings[1] == "hs" and parsedStrings[2] == "hair" then
    self.currentOverride.identity.hairDirectives = self.currentOverride.identity.hairDirectives or  self.currentIdentity.hairDirectives
    self.currentOverride.identity.hairDirectives = self.currentOverride.identity.hairDirectives.."?hueshift="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc(getArgs())
  end

  if parsedStrings[1] == "hs" and parsedStrings[2] == "body" then
    self.currentOverride.identity.bodyDirectives = self.currentOverride.identity.bodyDirectives or  self.currentIdentity.bodyDirectives
    self.currentOverride.identity.bodyDirectives = self.currentOverride.identity.bodyDirectives.."?hueshift="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc(getArgs())
  end

  if parsedStrings[1] == "hs" and parsedStrings[2] == "emote" then
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives or  self.currentIdentity.emoteDirectives
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives.."?hueshift="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc(getArgs())
  end

  if parsedStrings[1] == "sat" and parsedStrings[2] == "hair" then
    self.currentOverride.identity.hairDirectives = self.currentOverride.identity.hairDirectives or  self.currentIdentity.hairDirectives
    self.currentOverride.identity.hairDirectives = self.currentOverride.identity.hairDirectives.."?saturation="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc(getArgs())
  end

  if parsedStrings[1] == "sat" and parsedStrings[2] == "body" then
    self.currentOverride.identity.bodyDirectives = self.currentOverride.identity.bodyDirectives or  self.currentIdentity.bodyDirectives
    self.currentOverride.identity.bodyDirectives = self.currentOverride.identity.bodyDirectives.."?saturation="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc(getArgs())
  end

  if parsedStrings[1] == "sat" and parsedStrings[2] == "emote" then
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives or  self.currentIdentity.emoteDirectives
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives.."?saturation="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc(getArgs())
  end

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
 
  return updateNpc(getArgs())
end

function parseOverride(txt, pattern)
  local parsedStrings = {}

  for str in string.gmatch(txt, pattern) do
    if str ~= "" then
      table.insert(parsedStrings, str)
    end
  end

  return parsedStrings

end

function setNpcName()
  local text = widget.getText("tbNameBox")
  if text == "" then
    --get seed name
    newText = self.currentIdentity.name
    if self.currentOverride.identity.name then
      self.currentOverride.identity.name = nil
    end
  else
    self.currentOverride.identity.name = text
  end
end

function update(dt)
  --Cannot send entity messages during init, so will do it here
 
  updateFunc[self.updateIndx](dt)

  --initializing the seed value from the panel object

  --main loop after everyting has been loaded in
  
     --updateGUI()
  
end

--function seedValue() 
--  if self.typeInitialized and self.speciesInitialized and self.seedValueInitialized then 
--    self.manualInput = true
--    self.seedInput = widget.getText("seedValue")
--    sb.logWarn("typedKey?")
--     self.portraitNeedsUpdate = true
--  end
--end

function clampSize(newSize)
  return math.min(math.min(math.max(math.max(newSize, self.minTargetSize), self.currentSize), self.currentSize + self.maxStepSize), self.worldSize)
end

function updateTargetSize()
  self.currentOverride.identity = {}
  self.manualInput = false
  self.targetSize = widget.getSliderValue("sldTargetSize")
  self.currentSeed = self.targetSize
  --self.targetSize = clampSize(widget.getSliderValue("sldTargetSize"))
  --widget.setSliderValue("sldTargetSize", self.targetSize)
  widget.setText("lblSliderAmount", tostring(self.targetSize))
  --sb.logWarn("updateTargetSize?")
  
  return updateNpc(getArgs())

end

function acceptBtn()
  local args = {
    npcSpecies = self.currentSpecies,
    npcSeed = self.currentSeed,
    npcType = self.currentType,
    npcLevel = self.currentLevel,
    npcParam = self.currentOverride
  }
    --self.sendingSeedValue = world.sendEntityMessage(pane.sourceEntity(), "setSeedValuePanel", self.targetSize)
    self.sendingData = world.sendEntityMessage(pane.containerEntityId(), "setNpcData", args)
end


function replaceItemOverrides(args)
  args = parseArgs(args, {
    head = nil,
    chest = "hikerchest",
    legs = "hikerlegs",
    back = nil
  })
  local params = world.getObjectParameter(pane.containerEntityId(),"itemOverrideTemplate")
  local item = world.getObjectParameter(pane.containerEntityId(),"itemTemplate").item[1]
  dLogJson(params, "Params: ")
  local insertPosition = params.items.override[1][2][1]
  --debug--
  insertPosition.chest = world.getObjectParameter(pane.containerEntityId(),"itemTemplate").item
  insertPosition.chest[1].name = args.chest
  insertPosition.legs = world.getObjectParameter(pane.containerEntityId(),"itemTemplate").item
  insertPosition.legs[1].name = args.legs
  dLogJson(params, "replaceItemOverrides: Params: ")
  return params
end

function updateNpc(args)

  local variant = root.npcVariant(args.curSpecies,args.curType, args.curLevel, args.curSeed)
  self.currentIdentity = copy(variant.humanoidIdentity)

  if self.currentOverride.identity.name then
    widget.setText("tbNameBox", self.currentOverride.identity.name)
  else
    widget.setText("tbNameBox", self.currentIdentity.name)
  end

  self.currentIdentity.underwear = getDirectiveAtEnd(variant.humanoidIdentity.bodyDirectives)

  variant = root.npcVariant(args.curSpecies,args.curType, args.curLevel, args.curSeed, self.currentOverride)
  --dLogJson(variant, "variantCONFIG:  ")
  
  dCompare("bodyDirectives - curIden/override", self.currentIdentity.bodyDirectives, variant.humanoidIdentity.bodyDirectives)
  dCompare("hairDirectives - curIden/override", self.currentIdentity.hairDirectives, variant.humanoidIdentity.hairDirectives)
  dCompare("emoteDirectives - curIden/override", self.currentIdentity.emoteDirectives, variant.humanoidIdentity.emoteDirectives)


  local npcPort = root.npcPortrait("full", args.curSpecies,args.curType, args.curLevel, args.curSeed, args.curOverride)

  return setPortrait(npcPort)
end

function setPortrait(npcPort)

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
    "portraitSlot15",
    "portraitSlot16",
    "portraitSlot17",
    "portraitSlot18",
    "portraitSlot19",
    "portraitSlot20"
  }


  local num = 1

  while num <= #npcPort do
    widget.setImage(names[num], npcPort[num].image)
    widget.setVisible(names[num], true)
    num = num+1
  end

  while num <= #names do
    widget.setVisible(names[num], false)
    num = num+1
  end

end



-------TEST FUNCTIONS-----------
--not useful in any way, used to test things

function testFunction()
    local config = root.npcConfig("villager")
    dLogJson(config, "config:")
end


--callback when tab is selected--
--args:
  --button : ? (widget.getSelectedOption?)
  --indx buttonlabel.data (widget.getSelectedData)

function tabListOne(button, data)
  local args = {}
  if data == "tab1" then
    args.list = copy(self.speciesList)
    args.listType = "species"
    args.currentSelection = self.currentSpecies
    return setList(args)
  elseif data == "tab2" then
    args.list = copy(self.typeList)
    args.listType = "npcType"
    args.currentSelection = self.currentType
    return setList(args)
  else
    return setList(nil)
  end
end

function tabListTwo(button,data)
  local args = {}
  local tabInfo = {}
  tabInfo["tab1"] = getSpeciesOptions(self.currentSpecies, "Hair", {curDirective = self.currentOverride.identity.hairType})
  tabInfo["tab2"] = getSpeciesOptions(self.currentSpecies, "FHair", {curDirective = self.currentOverride.identity.hairType})
  tabInfo["tab3"] = getSpeciesOptions(self.currentSpecies, "HColor", {curDirective = self.currentOverride.identity.hairDirectives or self.currentIdentity.hairDirectives})
  tabInfo["tab4"] = nil
  tabInfo["tab5"] = getSpeciesOptions(self.currentSpecies, "BColor", {curDirective = self.currentOverride.identity.bodyDirectives or self.currentIdentity.bodyDirectives })
  tabInfo["tab6"] = getSpeciesOptions(self.currentSpecies, "UColor", {curDirective = self.currentOverride.underwear or self.currentIdentity.underwear})

  local info = tabInfo[data]
    if info then
      args = {list = info.title, 
              imgPath = info.imgPath, 
              hairGroup = info.hairGroup, 
              facialHairGroup = info.facialHairGroup,
              hexDirectives = info.hexDirectives,
              currentSelection = info.curDirective,
              listType = info.option}
    else
      args = {
              list = {""},
              listType = data
      }
    end
    return setList(args)
end

function selectTab(button, data)
  local listOption = widget.getSelectedOption(self.tabGroupWidget)
  local category = {}

  category["Generate"] = tabListOne
  category["Refine"] = tabListTwo
  category["Equip"] = ""
  return category[self.categoryWidgetData](button, data)
 -- dLog(args, "selectTab Failed - > args: ")
end


function getSpeciesOptions(species, option, returnInfo)
  returnInfo = returnInfo or {}
  returnInfo.option = option
  local speciesJson = getAsset("/species/"..species..".species") or nil

  if not speciesJson then dLog("getSpeciesOptions:  nil AssetFile") end

    --dLogJson(speciesJson, "speciesJSON: ")
  local genderPath = speciesJson.genders
  local gender = self.currentOverride.identity.gender or self.currentIdentity.gender
  local genderIndx = 1

  if not gender then 
    dLog("getSpeciesOptions:  nil gender") 
  end

  if genderPath[1]["name"] == gender then
    genderIndx = 1
  else
    genderIndx = 2
  end

  local title = {}
  local imgPath = {}
  local colorGenParams = {}
  if speciesJson["headOptionAsFacialhair"] then
    if speciesJson["headOptionAsFacialhair"] == true then
      returnInfo["headOptionAsFacialhair"] = speciesJson["headOptionAsFacialhair"]
    end
  end

  if speciesJson["altColorAsFacialMaskSubColor"] then
    if speciesJson["altColorAsFacialMaskSubColor"] == true then
      returnInfo["altColorAsFacialMaskSubColor"] = speciesJson["altColorAsFacialMaskSubColor"]
    end
  end

  if speciesJson["bodyColorAsFacialMaskSubColor"] then
    if speciesJson["bodyColorAsFacialMaskSubColor"] == true then
      returnInfo["bodyColorAsFacialMaskSubColor"] = speciesJson["bodyColorAsFacialMaskSubColor"]
    end
  end

  
  if option == "HColor" then
      returnInfo.colors = copy(speciesJson.hairColor)
      return getColorInfo(returnInfo)
  elseif option == "FHcolor" then
      return getColorInfo(returnInfo)
  elseif option == "BColor" then
      returnInfo.colors = copy(speciesJson.bodyColor)
    return getColorInfo(returnInfo)
  elseif option == "UColor" then
      returnInfo.colors = copy(speciesJson.undyColor)
    return getColorInfo(returnInfo)
  else
    return getSpeciesAsset(speciesJson, genderIndx, species, option, returnInfo) 
  end
end


function getSpeciesAsset(speciesJson, genderIndx, species, option, output)
  local optn = world.getObjectParameter(pane.containerEntityId(),"getAssetParams")[option]

  local genderPath = speciesJson.genders[genderIndx]
  local title = {}
  local imgPath = {}
  local info = {}
  local oOne = tostring(optn[1])
  local oTwo = tostring(optn[2])
  dCompare("oOne - oTwo", oOne, oTwo)

 
  info[oOne] = genderPath[oOne] or optn[3]
  info[oTwo] = genderPath[oTwo]

  for _,v in ipairs(info[oTwo]) do
    table.insert(title, v)
    table.insert(imgPath, string.format("/humanoid/%s/%s/%s.png",species,info[oOne],v))
  end
  output.title = title
  output.imgPath = imgPath
  output.hairGroup = info[oOne]
  return output
end


function getColorInfo(args)
  args = parseArgs(args, {
    colors = nil,
    curDirective = nil,
    hexDirectives = {}
    })

    local returnInfo = {}
    local newDirective = ""
    local firstRun = true
    local title = {}
    local indx = 1
    if args.colors then
      for _,v in ipairs(args.colors) do
        local nameString  = ""
              if type(v) == "string" then
                  return nil 
              end
          nameString = string.format("%s",indx)
          indx = indx + 1
          newDirective = replaceDirectives(args.curDirective,v)
            
        --local hashString = util.hashString(completeDirective)

        args.hexDirectives[nameString] = newDirective
        table.insert(title,nameString)
        firstRun = true
      end
      args.title = title
    end
    return args
end

function getAsset(assetPath)
  local asset = root.assetJson(assetPath)
  return asset
end
-------LIST FUNCTIONS-----------



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
  if not args.list then return end
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
        newArgs.directive = args.hexDirectives[v] or " "
        --args.hexDirectives = nil
        local hexId = string.match(newArgs.directive, "=(%w+)")
        if hexId then
          v = "^#"..hexId..";"..v
        end
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
      if newArgs.name == args.currentSelection then 
        indx = indx+1
        sb.logInfo("setList:  entered setListSelected")
        widget.setListSelected(self.techList, listItem)
      end
      
  end
end


function listItemSelected()
  local listItem = widget.getListSelected(self.techList)
  if not listItem then return end

  local listArgs = widget.getData(string.format("%s.%s", self.techList, listItem))

  if not listArgs then return end

  if listArgs.listType == "species" then
    self.currentSpecies = tostring(listArgs.name)
  end

  if listArgs.listType == "npcType" then
    self.currentType = tostring(listArgs.name)
  end

  if listArgs.listType == "Hair" then
    if listArgs.clearConfig then 
      self.currentOverride.identity["hairType"] = nil
    else
      self.currentOverride.identity.hairType = listArgs.name
    end
  end

  if listArgs.listType == "FHair" then
    if listArgs.clearConfig then 
      dLog("listArgs.fhair : clearConfig:  entered ClearConfig")
      --self.currentOverride.identity["facialHairGroup"] = nil
      self.currentOverride.identity["facialHairType"] = nil
    else
      --self.currentOverride.identity.facialHairGroup = listArgs.facialHairGroup
      self.currentOverride.identity.facialHairType = listArgs.name
    end
  end

  if listArgs.listType == "HColor" then
    if listArgs.clearConfig then
      self.currentOverride.identity["hairDirectives"] = nil
    else
      self.currentOverride.identity.hairDirectives = listArgs.directive
    end
  end

  if listArgs.listType == "FHcolor" then
    if listArgs.clearConfig then

      self.currentOverride.identity["facialHairDirectives"] = nil
    else
      if self.currentIdentity.facialHairDirectives ~= "" then
        self.currentOverride.identity.facialHairDirectives = listArgs.directive
      end
    end
  end


  if listArgs.listType == "BColor" then
    if listArgs.clearConfig then
      self.currentOverride.identity["bodyDirectives"] = nil
      self.currentOverride.identity["emoteDirectives"] = nil
    else
      self.currentOverride.identity.bodyDirectives = listArgs.directive
      self.currentOverride.identity.emoteDirectives = listArgs.directive
      dLog(listArgs.directive, "listArgDirective")
      dLog(self.currentIdentity.hairDirectives, "listingCurrentHairDirective")
      if listArgs.directive and (self.currentIdentity.hairDirectives ~= "") then
        local substring = string.match(self.currentIdentity.hairDirectives, "(%w+)=")
        if (string.find(listArgs.directive, substring, 1, true) ~= nil) then
          self.currentOverride.identity.hairDirectives = listArgs.directive
        end
        if self.currentIdentity.facialHairDirectives then
          substring = string.match(self.currentIdentity.facialHairDirectives, "(%w+)=")
          if listArgs.directive and substring then
            if (string.find(listArgs.directive, substring, 1, true) ~= nil) then
             self.currentOverride.identity.facialHairDirectives = listArgs.directive
            end
          end
        end
      end
    end
  end

  if listArgs.listType == "UColor" then
    
    if listArgs.clearConfig then
      self.currentOverride.identity.bodyDirectives = replaceDirectiveAtEnd(self.currentOverride.identity.bodyDirectives, self.currentIdentity.underwear)
      self.currentOverride.identity.hairDirectives = replaceDirectiveAtEnd(self.currentOverride.identity.hairDirectives, self.currentIdentity.underwear)  
      self.currentOverride.identity.emoteDirectives = replaceDirectiveAtEnd(self.currentOverride.identity.emoteDirectives, self.currentIdentity.underwear)
      --self.currentOverride.identity.hairDirectives = replaceDirectiveAtEnd(self.currentOverride.identity.hairDirectives, self.currentIdentity.underwear)

    else
      if self.currentOverride.identity.bodyDirectives then
        self.currentOverride.identity.bodyDirectives = replaceDirectiveAtEnd(self.currentOverride.identity.bodyDirectives, listArgs.directive)
      else
        self.currentOverride.identity.bodyDirectives = replaceDirectiveAtEnd(self.currentIdentity.bodyDirectives, listArgs.directive)
      end
      if self.currentOverride.identity.hairDirectives then
        self.currentOverride.identity.hairDirectives = replaceDirectiveAtEnd(self.currentOverride.identity.hairDirectives, listArgs.directive)
      else
        self.currentOverride.identity.hairDirectives = replaceDirectiveAtEnd(self.currentIdentity.hairDirectives, listArgs.directive)  
      end

      if self.currentOverride.identity.emoteDirectives then
        self.currentOverride.identity.emoteDirectives = replaceDirectiveAtEnd(self.currentOverride.identity.emoteDirectives, listArgs.directive)
      else
        self.currentOverride.identity.emoteDirectives = replaceDirectiveAtEnd(self.currentIdentity.emoteDirectives, listArgs.directive)  
      end
    end

  end

  self.manualInput = false
  self.portraitNeedsUpdate = true
end

-------END LIST FUNCTIONS---------
function replaceDirectiveAtEnd(directiveBase, directiveReplace)
  directiveBase = directiveBase or ""
  directiveReplace = directiveReplace or ""

  local split = util.split(directiveBase, "?replace")
  if #split < 3 then return directiveBase end
  if not string.match(directiveReplace, "?replace") then directiveReplace = "?replace"..directiveReplace end
  return "?replace"..split[2]..directiveReplace

end

function getDirectiveAtEnd(directiveBase)
  assert(directiveBase, "getDirectiveAtEnd:  givenDirective is null")
  local returnValue = ""
  local split = util.split(directiveBase, "?replace")
  local indx = #split
  if #split < 3 then return nil end
  while indx > 2 do
    if split[indx] ~= ""  and string.find(split[indx], "=") then
      break
    end
    indx = indx - 1
  end 

  return split[indx]
end

-------CATEGORY FUNCTIONS--------

function changeTabLabels(tabs, option)
  tabs = tabs or "nil"
  option = option or "nil"

  local tabOptions = world.getObjectParameter(pane.containerEntityId(),"tabOptions")[option]
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
  local  dataList = world.getObjectParameter(pane.containerEntityId(),"rgNPCModOptions")

  local tabNames = {"lblTab01","lblTab02","lblTab03","lblTab04","lblTab05","lblTab06"}

  self.categoryWidgetData = data

  if data == "Generate" then
    changeTabLabels(tabNames, "Generate")
    widget.setVisible(self.scrollArea, true)
    widget.setSliderEnabled("sldTargetSize", true)
    widget.setVisible("lblBlockNameBox", true)
    widget.setVisible("spnPersonality", false)
    widget.setVisible("lblPersonality", false)
  elseif data == "Refine" then
    changeTabLabels(tabNames, "Refine")
    widget.setVisible(self.scrollArea, true)
    widget.setSliderEnabled("sldTargetSize", false)
    widget.setVisible("lblBlockNameBox", false)
    widget.setVisible("spnPersonality", true)
    widget.setVisible("lblPersonality", true)
  elseif data == "IO" then
    widget.setSliderEnabled("sldTargetSize", false)
    widget.setVisible("lblBlockNameBox", false)
    widget.setVisible("spnPersonality", false)
    widget.setVisible("lblPersonality", false)
  end
  dLog(data, "selectGenCategory - selectedOption:  ")
  local indx = widget.getSelectedOption(self.tabGroupWidget)
  local tabData = widget.getSelectedData(self.tabGroupWidget)
  if indx and tabData then
    return selectTab(indx, tabData)
  end

end

-------END CATEGORY FUNCTIONS---------

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