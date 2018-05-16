function radioMessageIncompatibilities(currentSpecies, currentType)
    local unknownSpecies = not pcall(root.npcVariant, currentSpecies, "villager", 1)
    local unknownNpcType = not pcall(root.npcVariant, "human", currentType, 1)
    if unknownSpecies or unknownNpcType then
    local arg1, arg2, arg3 = "", "", ""
    local text = "It appears your version of reality does not recognize %s %s %s please aquire the appropriate information from the 6th dimention before interacting with this object!"
    if unknownSpecies then
        arg1 = string.format("the ^orange;Species^white;: ^orange;%s^white;", currentSpecies)
    end
    if unknownNpcType then
        arg3 = string.format("the ^yellow;NpcType^white;: ^yellow;%s^white;", currentType)
    end
    if unknownSpecies and unknownNpcType then
        arg2 = " & \n"
    end
    text = string.format(text, arg1, arg2, arg3)
    player.radioMessage({
        unique = false,
        text = text,
        textSpeed = 70,
        messageId = "testMessage",
        persistTime = 10,
    })
    pane.dismiss()
    end
end