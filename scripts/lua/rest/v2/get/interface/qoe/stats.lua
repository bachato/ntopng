--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")
local stats_utils = require("stats_utils")
local graph_utils = require "graph_utils"

--
-- Read statistics about nDPI application protocols on an interface
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/interface/qoe/stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local collapse_stats = toboolean(_GET["collapse_stats"])

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

local stats = interface.getActiveFlowsStats()

local js_formatter = "formatValue"

if not stats or not stats.qoe then
   rest_utils.answer(rest_utils.consts.err.internal_error)
   return
end

for key, value in pairsByField(stats.qoe, "num", rev) do
   res[#res + 1] = {
      label = i18n("flow_details.qoe_" .. key .. "_label") or "",
      value = value.num,
      url = nil
   }
end

if collapse_stats then
  res = stats_utils.collapse_stats(res, 1, 3 --[[ threshold ]])
end

rest_utils.answer(rc, graph_utils.convert_pie_data(res, true, js_formatter))
