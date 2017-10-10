nanohttpd
=========

A simple HTTP server using coroutines, written in Lua.

Install
-------

### Requirements
    - Lua 5.3
    - LuaSocket

### Install

```bash
$ git clone https://github.com/oyasmi/nanohttpd.git
```

Start
-----

```bash
$ cd /path/to/nanohttpd
$ ./httpd.lua
```

Config
------
All configurations reside within `config.lua`.

```
local host = "127.0.0.1"
local port = 8000

local root_path = "."           -- absolute or relative path
```
