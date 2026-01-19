--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local rest_utils = require("rest_utils")

--
-- Return all the actively monitored ntopng interfaces along with their ids
-- Example: curl -u admin:admin -H "Content-Type: application/json"  http://localhost:3000/lua/rest/v2/get/ntopng/interfaces.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local interfaces = interface.getIfNames()

for ifid, ifname in pairs(interfaces) do
  interface.select(ifname)
  local custom_name = getHumanReadableInterfaceName(ifname)

  res[#res + 1] = {
    ifid = tonumber(ifid),
    ifname = ifname,
    name = custom_name,
    is_packet_interface = interface.isPacketInterface(),
    is_pcap_interface = interface.isPcapDumpInterface(),
    is_zmq_interface = interface.isZMQInterface()
  }
end

rest_utils.answer(rc, res)
