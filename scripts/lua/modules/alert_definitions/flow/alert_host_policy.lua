--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local json = require "dkjson"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- ##############################################

local flow_alert_host_policy = classes.class(alert)

-- ##############################################

flow_alert_host_policy.meta = {
   alert_key = flow_alert_keys.flow_alert_host_policy,
   icon = "fas fa-fw fa-exclamation",
   i18n_title = "alerts_dashboard.host_policy",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function flow_alert_host_policy:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function flow_alert_host_policy.format(ifid, alert, alert_type_params)
   -- Extracting info field
   local href = ntop.getHttpPrefix() .. '/lua/admin/network_configuration.lua?page=policy'
   local key
   local reason = alert_type_params.reason
   
   if(reason == nil) then
      key = tostring(flow_alert_keys.flow_alert_host_policy)
      reason = alert_type_params.alerts[key].reason
   end
   

   key = "alerts_dashboard.alert_host_policy_descr_"..reason
		
   return(i18n(key, { href = href }))
end

-- #######################################################

return flow_alert_host_policy
