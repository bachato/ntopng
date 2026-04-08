/*
 *
 * (C) 2013-26 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* ****************************************** */

/* @brief Returns a table of traffic and alert statistics for the currently selected local network.  Lua: network.getNetworkStats() → table */
static int ntop_network_get_network_stats(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  NetworkStats* ns = c ? c->network : NULL;

  if (ns) {
    lua_newtable(vm);
    ns->lua(vm);
  } else
    lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Selects the active local network by its numeric ID for subsequent network.* calls in this Lua VM; pass nil to deselect.  Lua: network.select(network_id) → nil */
static int ntop_select_local_network(lua_State* vm) {
  u_int32_t local_network_id = (u_int32_t)-1;
  NetworkInterface* iface = getCurrentInterface(vm);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (lua_type(vm, 1) == LUA_TNIL)
    local_network_id = (u_int32_t)-1;
  else {
    if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK)
      return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
    local_network_id = (u_int32_t)lua_tointeger(vm, 1);
  }

  if (iface)
    getLuaVMUservalue(vm, network) = iface->getNetworkStats(local_network_id);

  // lua_pop(vm, 1); /* Cleanup the Lua stack */
  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Returns alerts matching given filter criteria for the currently selected local network.  Lua: network.getAlerts(params_table) → table */
static int ntop_network_get_alerts(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);

  return ntop_get_alerts(vm, c->network);
}

/* ****************************************** */

/* @brief Initializes the network check context for the given CIDR entity value, resolving it to a NetworkStats object for subsequent network.* calls.  Lua: network.checkContext(cidr_string) → boolean */
static int ntop_network_check_context(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  char* entity_val;
  bool ret = false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((entity_val = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((c->network == NULL) ||
      (strcmp(c->network->getEntityValue().c_str(), entity_val)) != 0) {
    NetworkInterface* iface = getCurrentInterface(vm);
    u_int32_t network_id = ntop->getLocalNetworkId(entity_val);

    if (!iface || (network_id == (u_int32_t)-1) ||
        ((c->network = iface->getNetworkStats(network_id)) == NULL)) {
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Could not set context for network %s", entity_val);
    } else
      ret = true;
  } else
    ret = true;

  lua_pushboolean(vm, ret);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Retrieves a cached alert context value for the current network by key and periodicity index.  Lua: network.getCachedAlertValue(key, periodicity) → string */
static int ntop_network_get_cached_alert_value(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  NetworkStats* ns = c ? c->network : NULL;
  char* key;
  std::string val;
  ScriptPeriodicity periodicity;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ns) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((periodicity = (ScriptPeriodicity)lua_tointeger(vm, 2)) >=
      MAX_NUM_PERIODIC_SCRIPTS)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  val = ns->getAlertCachedValue(std::string(key), periodicity);
  lua_pushstring(vm, val.c_str());

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Stores a cached alert context value for the current network by key, value, and periodicity index.  Lua: network.setCachedAlertValue(key, value, periodicity) → nil */
static int ntop_network_set_cached_alert_value(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);
  NetworkStats* ns = c ? c->network : NULL;
  char *key, *value;
  ScriptPeriodicity periodicity;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  if (!ns) return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  if ((key = (char*)lua_tostring(vm, 1)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((value = (char*)lua_tostring(vm, 2)) == NULL)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TNUMBER) != CONST_LUA_OK)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));
  
  if ((periodicity = (ScriptPeriodicity)lua_tointeger(vm, 3)) >=
      MAX_NUM_PERIODIC_SCRIPTS)
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  if ((!key) || (!value))
    return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_NO_RETURN_VALUE));

  ns->setAlertCacheValue(std::string(key), std::string(value), periodicity);
  lua_pushnil(vm);

  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* ****************************************** */

/* @brief Stores a triggered alert record in the alert database for the currently selected local network.  Lua: network.storeTriggeredAlert(alert_table) → nil */
static int ntop_network_store_triggered_alert(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);

  return (
      ntop_store_triggered_alert(vm, c->network, 1 /* 1st argument of vm */));
}

/* ****************************************** */

/* @brief Marks a previously triggered alert for the current network as resolved/released.  Lua: network.releaseTriggeredAlert(alert_table) → nil */
static int ntop_network_release_triggered_alert(lua_State* vm) {
  NtopngLuaContext* c = getLuaVMContext(vm);

  return (ntop_release_triggered_alert(vm, c->network, 1));
}

/* ****************************************** */

/* @brief Resets the inter-network traffic matrix counters for the current network (Pro only).  Lua: network.resetTrafficBetweenNets() → nil */
static int ntop_network_reset_traffic_between_nets(lua_State* vm) {
#ifdef NTOPNG_PRO
  NtopngLuaContext* c = getLuaVMContext(vm);
  NetworkStats* ns = c ? c->network : NULL;

  if (ns) ns->resetTrafficBetweenNets();
#endif

  lua_pushnil(vm);
  return (ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ONE_RETURN_VALUE));
}

/* **************************************************************** */

static luaL_Reg _ntop_network_reg[] = {
    /* Public User Scripts API, documented at
       doc/src/api/lua_c/network_checks/network.lua */
    {"select", ntop_select_local_network},
    {"getNetworkStats", ntop_network_get_network_stats},
    {"resetTrafficBetweenNets", ntop_network_reset_traffic_between_nets},

    /* END Public API */

    {"getCachedAlertValue", ntop_network_get_cached_alert_value},
    {"setCachedAlertValue", ntop_network_set_cached_alert_value},
    {"storeTriggeredAlert", ntop_network_store_triggered_alert},
    {"releaseTriggeredAlert", ntop_network_release_triggered_alert},
    {"getAlerts", ntop_network_get_alerts},
    {"checkContext", ntop_network_check_context},

    {NULL, NULL}};

luaL_Reg* ntop_network_reg = _ntop_network_reg;
