--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- ##############################################

local alert_ndpi_mismatching_protocol_with_ip = classes.class(alert)

-- ##############################################

alert_ndpi_mismatching_protocol_with_ip.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_mismatching_protocol_with_ip,
   i18n_title = "alerts_dashboard.ndpi_mismatching_protocol_with_ip_title",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.defense_evasion,
      mitre_technique = mitre.technique.data_obfuscation,
      mitre_id = "T1207"
   },

   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_mismatching_protocol_with_ip:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_mismatching_protocol_with_ip.format(ifid, alert, alert_type_params)
   return i18n('flow_risk.ndpi_mismatching_protocol_with_ip_descr')
end

-- #######################################################

return alert_ndpi_mismatching_protocol_with_ip
