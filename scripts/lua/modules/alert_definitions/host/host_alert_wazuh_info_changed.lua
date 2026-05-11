--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local host_alert_keys = require("host_alert_keys")

-- Import the classes library.
local alert_creators = require("alert_creators")
local classes = require("classes")
-- Make sure to import the Superclass!
local alert = require("alert")
local mitre = require "mitre_utils"
local alert_entities = require("alert_entities")

-- ##############################################

local host_alert_wazuh_info_changed = classes.class(alert)

host_alert_wazuh_info_changed.meta = {
	alert_key = host_alert_keys.host_alert_wazuh_info_changed,
	i18n_title = "alerts_dashboard.wazuh_info_changed",
	icon = "fas fa-fw fa-arrow-circle-up",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.discovery,
      mitre_technique = mitre.technique.system_info_discovery,
      mitre_id = "T1082"
   },
}

-- ##############################################

function host_alert_wazuh_info_changed:init(ifid, info)
	-- Call the parent constructor
	self.super:init()

	self.alert_type_params = {
		ifid = ifid,
		info = info,
	}
end

-- ##############################################

local function formatAlertMsg(info)
	local msg = i18n('alert_messages.wazuh_asset_info_changed')
   local changes_list = ""
   if not info then
      return msg
   end
   if info.new_open_ports and #info.new_open_ports > 0 then
      msg = string.format("%s[Num. New Open Ports: %d]", msg, #info.new_open_ports)
      local tmp_list = ""
      for _, value in pairs(info.new_open_ports) do
         tmp_list = string.format("%s%s,", tmp_list, tostring(value))
      end
      tprint(tmp_list)
      changes_list = string.format("%s- New Open Ports: %s\n", changes_list, tmp_list:sub(1, -2))
   end
   if info.process_changed and #info.process_changed > 0 then
      msg = string.format("%s[Num. Changed Processes: %d]", msg, #info.process_changed)
      local tmp_list = ""
      for _, value in pairs(info.process_changed) do
         tmp_list = string.format("%s%s (port %s) <i class='fa-solid fa-arrow-right'></i> %s, ", tmp_list, value.old_process or "", tostring(value.port), value.new_process or "")
      end
      changes_list = string.format("%s- Changed Processes: %s\n", changes_list, tmp_list:sub(1, -3))
   end
   if info.old_ports_no_longer_open and #info.old_ports_no_longer_open > 0 then
      msg = string.format("%s[Num. No Longer Open Ports: %d]", msg, #info.old_ports_no_longer_open)
      local tmp_list = ""
      for _, value in pairs(info.old_ports_no_longer_open) do
         tmp_list = string.format("%s%s,", tmp_list, tostring(value))
      end
      changes_list = string.format("%s- No Longer Open Ports: %s\n", changes_list, tmp_list:sub(1, -2))
   end
   if info.network_interface_removed and #info.network_interface_removed > 0 then
      msg = string.format("%s[Num. Net. Interfaces Removed: %d]", msg, #info.network_interface_removed)
      local tmp_list = ""
      for _, value in pairs(info.network_interface_removed) do
         tmp_list = string.format("%s%s,", tmp_list, tostring(value))
      end
      changes_list = string.format("%s- Net. Interfaces Removed: %s\n", changes_list, tmp_list:sub(1, -2))
   end
   if info.network_interface_added and #info.network_interface_added > 0 then
      msg = string.format("%s[Num. New Net. Interfaces: %d]", msg, #info.network_interface_added)
      local tmp_list = ""
      for _, value in pairs(info.network_interface_added) do
         tmp_list = string.format("%s%s,", tmp_list, tostring(value))
      end
      changes_list = string.format("%s- New Net. Interfaces: %s\n", changes_list, tmp_list:sub(1, -2))
   end
   
   if not isEmptyString(changes_list) then
      msg = string.format("%s\n%s", msg, changes_list)
   end
	return msg
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_wazuh_info_changed.format(ifid, alert, alert_type_params)
	return formatAlertMsg(alert_type_params.info or {})
end

-- #######################################################

return host_alert_wazuh_info_changed
