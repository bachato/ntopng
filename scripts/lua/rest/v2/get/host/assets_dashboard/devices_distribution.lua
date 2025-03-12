--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "label_utils"
require "ntop_utils"
require "http_lint"
require "lua_utils_get"
local graph_utils = require "graph_utils"
local format_utils = require "format_utils"
local rest_utils = require "rest_utils"
local asset_utils = require "asset_utils"
local discover_utils = require "discover_utils"

local ifid = _GET["ifid"] or interface.getId()
local rsp = {}
local filters = {}
local tmp_rsp = {}

local device_types = asset_utils.getDeviceTypes(ifid, filters) or {}
if table.len(device_types) > 0 then
    for _, value in pairs(device_types or {}) do
        if not tmp_rsp[tostring(value.device_type)] then
            tmp_rsp[tostring(value.device_type)] = {
                label = discover_utils.devtype2string(value.device_type),
                url = ntop.getHttpPrefix() .. "/lua/assets.lua?page=details&device_type=" .. value.device_type,
                count = 0
            }
        end
        tmp_rsp[tostring(value.device_type)].count =
            tmp_rsp[tostring(value.device_type)].count + tonumber(value.count)
    end
end

for type_id in discover_utils.sortedDeviceTypeLabels() do
    if not tmp_rsp[tostring(type_id)] then
        tmp_rsp[tostring(type_id)] = {
            label = discover_utils.devtype2string(type_id),
            count = 0
        }
    end
end

for _, value in pairsByField(tmp_rsp, "count", rev) do
    rsp[#rsp + 1] = value
end

local js_formatter = "formatValue"
local rsp = graph_utils.convert_bar_data(rsp, true, js_formatter)
rest_utils.extended_answer(rest_utils.consts.success.ok, rsp)
