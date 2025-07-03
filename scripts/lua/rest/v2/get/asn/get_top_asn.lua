--
-- (C) 2013-25 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local json = require("dkjson")
require "lua_utils"

local ifid = _GET["ifid"] or interface.getId()

interface.select(ifid)

local as_info = interface.getASesInfo({maxHits = 7, sortColumn = "column_traffic", a2zSortOrder = false})

if as_info and table.len(as_info) > 0 then
    as_info = as_info["ASes"]
end
rest_utils.answer(rest_utils.consts.success.ok, as_info)