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
local others = {label = i18n("others"), value = 0}

local oses = asset_utils.getOSes(ifid, filters) or {}
if table.len(oses) > 0 then
    for _, value in pairs(oses or {}) do
        if not tmp_rsp[tostring(value.os_type)] then
            tmp_rsp[tostring(value.os_type)] = {
                label = discover_utils.getOsName(value.os_type),
                url = ntop.getHttpPrefix() .. "/lua/assets.lua?page=details&os_type=" .. value.os_type,
                count = 0
            }
        end
        tmp_rsp[tostring(value.os_type)].count =
            tmp_rsp[tostring(value.os_type)].count + tonumber(value.count)
    end
end

for type_id in discover_utils.sortedOsTypeLabels() do
    if not tmp_rsp[tostring(type_id)] then
        tmp_rsp[tostring(type_id)] = {
            label = discover_utils.getOsName(type_id),
            count = 0
        }
    end
end

for _, value in pairsByField(tmp_rsp, "count", rev) do
    rsp[#rsp + 1] = value
end

if others.value > 0 then rsp[#rsp + 1] = others end

local js_formatter = "formatValue"
rest_utils.extended_answer(rest_utils.consts.success.ok,
                           graph_utils.convert_bar_data(rsp, true, js_formatter))
