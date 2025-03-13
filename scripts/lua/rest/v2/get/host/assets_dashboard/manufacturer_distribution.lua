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

local ifid = _GET["ifid"] or interface.getId()
local rsp = {}
local filters = {}
local tmp_rsp = {}
local max_manufacturers = 8
local others = {
    label = i18n("others"),
    value = 0 
}

local manufacturers = asset_utils.getManufacturers(ifid, filters) or {}
if table.len(manufacturers) > 0 then
    for _, value in pairs(manufacturers or {}) do
        if max_manufacturers >= 0 then
            max_manufacturers = max_manufacturers - 1
            rsp[#rsp + 1] = {
                label = shortenString(value.manufacturer, 25) .. " (" ..  tostring(value.count) .. ")",
                value = tonumber(value.count),
                url = ntop.getHttpPrefix() .. '/lua/assets.lua?page=details&manufacturer=' .. value.manufacturer
            }
        else
            others.value = others.value + value.count
        end
    end
end

if others.value > 0 then
    rsp[#rsp + 1] = others
end

local js_formatter = "formatValue"
rest_utils.extended_answer(rest_utils.consts.success.ok, graph_utils.convert_pie_data(rsp, true, js_formatter))
