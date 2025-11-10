--
-- (C) 2013-25 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

fname = "ndpi_application_protocols.txt"

sendHTTPContentTypeHeader('text/plain', 'attachment; filename="'..fname..'"')
interface.dumpnDPIProtocolId()
