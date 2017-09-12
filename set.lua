local mt = {__index = {
              insert = function(set, value)
                if not set["reverse"][value] then
                  table.insert(set, value)
                  set["reverse"][value] = #set
                end
              end,
              remove = function(set, value)
                local index = set["reverse"][value]
                if index then
                  set["reverse"][value] = nil
                  local top = table.remove(set)
                  if top ~= value then
                    set["reverse"][top] = index
                    set[index] = top
                  end
                end
              end}
           }

local function newset()
  local set = {reverse={}}
  return setmetatable(set, mt)
end

return newset
