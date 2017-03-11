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


  sb.logInfo(prefix)
end

function dComp.string(input)
end

function dComp.table(input)
end

function dComp.number(input)
end

function dComp.bool(input)
end

function dComp.userdata(input)
end

end