require "/scripts/util.lua"
require "/scripts/npcspawnutil.lua"

spnIdleStance = {}
modNpc = {}
selectedTab = {}

function init()
  self.config = getUserConfig("npcSpawnerPlus")
  self.returnInfo = {}
  sb.logInfo("NpcPanelMenu: init")
  self.portraits = {
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
  self.npcTypeList = world.getObjectParameter(pane.containerEntityId(),"npcTypeList")
  self.gettingNpcData = nil
  self.sendingData = nil

  self.currentSpecies = "penguin"
  self.currentSeed = 0
  self.currentType = "nakedvillager"
  self.currentIdentity = {}
  self.currentOverride = {identity = {}, initialStorage = {}, scriptConfig = {}}
  self.currentLevel = 10

  self.raceButtons = {}

  self.personalityIndex = 0

  self.returnInfoColors = {}

  --LIST VARS--
  self.scrollArea = "techScrollArea"
  self.techList = "techScrollArea.techList"
  self.infoList = "techScrollArea.infoList"

  self.tabData = nil
  self.tabGroupWidget = "rgTabs"
  self.categoryWidget = "sgSelectCategory"
  self.categoryWidgetData = "Generate"
  ------------
  ---OVERRIDE VARS----
  self.manualInput = false
  self.overrideTextBox = "tbOverrideBox"
  self.overrideText = ""


  self.worldSize = 20000
  self.currentSize = 0
  self.targetSize = 0
  self.minTargetSize = 0
  self.targetSizeIncrement = 1

  self.maxStepSize = self.worldSize
  -- updateGUI()
  self.portraitNeedsUpdate = false
  --logReport(testTwo)

  self.doingMainUpdate = false
  self.firstRun = true
  self.itemData = nil

  widget.setSliderRange("sldTargetSize",0, self.worldSize)
  widget.setSliderEnabled("sldTargetSize", true)
  widget.setSliderValue("sldTargetSize",self.targetSize)
  local currentRatio = self.currentSize / self.worldSize

  self.itemsToAdd = {}

  self.equipSlot = {
                    "primary",
                    "secondary",
                    "sheathedprimary",
                    "sheathedsecondary",
                    "head",
                    "headCosmetic",
                    "chest",
                    "chestCosmetic",
                    "legs",
                    "legsCosmetic",
                    "back",
                    "backCosmetic"
                  }
                  --primary and sheathed primary are always the goto weapons, secondary is for shields.
                  --duel wielding weapons for npcs just doesnt seem to work.
  self.equipBagStorage = widget.itemGridItems("itemGrid")
end

--uninit WORKS. Question is, can we send entity messages without worrying about memory leaks?
function uninit()
  dLog("TESTING UNINIT")
end

function update(dt)
  --Cannot send entity messages during init, so will do it here
  if self.doingMainUpdate then
    local needsUpdate = false
    local itemBag = widget.itemGridItems("itemGrid")

    for i = 1, 12 do
      if not compare(self.equipBagStorage[i], itemBag[i]) then
        if not self.currentOverride.items  then 
          self.currentOverride.items = config.getParameter("overrideContainerTemplate.items") 
        end
        --Add items to override item slot so they update visually.
        local insertPosition = self.currentOverride.items.override[1][2][1]
        setItemOverride(self.equipSlot[i],insertPosition,itemBag[i])

        --Also add them to bmain's initialStorage config parameter so its baked into the npc during reloads
        if (not path(self.currentOverride,"scriptConfig","initialStorage","itemSlots")) then 
          setPath(self.currentOverride,"scriptConfig","initialStorage","itemSlots",{}) 
        end
        self.currentOverride.scriptConfig.initialStorage.itemSlots[self.equipSlot[i]] = itemBag[i]  
        needsUpdate = true
      end
    end

    local curO = self.currentOverride

    if path(curO,"items","override",1,2,1) then

      if isEmpty(curO.items.override[1][2][1]) then
        curO.items = nil
        needsUpdate = true
      end
    end     
    if needsUpdate then 
      self.equipBagStorage = widget.itemGridItems("itemGrid")
      updateNpc() 
    end
  elseif self.firstRun then
    self.speciesList = root.assetJson("/interface/windowconfig/charcreation.config:speciesOrdering")
    self.gettingNpcData = world.sendEntityMessage(pane.containerEntityId(), "getNpcData")
    appendToListIfUnique(self.speciesList, self.config.additionalSpecies)
    appendToListIfUnique(self.npcTypeList, self.config.additionalNpcTypes)
    table.sort(self.speciesList)
    local protectorate = root.npcConfig("villager")
    local graduation = protectorate.scriptConfig.questGenerator.graduation
    local listOfProtectorates = {}
    if graduation and graduation.nextNpcType then
      for _,v in ipairs(graduation.nextNpcType) do
        local name = v[2]
        table.insert(listOfProtectorates, tostring(name))
      end
    end
    appendToListIfUnique(self.npcTypeList, listOfProtectorates)


    self.firstRun = false
  else
      if self.gettingNpcData:finished() then 
        getParamsFromSpawner()
        script.setUpdateDelta(30)
      end
  end
end

function setItemOverride(slotName, insertPosition, itemContainer)
      if itemContainer then 
        local slotContainer = config.getParameter("itemContainerTemplate.item[1]")
        itemContainer.count = nil
        insertPosition[slotName] = {itemContainer}
      else
        insertPosition[slotName] = nil
      end
      --dLog(insertPosition, "insert pos ")
end


-----CALLBACK FUNCTIONS-------
function spnIdleStance.up()
  dLog("spinner UP:  ")
  local personalities = root.assetJson("/humanoid.config:personalities")
  self.personalityIndex = util.wrap(self.personalityIndex + 1, 0, #personalities)
  setIdleStance(self.personalityIndex)
  updateNpc()
  return 
end

function spnIdleStance.down()
  dLog("spinner DOWN:  ")
  local personalities = root.assetJson("/humanoid.config:personalities")
  self.personalityIndex = util.wrap(self.personalityIndex - 1, 0, #personalities)
  setIdleStance(self.personalityIndex)
  updateNpc()
  return 
end


--callback
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

  if parsedStrings[1] == "hue" and parsedStrings[2] == "hair" then
    self.currentOverride.identity.hairDirectives = self.currentOverride.identity.hairDirectives or  self.currentIdentity.hairDirectives
    self.currentOverride.identity.hairDirectives = self.currentOverride.identity.hairDirectives.."?hueshift="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
  end

  if parsedStrings[1] == "hue" and parsedStrings[2] == "body" then
    self.currentOverride.identity.bodyDirectives = self.currentOverride.identity.bodyDirectives or  self.currentIdentity.bodyDirectives
    self.currentOverride.identity.bodyDirectives = self.currentOverride.identity.bodyDirectives.."?hueshift="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
  end

  if parsedStrings[1] == "hue" and parsedStrings[2] == "emote" then
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives or  self.currentIdentity.emoteDirectives
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives.."?hueshift="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
  end

  if parsedStrings[1] == "sat" and parsedStrings[2] == "hair" then
    self.currentOverride.identity.hairDirectives = self.currentOverride.identity.hairDirectives or  self.currentIdentity.hairDirectives
    self.currentOverride.identity.hairDirectives = self.currentOverride.identity.hairDirectives.."?saturation="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
  end

  if parsedStrings[1] == "sat" and parsedStrings[2] == "body" then
    self.currentOverride.identity.bodyDirectives = self.currentOverride.identity.bodyDirectives or  self.currentIdentity.bodyDirectives
    self.currentOverride.identity.bodyDirectives = self.currentOverride.identity.bodyDirectives.."?saturation="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
  end

  if parsedStrings[1] == "sat" and parsedStrings[2] == "emote" then
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives or  self.currentIdentity.emoteDirectives
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives.."?saturation="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
  end

  if parsedStrings[1] == "sat" and parsedStrings[2] == "emote" then
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives or  self.currentIdentity.emoteDirectives
    self.currentOverride.identity.emoteDirectives = self.currentOverride.identity.emoteDirectives.."?saturation="..parsedStrings[3]
    widget.setText(self.overrideTextBox, parsedStrings[1].." "..parsedStrings[2].." ")
    return updateNpc()
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
    self.currentSeed = parsedStrings[4]
  end

  self.manualInput = true
 
  return updateNpc()
end

--Callback
function setNpcName()
  local text = widget.getText("tbNameBox")
  if text == "" then
    --get seed name
    local newText = self.currentIdentity.name
    if self.currentOverride.identity.name then
      self.currentOverride.identity.name = newText
    end
    widget.setText("tbNameBox", newText)
  else
    self.currentOverride.identity.name = text
  end
end

--Callback
function updateTargetSize()
  self.currentOverride.identity = {}
  self.manualInput = false
  self.targetSize = widget.getSliderValue("sldTargetSize")
  self.currentSeed = self.targetSize
  widget.setText("lblSliderAmount", "Seed:  "..tostring(self.targetSize))
  updateNpc()
end

function acceptBtn()
  self.currentOverride.identity = parseArgs(self.currentOverride.identity, copy(self.currentIdentity))
  setNpcName()
  local args = {
    npcSpecies = self.currentSpecies,
    npcSeed = self.currentSeed,
    npcType = self.currentType,
    npcLevel = self.currentLevel,
    npcParam = self.currentOverride
  }
  --90% of the crew uniform gets overwritten, but it allows you to use custom weapons!  
  --You can pair this with other mods that handle equiping armor
    --args.npcParam.disableWornArmor = false
    --dLogJson(args,"SENT IDENTITY", true)
    --self.sendingSeedValue = world.sendEntityMessage(pane.sourceEntity(), "setSeedValuePanel", self.targetSize)
    world.sendEntityMessage(pane.containerEntityId(), "setNpcData", args)
end

function setListInfo(categoryName, uniqueId)
  widget.clearListItems(self.infoList)
  dLog(categoryName, "catName")
  if not categoryName then return end
  local tabInfo = config.getParameter("tabOptions."..categoryName)
  local info = config.getParameter("infoDescription")
  local subInfo = info[categoryName]
  --dLogJson(subInfo, "subInfo")
  if uniqueId then 
    for i,v in ipairs(subInfo) do
      if v.key == "uniqueID" then 
        info[categoryName][i].value = uniqueId
        break
      end
    end
  end
  subInfo = info[categoryName]
  for _,v in ipairs(subInfo) do
    local listItem = widget.addListItem(self.infoList)
    for k,ve in pairs(v) do
      widget.setText(string.format("%s.%s.%s", self.infoList, listItem, k), ve)
    end
  end
  dLog(tabInfo, "TAB INFO:  ")
  for i,v in ipairs(tabInfo) do
    local tabDesc = info[v]
    if type(tabDesc) == "string" and tabDesc ~= "" then
      local listItem = widget.addListItem(self.infoList)
      widget.setText(string.format("%s.%s.%s",self.infoList, listItem,"key"), v)
      widget.setText(string.format("%s.%s.%s",self.infoList, listItem,"value"), tabDesc)
    elseif type(tabDesc) == "table" then
      for k,v in pairs(tabDesc) do
        widget.setText(string.format("%s.%s.%s",self.infoList, listItem,k), v)
      end
    end
  end
end

function selectTab(index, option)
  dLog(option,  "    SelectTab") 
  self.returnInfo = {}
  self.returnInfoColors = nil
  local listOption = widget.getSelectedOption(self.tabGroupWidget)

  local curTabs = config.getParameter("tabOptions."..self.categoryWidgetData)
  local listType = curTabs[index+2]
  
  if not listType or listType == "" then 
    return setList(nil) 
  end

  if not(self.speciesJson and (self.speciesJson.kind == self.currentSpecies)) then
    self.speciesJson = root.assetJson("/species/"..self.currentSpecies..".species")
  end
  selectedTab[listType](self.returnInfo)
  local returnInfo = self.returnInfo
  if returnInfo.useInfoList then
    setList(nil)
    widget.setVisible(self.techList, false)
    widget.setVisible(self.infoList, true)
    setListInfo(returnInfo.selectedCategory, self.uniqueExportId)
    self.uniqueExportId = nil
  else
    setListInfo(nil)
    widget.setVisible(self.techList, true)
    widget.setVisible(self.infoList, false)
  end
  
  
  if returnInfo.skipTheRest then return end
  dLog("contining getting tab info")
  returnInfo.listType = listType
  local genderPath = self.speciesJson.genders
  returnInfo.species = self.currentSpecies

  if returnInfo.colors then
    getColorInfo(self.returnInfoColors, returnInfo)
  else
    local optn  = config.getParameter("assetParams."..listType)
    if optn then
      getSpeciesAsset(self.speciesJson, getGenderIndx(self.currentIdentity.gender), self.currentSpecies, optn, returnInfo)
    end
  end
  returnInfo.colors = self.returnInfoColors
  setList(returnInfo)
end

function selectGenCategory(button, data)
  dLog("selectGenCategory")
  self.categoryWidgetData = data
  local tabNames = {"lblTab01","lblTab02","lblTab03","lblTab04","lblTab05","lblTab06"}
  local indx = widget.getSelectedOption(self.tabGroupWidget)
  local tabData = widget.getSelectedData(self.tabGroupWidget)
  if data == "Generate" then
    widget.setVisible(self.scrollArea, true)
    widget.setSliderEnabled("sldTargetSize", true)
    --widget.setVisible("lblBlockNameBox", false)
    widget.setVisible("spnPersonality", false)
    widget.setVisible("lblPersonality", false)
  elseif data == "Colorize" then
    widget.setVisible(self.scrollArea, true)
    --widget.setSliderEnabled("sldTargetSize", false)
    --widget.setVisible("lblBlockNameBox", false)
    widget.setVisible("spnPersonality", true)
    widget.setVisible("lblPersonality", true)
  elseif data == "Advanced" then
    widget.setSliderEnabled("sldTargetSize", false)
    widget.setVisible("lblBlockNameBox", false)
    widget.setVisible("spnPersonality", false)
    widget.setVisible("lblPersonality", false)
  end
  changeTabLabels(tabNames, data)
  dLog(data, "selectGenCategory - selectedOption:  ")
  if indx and tabData then
    selectTab(indx, tabData)
    return 
  end
end

--args:
  --list
  --listType
function setList(args)
  --dLogJson(args, "setList - ARGS")
  --table.sort(args.list)
  widget.clearListItems(self.techList)
  local indx = 1
  local displayText = nil
  local iTitle = nil
  local iData = nil
  if not args then dLog("no args found") return end

  
  widget.setData(string.format("%s", self.techList), args)

  if (args.isOverride) and (args.currentSelection ~= "") then
    args.clearConfig = true
    local defaultListItem = widget.addListItem(self.techList)
      widget.setText(string.format("%s.%s.techName", self.techList, defaultListItem), "Remove Overrides")
      widget.setData(string.format("%s.%s", self.techList, defaultListItem), {listType = tostring(args.listType), clearConfig = true})
  end 
  for i,v in pairs(args.title) do
      --dLog({i,v}, "HIT PAIR")
      local listItem = widget.addListItem(self.techList)
      if args.colors then
        displayText = tostring(indx)
        iTitle = tostring(indx)
        iData = args.colors[indx]
        local _,hexId = next(iData)
        if hexId then
          displayText = "^#"..hexId..";"..displayText
        end
      else
        displayText = tostring(v) 
        iTitle = tostring(v)
        if args.iData then
          iData = args.iData[i] or v
        else
          iData = v
        end
        if iIcon then
          widget.setImage(string.format("%s.%s.techIcon", self.techList, listItem), iIcon)
        end
      end

      widget.setText(string.format("%s.%s.techName", self.techList, listItem), displayText)
      widget.setData(string.format("%s.%s", self.techList, listItem), {itemTitle=iTitle , itemData = iData})

      if v == args.currentSelection then 
        sb.logInfo("setList:  entered setListSelected")
        widget.setListSelected(self.techList, listItem)
      end 
      indx = indx+1
  end
end


function selectListItem(name, listData)
  local listItem = widget.getListSelected(self.techList)
  if not listItem then return end
  local itemData = widget.getData(string.format("%s.%s", self.techList, listItem))
  self.itemData = copy(itemData.itemData)
  listData.itemData = copy(itemData.itemData)
  listData.itemTitle = itemData.itemTitle
  listData.clearConfig = itemData.clearConfig
  if not listData and listData.listType then return end
  modNpc[listData.listType](listData, self.currentIdentity, self.currentOverride)

  updateNpc()
  return 
end

--------SPECIES GATHER INFO FUNCTIONS--------
function getSpeciesOptions(species, option, returnInfo)
  return returnInfo
end

function compareDirectiveToColor(directive, json)
  if type(json) ~= "table" or (tostring(directive) == "") then return false end
  local _,set = next(json)
  if type(set) ~= "table" then return false end
  local k,v  = next(set)
  k = string.lower(k)
  v = string.lower(v)
  dLog(k, "MATCHING TEST")
  dLog(string.match(directive,tostring(k).."="), "result ")
  return string.match(directive,tostring(k).."=")
end

function getSpeciesAsset(speciesJson, genderIndx, species, optn, output)
  if not optn then return end
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
end

function getColorInfo(colors, output)
  output.title = output.title or {}
  if colors then
    for i = 1, #colors do    
      table.insert(output.title,tostring(i))
    end
  end
end


------ GUI UPDATE FUNCTIONS ------
function changeTabLabels(tabs, option)
  tabs = tabs or "nil"
  option = option or "Error"

  local tabOptions = config.getParameter("tabOptions."..option)
  local indx = 1

  if tabOptions then
    for _,v in ipairs(tabs) do
      widget.setText(v, tabOptions[indx])
      indx = indx+1
    end
  end
end

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

function setIdleStance(index)
  if index ~= 0 then
    widget.setText("lblIdleStance", tostring(index))
    local personalities = root.assetJson("/humanoid.config:personalities")
    local personality = personalities[index]
    --assert(personality, string.format("cannot find personality, bad index?  :  %s", index))
    local identity = self.currentOverride.identity
    identity.personalityIdle = personality[1]
    identity.personalityHeadOffset = personality[3]
    identity.personalityArmIdle = personality[2]
    identity.personalityArmOffset = personality[4]
  else
    widget.setText("lblPersonality", "No Override")
    clearPersonality()
  end
end

function clearPersonality()
  if self.currentOverride.identity then
    local identity = self.currentOverride.identity
    identity.personalityIdle = nil
    identity.personalityHeadOffset = nil
    identity.personalityArmIdle = nil
    identity.personalityArmOffset = nil
  end
end

function replaceDirectives(directive, directiveJson)
  
  dLog("replaceDirectives")
  dLog(directive, "enterString:  ")
  dLog(directiveJson,"enter Json")
  if not directive and type(directive) == "nil" then return nil end
  local splitDirectives = util.split(directive,"?replace")

  for i,v in ipairs(splitDirectives) do
    if not (v == "") then
        local k = string.match(v, "(%w+)=%w+")
        if directiveJson[k] or directiveJson[string.upper(k)] or directiveJson[string.lower(k)] then
            dLogJson(directiveJson[k], "matchJsonValue:")
            splitDirectives[i] = createDirective(directiveJson)
        end
    end
  end
  local returnString = ""
  for i,v in ipairs(splitDirectives) do
    if v ~= "" then
      returnString = returnString.."?replace"..v
    end
  end
  dLog(returnString, "returnString:  ")
  return returnString
end

function createDirective(directiveJson)
  local prefix = ""
  for k,v in pairs(directiveJson) do
    prefix = string.format("%s;%s=%s",prefix,k,v)
  end
  return prefix
end

function updateNpc(noVisual)
  local curSpecies = self.currentSpecies
  local curSeed =  self.currentSeed
  local curType = self.currentType
  local curLevel = self.currentLevel
  local curId = self.currentIdentity
  local curOverride = self.currentOverride

  local variant = root.npcVariant(curSpecies, curType, curLevel, curSeed)

  self.currentIdentity = copy(variant.humanoidIdentity)
  if curOverride.identity and curOverride.identity.name then
    widget.setText("tbNameBox", curOverride.identity.name)
  else
    widget.setText("tbNameBox", self.currentIdentity.name)
  end
  if noVisual then return end

  local npcPort = root.npcPortrait("full", curSpecies, curType, curLevel, curSeed, curOverride)

  return setPortrait(npcPort)
end

function setPortrait(npcPort)
  local num = 1
  local portraits = self.portraits
  while num <= #npcPort do
    widget.setImage(portraits[num], npcPort[num].image)
    widget.setVisible(portraits[num], true)
    num = num+1
  end
  while num <= #portraits do
    widget.setVisible(portraits[num], false)
    num = num+1
  end
end

-------TEST FUNCTIONS-----------
--not useful in any way, used to test things

function testFunction()
    local config = root.npcConfig("villager")
    dLogJson(config, "config:")
end



function getAsset(assetPath)
  local asset = root.assetJson(assetPath)
  return asset
end

-------MAIN LIST FUNCTIONS-----------


function replaceDirectiveAtEnd(directiveBase, directiveReplace)
  directiveBase = directiveBase or ""
  directiveReplace = directiveReplace or ""

  local split = util.split(directiveBase, "?replace")
  if #split < 3 then return directiveBase end
  if not string.match(directiveReplace, "?replace") then directiveReplace = "?replace"..directiveReplace end

  split[#split] = directiveReplace
  local result = ""
  for _,v in ipairs(split) do
    result = "?replace"..v
  end

  return result
end

function getDirectiveAtEnd(directiveBase)
  local returnValue = ""
  local split = util.split(directiveBase, "?replace")
  local indx = #split
  if indx < 2 then 
    return nil 
  end
  while indx > 2 do
    if tostring(split[indx]) ~= ""  and string.find(split[indx], "=") then
      break
    end
    indx = indx - 1
  end 
  local table = {}
  for k, v in string.gmatch(split[indx],"(%w+)=(%w+)") do
    table[string.lower(k)] = string.lower(v)
  end
  return table
end


function getParamsFromSpawner()
  dLog("checkin FOR THE DATA WTF")
    self.doingMainUpdate = true
    local result = self.gettingNpcData:result()
    if type(result) ~= "table" then
     result = {} 
    else
      result = copy(self.gettingNpcData:result())
    end
    --dLogJson(result, "GETTIN DATA", true)
    --world.logInfo("UI: the seed value has been initialized from panel object. Changed to: " .. tostring(result))
    --self.slider.value = result

    if result.npcSpecies then
      self.currentSpecies = tostring( result.npcSpecies)
      dLog("init:  getting species")
    end

    if result.npcType then
      self.currentType = tostring(result.npcType)
      dLog("init:  getting type")
    end

    if result.npcLevel then
      self.currentLevel = tonumber(result.npcLevel) or 10
      dLog("init:  getting level")
    end

    if result.npcParam then
      self.currentOverride = copy(result.npcParam)
      --dLogJson(self.currentOverride, "init:  getting parms")
      if not self.currentOverride.scriptConfig then self.currentOverride.scriptConfig = {} end
    end
    if not self.currentOverride.identity then 
      self.currentOverride.identity = {}
    end
    
    if type(result.npcSeed) == "string" then 
        self.currentSeed = tostring(result.npcSeed)
        widget.setText("seedValue", self.currentSeed)
    elseif type(result.npcSeed) == "number" then
        self.manualInput = false
        self.currentSeed = tostring(result.npcSeed)
        self.targetSize = result.npcSeed
        widget.setSliderValue("sldTargetSize", self.targetSize)
        widget.setText("seedValue", self.currentSeed)
    end

    --setName
    if self.currentOverride.identity.name then
      widget.setText("tbNameBox", self.currentOverride.identity.name)
    end
   -- self.updateIndx = self.updateIndx + 1
    updateNpc()
    --self.speciesJson = root.assetJson("/species/"..self.currentSpecies..".species")
    --modNpc.Species({itemTitle = self.currentSpecies})

    widget.setSelectedOption(self.categoryWidget, -1)
    widget.setVisible(self.categoryWidget, true)
    widget.setVisible(self.tabGroupWidget, true)
    widget.setVisible(self.scrollArea, true)
    
    --script.setUpdateDelta(10)
    --self.updateIndx = self.updateIndx + 1 

end

function getGenderIndx(name)
  local genderIndx
  for i,v in ipairs(self.speciesJson.genders) do
    if v.name == name then return i end
  end
end
------CHANGE NPC FUNCTIONS---------
function modNpc.Species(listData, cur, curO)
  local curO = curO.identity
  if self.currentSpecies ~= listData.itemTitle then

    dLog({listData,curO},"modNPC.HitSpecies")
    self.currentSpecies = tostring(listData.itemTitle)
    updateNpc(true)
    self.currentOverride.identity = nil
    self.currentOverride.identity = {}
  end
  local speciesIcon = self.speciesJson.genders[getGenderIndx(self.currentIdentity.gender)].characterImage
  widget.setImage("techIconHead",speciesIcon)
end

function modNpc.NpcType(listData, cur, curO)
    self.currentType = tostring(listData.itemTitle)
end

function modNpc.Hair(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then 
    curO["hairType"] = nil
  else
    curO.hairType = tostring(listData.itemTitle)
  end
end

function modNpc.FHair(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then 
    dLog("listData.fhair : clearConfig:  entered ClearConfig")
    --curO["facialHairGroup"] = nil
    curO["facialHairType"] = nil
  else
    --curO.facialHairGroup = listData.facialHairGroup
    curO.facialHairType = listData.itemTitle
  end
end

function modNpc.FMask(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then 
    dLog("listData.fMask : clearConfig:  entered ClearConfig")
    --curO["facialHairGroup"] = nil
    curO["facialMaskType"] = nil
  else
    --curO.facialHairGroup = listData.facialHairGroup
    curO.facialMaskType = listData.itemTitle
  end
end

function modNpc.HColor(listData, cur, curO)
  local curO = curO.identity
  dLog(cur.hairDirectives, "enterd HColor  ")
  dLog(listData.itemData, "ItemData  ")
  if cur.hairDirectives == "" then return end
  if listData.clearConfig then
    curO["hairDirectives"] = nil
  else
    curO.hairDirectives = replaceDirectives(curO.hairDirectives or cur.hairDirectives, listData.itemData)
  end
end

function modNpc.FHColor(listData, cur, curO)
  local curO = curO.identity
  if cur.facialHairDirectives == "" then return end
  if listData.clearConfig then
    curO["facialHairDirectives"] = nil
  else
    curO.facialHairDirectives = replaceDirectives(curO.facialHairDirectives or cur.facialHairDirectives, listData.itemData)
  end
end

function modNpc.FMColor(listData, cur, curO)
  local curO = curO.identity
  if cur.facialMaskDirectives == "" then return end
  if listData.clearConfig then
    curO["facialMaskDirectives"] = nil
  else
    curO.facialMaskDirectives = replaceDirectives(curO.facialMaskDirectives or cur.facialMaskDirectives, listData.itemData)
  end
end

function modNpc.BColor(listData, cur, curO)
  local curO = curO.identity
  dLog("enterd BColor")
  if listData.clearConfig then
    curO["bodyDirectives"] = nil
    curO["emoteDirectives"] = nil
  else
    curO.bodyDirectives = replaceDirectives(curO.bodyDirectives or cur.bodyDirectives, listData.itemData)
    curO.emoteDirectives = replaceDirectives(curO.emoteDirectives or cur.emoteDirectives, listData.itemData)  
  end
end

function modNpc.UColor(listData, cur, curO)
  local curO = curO.identity
  if listData.clearConfig then
    local endDirective = getDirectiveAtEnd(cur.bodyDirectives)
    curO.bodyDirectives = replaceDirectives(curO.bodyDirectives, endDirective)
    curO.hairDirectives = replaceDirectives(curO.hairDirectives, endDirective)  
    curO.emoteDirectives = replaceDirectives(curO.emoteDirectives, endDirective)
  else
    curO.bodyDirectives = replaceDirectives(curO.bodyDirectives or cur.bodyDirectives, listData.itemData)
    curO.hairDirectives = replaceDirectives(curO.hairDirectives or cur.hairDirectives, listData.itemData)  
    curO.emoteDirectives = replaceDirectives(curO.emoteDirectives or cur.emoteDirectives, listData.itemData)  
  end
end

----[[

function modNpc.Prsnlity(listData,cur,curO)
  if listData.clearConfig then 
    if path(curO,"scriptConfig","personality") then
        curO.scriptConfig.personality = nil
    end
    return
  else
    setPath(curO,"scriptConfig","personality",{})
  end
  self.currentOverride.scriptConfig.personality = listData.itemData
  dLogJson(curO, "curO", true)
end
--TODO -- ADD args.listype UP TOP!!!!
function selectedTab.Species(args)
    args = args or {}
    args.title = copy(self.speciesList)
    args.currentSelection = self.currentSpecies
    args.isOverride = false
end
function selectedTab.NpcType(args)
    args = args or {}
    args.title = copy(self.npcTypeList)
    args.currentSelection = self.currentType
    args.isOverride = false
end
function selectedTab.Hair(args)
    args.currentSelection = self.currentOverride.identity.hairType or self.currentIdentity.hairType 
    args.title = {}
    args.isOverride = true
end
function selectedTab.FHair(args)
    args.currentSelection = self.currentOverride.identity.facialHairType or self.currentIdentity.facialHairType
    args.title = {}
    args.isOverride = true
end
function selectedTab.FMask(args)
    args.currentSelection = self.currentOverride.identity.facialMaskType or self.currentIdentity.facialMaskType
    args.title = {}
    args.isOverride = true
end
function selectedTab.HColor(args)
  args.title = {}
  args.colors = {}
  if compareDirectiveToColor(self.currentIdentity.hairDirectives, self.speciesJson.bodyColor) then
    self.returnInfoColors = self.speciesJson.bodyColor
  elseif compareDirectiveToColor(self.currentIdentity.hairDirectives, self.speciesJson.hairColor) then
    self.returnInfoColors = self.speciesJson.hairColor
  elseif compareDirectiveToColor(self.currentIdentity.hairDirectives, self.speciesJson.undyColor) then
    self.returnInfoColors = self.speciesJson.undyColor
  else 
    self.returnInfoColors = nil
  end
  args.isOverride = true
end
function selectedTab.FHColor(args)
  args.title = {}
  args.colors = {}
  if compareDirectiveToColor(self.currentIdentity.facialHairDirectives, self.speciesJson.bodyColor) then
    self.returnInfoColors = self.speciesJson.bodyColor
  elseif compareDirectiveToColor(self.currentIdentity.facialHairDirectives, self.speciesJson.hairColor) then
    self.returnInfoColors = self.speciesJson.hairColor
  elseif compareDirectiveToColor(self.currentIdentity.facialHairDirectives, self.speciesJson.undyColor) then
    self.returnInfoColors = self.speciesJson.undyColor
  else 
    self.returnInfoColors = nil
  end
  args.isOverride = true
end
function selectedTab.FMColor(args)
  args.title = {}
  args.colors = {}
  if compareDirectiveToColor(self.currentIdentity.facialMaskDirectives, self.speciesJson.bodyColor) then
    self.returnInfoColors = self.speciesJson.bodyColor
  elseif compareDirectiveToColor(self.currentIdentity.facialMaskDirectives, self.speciesJson.hairColor) then
    self.returnInfoColors = self.speciesJson.hairColor
  elseif compareDirectiveToColor(self.currentIdentity.facialMaskDirectives, self.speciesJson.undyColor) then
    self.returnInfoColors = self.speciesJson.undyColor
  else 
    self.returnInfoColors = nil
  end
  args.isOverride = true
end
function selectedTab.BColor(args)
  args.title = {}
  args.colors = {}
  if #self.speciesJson.bodyColor > 1 then
    self.returnInfoColors = self.speciesJson.bodyColor
  else
    self.returnInfoColors = nil
  end
  args.isOverride = true
end
function selectedTab.UColor(args)
  args.title = {}
  args.colors = {}
  if #self.speciesJson.undyColor > 1 then
    self.returnInfoColors =  self.speciesJson.undyColor
  else
    self.returnInfoColors = nil
  end
  args.isOverride = true
end


function selectedTab.Prsnlity(args)
  local npcType = self.currentType
  self.typeConfig = root.npcConfig(npcType)
  args.title = {}
  args.iData = {}
  for _,v in ipairs(self.typeConfig.scriptConfig.personalities) do
    local prsnlity = v[2]
    dLog(prsnlity.personality, "Prsnlity:  ")
    table.insert(args.title,prsnlity.personality)
    table.insert(args.iData,prsnlity)
  end
  args.isOverride = true
end


function selectedTab.Export(args)
  args.useInfoList = true
  args.skipTheRest = true
  args.selectedCategory = "ExportOptn"
  self.currentOverride.identity = parseArgs(self.currentOverride.identity, copy(self.currentIdentity))
  setNpcName()
  local args = {
    npcSpecies = self.currentSpecies,
    npcSeed = self.currentSeed,
    npcType = self.currentType,
    npcLevel = self.currentLevel,
    npcParam = self.currentOverride
  }
  local spawner = world.getObjectParameter(pane.containerEntityId(),"spawner")
  spawner.npcSpeciesOptions[1] = args.npcSpecies
  spawner.npcTypeOptions[1] = args.npcType
  spawner.npcParameterOptions[1] = args.npcParam
  local exportString = string.format("/spawnitem spawnerwizard 1 '{\"spawner\":%s,\"shortdescription\":\"%s Spawner\",\"retainObjectParametersInItem\": true}'",sb.printJson(spawner), args.npcParam.identity.name)
  local config = getUserConfig("npcSpawnerPlus")
  local name = widget.getText("tbNameBox")
  local species = self.currentSpecies
  local gender = self.currentIdentity.gender
  local key = string.format("%s%s%s", name,species,gender)
  self.uniqueExportId = string.lower(key)
  dLog("")
  dLog("Search ID:  "..string.lower(key).."\n\n"..exportString.."\n\n")
  dLog("")
  dLog("")
  --if config.exportedNpcs[1] then config.exportedNpcs = {} end
  --config.exportedNpcs[self.uniqueExportId] = exportString
  --root.setConfigurationPath("npcSpawnerPlus.exportedNpcs", config.exportedNpcs)
end

function selectedTab.Info(args)
  args.useInfoList = true
  args.skipTheRest = true
  args.selectedCategory = self.categoryWidgetData
end


--[[
  if self.speciesJson["headOptionAsFacialhair"] then
    if self.speciesJson["headOptionAsFacialhair"] == true then
      returnInfo["headOptionAsFacialhair"] = self.speciesJson["headOptionAsFacialhair"]
    end
  end

  if self.speciesJson["altColorAsFacialMaskSubColor"] then
    if self.speciesJson["altColorAsFacialMaskSubColor"] == true then
      returnInfo["altColorAsFacialMaskSubColor"] = self.speciesJson["altColorAsFacialMaskSubColor"]
    end
  end

  if self.speciesJson["bodyColorAsFacialMaskSubColor"] then
    if self.speciesJson["bodyColorAsFacialMaskSubColor"] == true then
      returnInfo["bodyColorAsFacialMaskSubColor"] = self.speciesJson["bodyColorAsFacialMaskSubColor"]
    end
  end
------------------
    local crewConfig = root.npcConfig(self.currentType)
    local crewUniformStorage = path(args.npcParam,"scriptConfig","initialStorage","crewUniform")
    if not crewUniformStorage then 
      crewUniformStorage = args.npcParam
      setPath(crewUniformStorage,"scriptConfig","initialStorage","crewUniform",{})
      crewUniformStorage = path(args.npcParam,"scriptConfig","initialStorage","crewUniform")
    end
    crewUniformStorage.slots = copy(self.equipSlot)
    crewUniformStorage.items = {}
    for i = 1, #crewUniformStorage.slots do
      crewUniformStorage.items[self.equipSlot[i]-] = self.equipBagStorage[i]
    end
    args.npcParam.scriptConfig.crew =  copy(crewConfig.scriptConfig.crew)
    local crew = args.npcParam.scriptConfig.crew
    if crew then
      if not crew.uniform then crew.uniform = {} end
      crew.unifomSlots = copy(self.equipSlot)
      crew.uniform.slots = copy(self.equipSlot)
      crew.uniform.items = copy(crewUniformStorage.items)
      crew.role.uniformColorIndex = 0
      crew.role["uniformColorIndex"] = 0
      crew.defaultUniform = {}
      for i = 1, #crewUniformStorage.slots do
        crew.defaultUniform[self.equipSlot[i]-] = self.equipBagStorage[i]
      end
    end
--]]