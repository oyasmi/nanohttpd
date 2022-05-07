local root_path = ""
local mime = {html='text/html', htm='text/html', css='text/css', js='text/javascript',
              txt='text/plain', png='image/png', jpg='image/jpeg', jpeg='image/jpeg',
              bmp='image/bmp', ico='image/x-icon', svg='image/svg+xml'}

local code_desc = {[200]="OK", [404]="Not Found", [500]="Internal Server Error",
                   [501]="Not Implemented"}

local function guessMime(filename)
  local surfix = "html"
  for i = #filename, 1, -1 do
    if string.sub(filename, i, i) == '.' then
      surfix = string.sub(filename, i+1)
      break
    end
  end
  local mimetype = mime[surfix] or mime['html']
  return mimetype
end

local function parse_request(request)
  if request == nil or #request == 0 then
    return nil
  end

  lines = {}
  for l in request:gmatch("[^\r\n]+") do
    lines[#lines+1] = l
  end

  local req = {}
  req["method"], req["uri"], req["http_ver"] = string.match(lines[1], "(%a.*) (%g.*) (%g.*)")
  req["method"] = string.upper(req["method"])

  i = 2
  while i < #lines and #lines[i] > 0 do
    local comma_idx = string.find(lines[i], ":")
    req[string.lower(string.sub(lines[i], 1, comma_idx-1))] = string.sub(lines[i], comma_idx+1)
    i = i + 1
  end

  return req
end

local function process_request(req)
  local resp = {http_ver = "HTTP/1.1", body = ""}
  if req["method"] == "GET" or req["method"] == "HEAD" then
    if string.sub(req["uri"], -1) == "/" then
      req["uri"] = req["uri"] .. "index.html"
    end
    local f = io.open(req["uri"], "r")
    if f == nil then
      resp["code"] = 404
      resp["content-type"] = mime["html"]
      resp["content-length"] = 0
    else
      resp["code"] = 200
      resp["content-type"] = guessMime(req["uri"])
      if req["method"] == "GET" then
        resp["body"] = f:read("*a")
      else
        resp["body"] = ""
      end
      resp["content-length"] = #resp["body"]
      if mime ~= mime["html"] then
        resp["expires"] = os.date('!%a, %d %b %Y %T GMT', os.time()+86400*3)
      end
      f:close()
    end
  else
    resp["code"] = 501
    resp["content-type"] = mime["html"]
    resp["content-length"] = 0
  end

  return resp
end

local function gen_response_string(resp)
  local msg = {}
  msg[#msg+1] = string.format("%s %d %s", resp["http_ver"], resp["code"], code_desc[resp["code"]])
  for _, param in ipairs({"content-type", "content-length"}) do
    msg[#msg+1] = string.format("%s: %s", param, resp[param])
  end
  if resp["expires"] then
    msg[#msg+1] = resp["expires"]
  end
  msg[#msg+1] = ""
  if resp["body"] then
    msg[#msg+1] = resp["body"]
  end
  
  return table.concat(msg, "\r\n")
end

return {guessMime = guessMime,
        parse_req = parse_request,
        process_req = process_request,
        gen_resp_string = gen_response_string}
