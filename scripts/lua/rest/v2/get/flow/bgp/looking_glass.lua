--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local json = require "dkjson"
local bgp_utils = require "bgp_utils"
local rest_utils = require "rest_utils"

-- ################################################

local rsp = {}
local host_to_find = _GET["host"]

--[[
if isEmptyString(host_to_find) then
   rest_utils.answer(rest_utils.consts.err.bad_format)
   return
end
]]
-- ################################################

local rib = ntop.ribFind(host_to_find)

rib = json.encode(rib)

if not isEmptyString(rib) then
   rib = json.decode(rib)
   rsp = bgp_utils.formatBgpBmpInfo(rib)
end

-- ################################################

rest_utils.answer(rest_utils.consts.success.ok, rsp)
