--
-- (C) 2019-24 - ntop.org
--
-- ##############################################
local flow_alert_keys = require "flow_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local blacklist_debug = 'ntopng.debug.alerts.blacklisted_flow'

-- ##############################################

local alert_flow_blacklisted = classes.class(alert)

-- ##############################################

alert_flow_blacklisted.meta = {
    alert_key = flow_alert_keys.flow_alert_blacklisted,
    i18n_title = "flow_checks_config.blacklisted",
    icon = "fas fa-fw fa-exclamation",

    has_victim = true,
    has_attacker = true
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param info A flow info table fetched with `flow.getBlacklistedInfo()`
-- @return A table with the alert built
function alert_flow_blacklisted:init()
    -- Call the parent constructor
    self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_flow_blacklisted.format(ifid, alert, alert_type_params)
    local is_cat_blacklisted = alert_type_params["cat_blacklisted"]

    local res = ""
    if is_cat_blacklisted then
        local href = string.format("<a href='%s/lua/admin/edit_categories.lua?tab=protocols'><i class='fas fa-cog'></i></a>", ntop.getHttpPrefix())
        res = string.format("%s", i18n("blacklisted_category", { config_href = href }))
    end

    return res
end

-- #######################################################

return alert_flow_blacklisted
