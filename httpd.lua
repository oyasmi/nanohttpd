#!/usr/local/bin/lua5.3
local socket = require("socket")

function guessMime(filename)
  local mime = {html='text/html', htm='text/html', css='text/css', js='text/javascript',
                txt='text/plain', png='image/png', jpg='image/jpeg', jpeg='image/jpeg',
                bmp='image/bmp', ico='image/x-icon', svg='image/svg+xml'}
  local surfix = "html"
  for i = #filename, 1, -1 do
    if string.sub(filename, i, i) == '.' then
      surfix = string.sub(filename, i+1)
      break
    end
  end
  local mimetype = mime[surfix]
  if mimetype == nil then
    mimetype = mime['html']
  end
  return mimetype
end

function handle(client)
  local req_line = client:receive('*l')
  _ = client:receive('*a')
  local req = {}
  local i = string.find(req_line, ' ', 1, true)
  req[1] = string.sub(req_line, 1, i-1)
  local j = string.find(req_line, ' ', i+1, true)
  req[2] = string.sub(req_line, i+1, j-1)
  if string.sub(req[2], #req[2], #req[2]) == "/" then
    req[2] = req[2] .. "index.html"
  end
  req[3] = string.sub(req_line, j+1)
  local f = io.open("."..req[2], "r")
  local resp = {}
  if f == nil then
    resp[#resp+1] = "HTTP/1.0 404 Not Found"
    resp[#resp+1] = ""
  else
    resp[#resp+1] = "HTTP/1.0 200 OK"
    local ctnt = f:read("*a")
    resp[#resp+1] = "Content-Length: " .. #ctnt
    local mime = guessMime(req[2])
    resp[#resp+1] = "Conten-Type: " .. mime
    if mime ~= 'text/html' then
      resp[#resp+1] = "Expires: " .. os.date('!%a, %d %b %Y %T GMT', os.time()+86400*3)
    end
    resp[#resp+1] = ""
    resp[#resp+1] = ctnt
    f:close()
  end
  
  client:send(table.concat(resp, "\r\n"))
  client:close()
end

function main()
  local port = 6000
  if arg[1] ~= nil then
    port = tonumber(arg[1])
  end
  
  local server = assert(socket.bind("127.0.0.1", port))
  while true do
    local client = server:accept()
    client:settimeout(1, 'b')
    handle(client)
  end
end

main()
