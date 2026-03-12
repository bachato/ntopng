--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local as_utils = require "as_utils"
local rest_utils = require "rest_utils"
local json = require("dkjson")
require "lua_utils"

local ifid = _GET["ifid"] or interface.getId()
local as_filter = nil

local ifid = _GET["ifid"] or interface.getId()
local epoch_begin = _GET["epoch_begin"] or 0
local epoch_end = _GET["epoch_end"] or 0
local is_live = toboolean(_GET["is_live"] or true)
local selected_asn = _GET["show_as"]
local interface_role = _GET["interface_role"]
local ip_interface = _GET["ip_interface"]

local ases_info = {}
local res = {}

interface.select(ifid)

if not is_live and not hasClickHouseSupport() then
    rest_utils.answer(rest_utils.consts.err.clickhouse_missing)
    return 
end

local options = {
    ifid = ifid,
    epoch_begin = epoch_begin,
    epoch_end = epoch_end,
    selected_asn = selected_asn,
    interface_role = interface_role,
    ip_interface = ip_interface
}

local as_info = {}

if is_live == true then
    as_info = as_utils.getTopASLive(options)
else
    as_info = as_utils.getTopASHistorical(options)
end

rest_utils.answer(rest_utils.consts.success.ok, as_info)
