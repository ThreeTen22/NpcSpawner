dComp = {}

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


function dCompare(prefix, one, two)
  if dLogLevel ~= 1 then return
  sb.logInfo(prefix)
  dComp["nil"] = nilString
  dComp[type(one)](one)
  dComp[type(two)](two)
end

function dComp.string(input)
  return dLog(input, "string: ")
end

function dComp.table(input)
  return dLogJson(input, "table")
end

function dComp.number(input)
  return dLog(input, "number")
end

function dComp.bool(input)
  return dLog(input, "bool: ")
end

function dComp.userdata(input)
  return dLogJson(input, "userdata:")
end

function nilString(input)
  return sb.logInfo("nil")
end