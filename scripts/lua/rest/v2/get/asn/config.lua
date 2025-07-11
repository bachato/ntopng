--
-- (C) 2021 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local json = require "dkjson"

local res = {}

-- Get data from redis: expected format, array of objects with keys: 
res = {
    {
        key = "customer_asn",
        value_description = ntop.getCache(
            "ntopng.prefs.config_customer_asn_list") or ""
    }, {
        key = "sub_customer_asn",
        value_description = ntop.getCache(
            "ntopng.prefs.config_sub_customer_asn_list") or ""
    }, {
        key = "remote_asn",
        value_description = ntop.getCache("ntopng.prefs.config_remote_asn_list") or
            ""
    }
}

rest_utils.answer(rest_utils.consts.success.ok, res)
