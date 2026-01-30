--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")

--
-- Return limits for the current ntopng license
-- Example: curl -u admin:admin -H "Content-Type: application/json"  http://localhost:3000/lua/rest/v2/get/ntopng/limits.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {
   nodes = {{
      group = "unknown",
      value = 1,
      id = "192.168.2.169",
      color = "#28a745",
      label = "ProCurve Switch 2510B-24"
   }, {
      group = "unknown",
      value = 1,
      id = "192.168.2.237",
      color = "#495057",
      label = "X435-24P-4S"
   }},
   edges = {{
      from = "192.168.2.169",
      to = "192.168.2.237",
      title = "1.99 Mbps",
      color = "#495057",
      arrows = "to",
      value = 1987725.3608247
   }}
}

if _GET["enabled"] and _GET["enabled"] == "true" then
   res = {
      nodes = {{
         label = "Test Node 1",
         link = "/lua/flows_stats.lua",
         node_id = "test_node_1"
      }, {
         label = "Test Node 2",
         link = "/lua/flows_stats.lua",
         node_id = "test_node_2"
      }},
      links = {{
         label = "Test Link",
         source_node_id = "test_node_1",
         target_node_id = "test_node_2",
         value = 6375108
      }}
   }
end

rest_utils.answer(rc, res)
