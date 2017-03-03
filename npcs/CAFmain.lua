
function getWeapon(weaponID)
	npc.setItemSlot("primary", weaponID)
end

function getAlt(altID)
	npc.setItemSlot("alt", altID)
end

function getBack(backID)
	npc.setItemSlot("back", backID)
end

function getHeadArmor(armorID)
	npc.setItemSlot("head", armorID)
end

function getChestArmor(armorID)
	npc.setItemSlot("chest", armorID)
end

function getLegArmor(armorID)
	npc.setItemSlot("legs", armorID)
end

function reInit()		--called after all gear has been reset. Helps to re-initialize combat behavior based on new weapons
	init()
end


function logSeed()
	return
	-- sb.logInfo("NPC - %s", sb.printJson(npcInfo, true))
end