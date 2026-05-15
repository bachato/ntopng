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

local alert_ndpi_non_pqc = classes.class(alert)

-- ##############################################

alert_ndpi_non_pqc.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_non_pqc,
   i18n_title = "flow_risk.ndpi_non_pqc",
   icon = "fas fa-fw fa-exclamation",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.defense_evasion,
      mitre_technique = mitre.technique.remote_services,
      mitre_id = "T1027"
   },

   has_victim = true,
   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_non_pqc:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_non_pqc.format(ifid, alert, alert_type_params)
   return
end

-- #######################################################

return alert_ndpi_non_pqc
