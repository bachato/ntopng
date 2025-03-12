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
local tmp_rsp = {
    dns_server = {
        offline = 0,
        online = 0,
        type = 0
    },
    smtp_server = {
        offline = 0,
        online = 0,
        type = 2
    },
    imap_server = {
        offline = 0,
        online = 0,
        type = 4
    },
    pop_server = {
        offline = 0,
        online = 0,
        type = 5
    },
    ntp_server = {
        offline = 0,
        online = 0,
        type = 3
    },
    dhcp_server = {
        offline = 0,
        online = 0,
        type = 1
    },
}

local tot_servers_overview = asset_utils.getServersOverview(ifid, filters)
if table.len(tot_servers_overview) > 0 then
    tot_servers_overview = tot_servers_overview[1]
    for value, num in pairsByKeys(tot_servers_overview) do
        if value == "dns_servers_offline" then
            tmp_rsp.dns_server.offline = num or 0
        elseif value == "dns_servers_online" then
            tmp_rsp.dns_server.online = num or 0
        elseif value == "smtp_servers_offline" then
            tmp_rsp.smtp_server.offline = num or 0
        elseif value == "smtp_servers_online" then
            tmp_rsp.smtp_server.online = num or 0
        elseif value == "imap_servers_offline" then
            tmp_rsp.imap_server.offline = num or 0
        elseif value == "imap_servers_online" then
            tmp_rsp.imap_server.online = num or 0
        elseif value == "pop_servers_offline" then
            tmp_rsp.pop_server.offline = num or 0
        elseif value == "pop_servers_online" then
            tmp_rsp.pop_server.online = num or 0
        elseif value == "ntp_servers_offline" then
            tmp_rsp.ntp_server.offline = num or 0
        elseif value == "ntp_servers_online" then
            tmp_rsp.ntp_server.online = num or 0
        elseif value == "dhcp_servers_offline" then
            tmp_rsp.dhcp_server.offline = num or 0
        elseif value == "dhcp_servers_online" then
            tmp_rsp.dhcp_server.online = num or 0
        end
    end

    for server, info in pairsByKeys(tmp_rsp or {}) do
        rsp[#rsp + 1] = { 
            server = i18n('asset_details.' .. server) .. "s",
            online = tostring(info.online),
            offline = tostring(info.offline),
            url = ntop.getHttpPrefix() .. "/lua/assets.lua?page=details&server_type=" .. info.type
        }
    end
end

rest_utils.extended_answer(rest_utils.consts.success.ok, rsp, {
    ["recordsTotal"] = tonumber(tot_assets)
})
