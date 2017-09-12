local function newset()
  local reverse = {}
  local set = {}
  return setmetatable(set,
                      {__index = {
                         insert = function(set, value)
                           if not reverse[value] then
                             table.insert(set, value)
                             reverse[value] = #set
                           end
                         end,
                         remove = function(set, value)
                           local index = reverse[value]
                           if index then
                             reverse[value] = nil
                             local top = table.remove(set)
                             if top ~= value then
                               reverse[top] = index
                               set[index] = top
                             end
                           end
                         end}
                      })
end

return newset
