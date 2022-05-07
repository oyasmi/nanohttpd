#!/usr/bin/env lua
local socket = require("socket")
local set = require("set")
local httplib = require("httplib")
local config = require("config")

recvt = set.new()
sendt = set.new()

socks = {}
handlers = {}
strs_read = {}
resps_to_send = {}

function read_req(fd)
  local pos_a, pos_b = strs_read[fd]:find("\r\n\r\n")
  local req_str
  if pos_a then
    req_str = strs_read[fd]:sub(1, pos_b)
    strs_read[fd] = strs_read[fd]:sub(pos_b + 1)
  else
    recvt:insert(socks[fd])
    req_str = coroutine.yield()
    recvt:remove(socks[fd])
  end
  return req_str
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
    local req_str = read_req(fd)
    local req = httplib.parse_req(req_str)
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
  svr_sock:settimeout(0)
  socks[svr_fd] = svr_sock
  recvt:insert(svr_sock)
  print(string.format("Server Started on %s:%d ...", config.host, config.port))
  
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
          strs_read[new_fd] = ""
          new_conn:settimeout(0)
          coroutine.resume(handlers[new_fd], new_fd)
        end
      else
        local ret, error_str, read_str = conn:receive("*a")
        if error_str == "closed" or read_str == nil or #read_str == 0 then
          close_sock(fd)
        else
          strs_read[fd] = strs_read[fd] .. read_str
          local pos_a, pos_b = string.find(strs_read[fd], "\r\n\r\n")
          if pos_a then
            local req_str = strs_read[fd]:sub(1, pos_b)
            strs_read[fd] = strs_read[fd]:sub(pos_b + 1)
            coroutine.resume(handlers[fd], req_str)
          end
        end
      end
    end
    for i, conn in ipairs(writable) do
      local fd = conn:getfd()
      local resp_msg = resps_to_send[fd]
      local bytes_sent, err = conn:send(resp_msg)
      if bytes_sent == nil then -- error
        if err == "timeout" then
        else
          print(err)
          close_sock(fd)
        end
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
