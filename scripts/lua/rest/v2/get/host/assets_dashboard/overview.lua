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
    rsp = tot_assets_overview[1]
end

rest_utils.extended_answer(rest_utils.consts.success.ok, rsp, {
    ["recordsTotal"] = tonumber(tot_assets)
})
