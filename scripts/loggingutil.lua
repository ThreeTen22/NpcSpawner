function dLog(item, prefix)
  if not prefix then prefix = "" end
  if type(item) ~= "string" then
    sb.logInfo("%s",prefix.."  "..dOut(item))
  else 
    sb.logInfo("%s",prefix.."  "..dOut(item))
  end
end

function dOut(input)
  if not input then input = "" end
  return sb.print(input)
end

function dLogJson(input, prefix, clean)
  local str = "\n"
  if toBool(clean) or toBool(prefix) then clean = 1 else clean = 0 end
  if prefix ~= "true" and prefix ~= "false" and prefix then
    str = prefix..str
  end
   local info = sb.printJson(input, clean)
   sb.logInfo("%s", str..info)
end

function dPrintJson(input)
  local info = sb.printJson(input,1)
  sb.logInfo("%s",info)
  return info
end

local dComp = {}
dComp["string"] = function(input) return dLog(input, "string: ") end
dComp["table"] = function(input) return dLogJson(input, "table: ") end
dComp["number"] = function(input) return dLog(input, "number: ") end
dComp["boolean"] = function (input) return dLog(input, "bool: ") end
dComp["userdata"] = function(input) return dLogJson(input, "userdata:") end
dComp["thread"] = function(input) return dLog(input) end
dComp["function"] = function(input) return sb.logInfo("%s", input) end
dComp["nil"] = function(input) return dLog("nil") end

function dCompare(prefix, one, two)
    dLog(prefix)
    dComp[type(one)](one) 
    dComp[type(two)](two)
  end
