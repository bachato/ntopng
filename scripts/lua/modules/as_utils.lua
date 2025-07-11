--
-- (C) 2021 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"

local as_utils = {}

function as_utils.getAllConfigurations()
    local customer_asn_string =
        ntop.getCache("ntopng.prefs.config_customer_asn_list") or ""
    local sub_customer_asn_string = ntop.getCache(
                                 "ntopng.prefs.config_sub_customer_asn_list") or
                                 ""
    local remote_asn_string = ntop.getCache("ntopng.prefs.config_remote_asn_list") or
                           ""
    
    local customer_asn = {}
    local sub_customer_asn = {}
    local remote_asn = {}

    local tmp = split(customer_asn_string, ",")
    for _, val in pairs(tmp or {}) do
        customer_asn[val] = 1
    end
    tmp = split(sub_customer_asn_string, ",")
    for _, val in pairs(tmp or {}) do
        sub_customer_asn[val] = 1
    end
    tmp = split(remote_asn_string, ",")
    for _, val in pairs(tmp or {}) do
        remote_asn[val] = 1
    end

    return customer_asn, sub_customer_asn, remote_asn
end

return as_utils
