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

local alert_periodicity_changed = classes.class(alert)

-- ##############################################

alert_periodicity_changed.meta = {
   alert_key = flow_alert_keys.flow_alert_periodicity_changed,
   i18n_title = "alerts_dashboard.alert_periodicity_update",
   icon = "fas fa-fw fa-arrows-alt-h",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.exfiltration,
      mitre_technique = mitre.technique.scheduled_tranfer,
      mitre_id = "T1029"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_periodicity_changed:init()
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_periodicity_changed.format(ifid, alert, alert_type_params)
   local is_periodic = alert_type_params.is_periodic or false

   if is_periodic then
      return(i18n("alerts_dashboard.periodicity_is_periodic_descr"))
   else
      return(i18n("alerts_dashboard.periodicity_is_aperiodic_descr"))
   end
end

-- #######################################################

return alert_periodicity_changed
