--
-- (C) 2013-25 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local json = require("dkjson")
require "lua_utils"

local ifid = _GET["ifid"] or interface.getId()
local selected_asn = _GET["show_as"]
local as_filter = nil

if selected_asn == "my_as" then
    as_filter = 1
elseif selected_asn == "my_customer_as" then
    as_filter = 2
elseif selected_asn == "remote_as" then
    as_filter = 3
end

interface.select(ifid)

local as_info = interface.getASesInfo({
    maxHits = 7,
    sortColumn = "column_traffic",
    a2zSortOrder = false,
}, false, as_filter)


if as_info and table.len(as_info) > 0 then as_info = as_info["ASes"] end
rest_utils.answer(rest_utils.consts.success.ok, as_info)
