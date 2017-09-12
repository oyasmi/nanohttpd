#!/usr/local/bin/lua5.3
local socket = require("socket")
local newset = require("set")
local httplib = require("httplib")
local config = require("config")

recvt = newset()
sendt = newset()

socks = {}
handlers = {}
resps_to_send = {}

function read_req(fd)
  recvt:insert(socks[fd])
  req = coroutine.yield()
  recvt:remove(socks[fd])
  return req
end

function send_resp(fd, resp_msg)
  resps_to_send[fd] = resp_msg
  sendt:insert(socks[fd])
  coroutine.yield()
  sendt:remove(socks[fd])
  resps_to_send[fd] = nil
end

function close_sock(fd)
  resps_to_send[fd] = nil
  if socks[fd] then
    recvt:remove(socks[fd])
    sendt:remove(socks[fd])
    socks[fd]:close()
    socks[fd] = nil
  end
  handlers[fd] = nil
  print("connection closed")
end

function handle(fd)
  while true do
    local req = read_req(fd)
    req["uri"] = config.root_path .. req["uri"]
    local resp = httplib.process_req(req)
    local resp_msg = httplib.gen_resp_string(resp)
    send_resp(fd, resp_msg)
  end
end

function main()
  config.host = config.host or "127.0.0.1"
  config.port = config.port or 8000
  config.root_path = config.root_path or "."
  
  local svr_sock = assert(socket.bind(config.host, config.port))
  local svr_fd = svr_sock:getfd()
  svr_sock:settimeout(0.1)
  socks[svr_fd] = svr_sock
  recvt:insert(svr_sock)
  print("Server Started on ", config.host, ":", config.port)
  
  while true do
    local readable, writable, status = socket.select(recvt, sendt, 60)
    for i, conn in ipairs(readable) do
      local fd = conn:getfd()
      if(fd == svr_fd) then
        local new_conn = conn:accept()
        if new_conn then
          print("new connection")
          local new_fd = new_conn:getfd()
          socks[new_fd] = new_conn
          handlers[new_fd] = coroutine.create(handle)
          coroutine.resume(handlers[new_fd], new_fd)
        end
      else
        local req = httplib.read_req(conn)
        if req then
          print("get request: " .. req["method"] .. " " .. req["uri"])
          coroutine.resume(handlers[fd], req)
        else
          close_sock(fd)
        end
      end
    end
    for i, conn in ipairs(writable) do
      local fd = conn:getfd()
      local resp_msg = resps_to_send[fd]
      local bytes_sent = conn:send(resp_msg)
      if bytes_sent == nil then -- error
        close_sock(fd)
      elseif bytes_sent == #resp_msg then -- successfully
        coroutine.resume(handlers[fd])
      elseif bytes_sent < #resp_msg then -- partially send
        resps_to_send[fd] = string.sub(resp_msg, bytes_sent+1)
      else
        print("Error")
        close_sock(fd)
      end
    end
  end
  
end

main()
