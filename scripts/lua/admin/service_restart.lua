--
-- (C) 2017-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

sendHTTPHeader('application/json')

if not isAdministratorOrPrintErr() then
  return
end

if ntop.serviceRestart then
  ntop.serviceRestart()
end

res = { }

print(json.encode(res, nil, 1))
