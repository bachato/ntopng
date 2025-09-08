--
-- (C) 2021-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" ..
                   package.path

-- Import the classes library.
local classes = require "classes"

require "lua_utils"
local alert_store = require "alert_store"
local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local alert_entities = require "alert_entities"
local format_utils = require "format_utils"
local tag_utils = require "tag_utils"

-- ##############################################

local as_alert_store = classes.class(alert_store)

-- ##############################################

function as_alert_store:init(args)
    self.super:init()

    if ntop.isClickHouseEnabled() then
        self._table_name = "as_alerts_view"
        self._write_table_name = "as_alerts"
        self._engaged_write_table_name = "engaged_as_alerts"
    else
        self._table_name = "as_alerts_view"
        self._write_table_name = "as_alerts"
        self._engaged_write_table_name = "mem_db.engaged_as_alerts"
    end

    self._alert_entity = alert_entities.as
end

-- ##############################################

function as_alert_store:_build_insert_query(alert, write_table, alert_status,
                                            extra_columns, extra_values)

    local asn = alert.entity_val
    local name = asn
    local alias = ""

    local insert_stmt = string.format("INSERT INTO %s " ..
                                          "(%salert_id, alert_status, require_attention, interface_id, tstamp, tstamp_end, severity, score, asn, name, alias, granularity, json) " ..
                                          "VALUES (%s%u, %u, %u, %d, %u, %u, %u, %u, %u, '%s', '%s', %u, '%s'); ",
                                      write_table, extra_columns, extra_values,
                                      alert.alert_id, alert_status,
                                      ternary(alert.require_attention, 1, 0),
                                      self:_convert_ifid(interface.getId()),
                                      alert.tstamp, alert.tstamp_end,
                                      map_score_to_severity(alert.score),
                                      alert.score, asn, self:_escape(name),
                                      self:_escape(alias), alert.granularity,
                                      self:_escape(alert.json))

    return insert_stmt
end

-- ##############################################

-- @brief Add filters according to what is specified inside the REST API
function as_alert_store:_add_additional_request_filters()
    -- Add filters specific to the system family
    local asn = _GET["asn"]

    self:add_filter_condition_list('asn', asn, 'number')
end

-- ##############################################

-- @brief Get info about additional available filters
function as_alert_store:_get_additional_available_filters()
    local filters = {asn = tag_utils.defined_tags.asn}

    return filters
end

-- ##############################################

-- @brief Performs a query for the top ASs by alert count
function as_alert_store:top_asn_historical()
    -- Preserve all the filters currently set
    local where_clause = self:build_where_clause()

    local q
    if ntop.isClickHouseEnabled() then
        q = string.format(
                "SELECT asn, count(*) count, name FROM %s WHERE %s GROUP BY asn, name ORDER BY count DESC LIMIT %u",
                self._table_name, where_clause, self._top_limit)
    else
        q = string.format(
                "SELECT asn, count(*) count, name FROM %s WHERE %s GROUP BY asn ORDER BY count DESC LIMIT %u",
                self._table_name, where_clause, self._top_limit)
    end

    local q_res = interface.alert_store_query(q) or {}

    return q_res
end

-- ##############################################

-- @brief Stats used by the dashboard
function as_alert_store:_get_additional_stats()
    local stats = {}
    stats.top = {}
    stats.top.asn = self:top_asn_historical()
    return stats
end

-- ##############################################

local RNAME = {
    -- ALIAS = { name = "alias", export = true},
    ASN = {name = "asn", export = true},
    AS_NAME = {name = "name", export = true},
    ALERT_NAME = {name = "alert_name", export = true},
    DESCRIPTION = {name = "description", export = true},
    MSG = {
        name = "msg",
        export = true,
        elements = {"name", "value", "description"}
    }
}

function as_alert_store:get_rnames() return RNAME end

-- @brief Convert an alert coming from the DB (value) to a record returned by the REST API
function as_alert_store:format_record(value, no_html)
    local record = self:format_json_record_common(value,
                                                  alert_entities.as.entity_id,
                                                  no_html)

    local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]),
                                                   no_html,
                                                   alert_entities.as.entity_id)
    local alert_fullname = alert_consts.alertTypeLabel(tonumber(
                                                           value["alert_id"]),
                                                       true, alert_entities.as
                                                           .entity_id)
    local alert_info = alert_utils.getAlertInfo(value)
    local msg = alert_utils.formatAlertMessage(ifid, value, alert_info)

    value.asn = value.asn or value.entity_val

    -- record[RNAME.ALIAS.name] = value.alias
    record[RNAME.ASN.name] = value.asn
    record[RNAME.AS_NAME.name] = format_utils.formatASN(value.asn)

    record[RNAME.ALERT_NAME.name] = alert_name

    if string.lower(noHtml(msg)) == string.lower(noHtml(alert_name)) then
        msg = ""
    end

    if no_html then msg = noHtml(msg) end

    record[RNAME.DESCRIPTION.name] = msg

    record[RNAME.MSG.name] = {
        name = noHtml(alert_name),
        fullname = alert_fullname,
        value = tonumber(value["alert_id"]),
        description = msg,
        configset_ref = alert_utils.getConfigsetAlertLink(alert_info)
    }

    return record
end

-- ##############################################

return as_alert_store
