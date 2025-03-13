--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "label_utils"
require "ntop_utils"
require "http_lint"
require "lua_utils_get"
local format_utils = require "format_utils"
local rest_utils = require "rest_utils"
local asset_utils = require "asset_utils"

local ifid = _GET["ifid"] or interface.getId()
local rsp = {}
local filters = {}
local tmp_rsp = {}

local tot_assets_overview = asset_utils.getAllAssetsOverview(ifid, filters)
if table.len(tot_assets_overview) > 0 then
    tot_assets_overview = tot_assets_overview[1]
    for value, num in pairsByKeys(tot_assets_overview) do
        local name = i18n("asset_details." .. value) .. "s"
        local text_color = nil
        local add_separator_above = false
        local add_separator_below = false
        local key = nil
        if value == "online_asset" then
            add_separator_above = true
            key = 8
            text_color = "text-success"
            text_width = "6"
        elseif value == "offline_asset" then
            key = 9
            text_color = "text-secondary"
            text_width = "6"
        elseif value == "assets" then
            text_width = "12"
            key = 1
            add_separator_below = true
        elseif value == "dns_server" then
            key = 2
            text_width = "4"
        elseif value == "dhcp_server" then
            key = 3
            text_width = "4"
        elseif value == "smtp_server" then
            key = 4
            text_width = "4"
        elseif value == "imap_server" then
            add_separator_above = true
            key = 5
            text_width = "4"
        elseif value == "pop_server" then
            key = 6
            text_width = "4"
        elseif value == "ntp_server" then
            key = 7
            text_width = "4"
        end
        tmp_rsp[key] = { 
            text_color = text_color,
            text_width = text_width,
            num_elements = num,
            add_separator_above = add_separator_above,
            add_separator_below = add_separator_below,
            label = name 
        }
    end

    for _, value in pairsByKeys(tmp_rsp or {}) do
        rsp[#rsp + 1] = value
    end
end

rest_utils.extended_answer(rest_utils.consts.success.ok, rsp, {
    ["recordsTotal"] = tonumber(tot_assets)
})
