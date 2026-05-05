--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- Keep in sync with pro/scripts/lua/enterprise/modules/wazuh_utils.lua
local WAZUH_ALERTS_CODE = {
	OLD_PORT_NO_LONGER_OPEN = 0,
	NEW_PORT_OPEN = 1,
	PROCESS_CHANGED = 2,
	NETWORK_INTERFACE_REMOVED = 3,
	NETWORK_INTERFACE_ADDED = 4,
}

-- ##############################################

local alert_system_error = classes.class(alert)

alert_system_error.meta = {
  alert_key = other_alert_keys.alert_wazuh_info_changed,
  i18n_title = "alerts_dashboard.wazuh_info_changed",
  icon = "fas fa-fw fa-arrow-circle-up",
  entities = {
     alert_entities.system,
  },
}

-- ##############################################

function alert_system_error:init(info, host)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      info = info,
      host = host
   }
end

-- ##############################################

local function formatAlertMsg(info)
   local msg = ""
   if info.alert_code == WAZUH_ALERTS_CODE.OLD_PORT_NO_LONGER_OPEN then
      msg = i18n('alert_messages.wazuh_old_port_no_longer_open', {
         host = info.asset_info.ip,
         ifid = info.asset_info.ifid,
         key = info.asset_info.key,
         port = info.old_port_info.port
      })
   elseif info.alert_code == WAZUH_ALERTS_CODE.NEW_PORT_OPEN then
      msg = i18n('alert_messages.wazuh_new_port_open', {
         host = info.asset_info.ip,
         ifid = info.asset_info.ifid,
         key = info.asset_info.key,
         port = info.new_port_info.port
      })
   elseif info.alert_code == WAZUH_ALERTS_CODE.PROCESS_CHANGED then
      msg = i18n('alert_messages.wazuh_process_changed', {
         host = info.asset_info.ip,
         ifid = info.asset_info.ifid,
         key = info.asset_info.key,
         port = info.new_port_info.port,
         process = info.old_port_info.process,
         new_process = info.new_port_info.process
      })
   elseif info.alert_code == WAZUH_ALERTS_CODE.NETWORK_INTERFACE_REMOVED then
      msg = i18n('alert_messages.wazuh_network_interface_removed', {
         host = info.asset_info.ip,
         ifid = info.asset_info.ifid,
         key = info.asset_info.key,
         iface = info.old_network_interface_info.name,
      })
   elseif info.alert_code == WAZUH_ALERTS_CODE.NETWORK_INTERFACE_ADDED then
      msg = i18n('alert_messages.wazuh_network_interface_added', {
         host = info.asset_info.ip,
         ifid = info.asset_info.ifid,
         key = info.asset_info.key,
         iface = info.new_network_interface_info.name,
      })
   end
   tprint(msg)
   return msg
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_system_error.format(ifid, alert, alert_type_params)
   tprint(alert_type_params)
   return formatAlertMsg(alert_type_params.info or {})
end

-- #######################################################

return alert_system_error
