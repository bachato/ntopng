--
-- (C) 2021 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"

local as_utils = {}

local function parseASNList(string)
   local asn = {}
   local tmp = split(string, ",")
   for _, val in pairs(tmp or {}) do
      asn[val] = 1
   end
   return asn
end

function as_utils.getCustomerASNList()
   return ntop.getCache("ntopng.prefs.config_customer_asn_list") or ""
end

function as_utils.getSubCustomerASNList()
   return ntop.getCache("ntopng.prefs.config_sub_customer_asn_list") or ""
end

function as_utils.getRemoteASNList()
   return ntop.getCache("ntopng.prefs.config_remote_asn_list") or ""
end

function as_utils.getCustomerASNs()
   return parseASNList(as_utils.getCustomerASNList())
end

function as_utils.getSubCustomerASNs()
   return parseASNList(as_utils.getSubCustomerASNList())
end

function as_utils.getRemoteASNs()
   return parseASNList(as_utils.getRemoteASNList())
end

function as_utils.getAllConfigurations()
   local customer_asn = as_utils.getCustomerASNs()
   local sub_customer_asn = as_utils.getSubCustomerASNs()
   local remote_asn = as_utils.getRemoteASNs()
   return customer_asn, sub_customer_asn, remote_asn
end

return as_utils
