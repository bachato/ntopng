--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local rest_utils = require("rest_utils")

--
-- Read the IP address(es) for an interface
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/interface/address.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = interface.getId()
local if_name = interface.getName()
local rsp = {
    name = if_name,
    id = ifid
}

rest_utils.answer(rc, rsp)
