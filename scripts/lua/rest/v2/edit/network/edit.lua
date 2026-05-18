--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

require("lua_utils")
require("http_lint")

local rest_utils = require("rest_utils")
local site_utils = require("site_utils")

local network_cidr = _POST["network_cidr"]
local network_alias = _POST["custom_name"]
local network_site = _POST["site_id"]

if not isEmptyString(network_site) then
	local site_utils = require("site_utils")
	site_utils.mapNetworkToSite(network_cidr, network_site)
end

if not isEmptyString(network_alias) then
   setLocalNetworkAlias(network_cidr, network_alias)
end

rest_utils.answer(rest_utils.consts.success.ok)
