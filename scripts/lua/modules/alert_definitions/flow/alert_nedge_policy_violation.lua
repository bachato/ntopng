--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_nedge_policy_violation = classes.class(alert)

-- ##############################################

alert_nedge_policy_violation.meta = {
   alert_key = flow_alert_keys.flow_alert_nedge_policy_violation,
   i18n_title = "flow_details.policy_violation",
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_nedge_policy_violation:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_nedge_policy_violation.format(ifid, alert, alert_type_params)
   return i18n("flow_details.policy_violation")
end

-- #######################################################

return alert_nedge_policy_violation
