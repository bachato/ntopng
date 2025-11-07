--
-- (C) 2017-24 - ntop.org
--

local dhcp_utils = {}

-- ##############################################

local function getDhcpRangesKey(ifid)
  return string.format("ntopng.prefs.ifid_%u.dhcp_ranges", ifid)
end

-- ##############################################

function dhcp_utils.listRanges(ifid)
  local ranges_str = ntop.getPref(getDhcpRangesKey(ifid))
  local ranges = string.split(ranges_str, ",") or {ranges_str}
  local res = {}

  for _, range in ipairs(ranges) do
    local r = string.split(range, "%-")

    if r and #r == 2 then
      res[#res + 1] = {r[1], r[2]}
    end
  end

  return res
end

-- ##############################################

function dhcp_utils.editRanges(ifid, ranges_to_remove, ranges_to_add)
  local cur_ranges = ntop.getPref(getDhcpRangesKey(ifid))
  local num_ranges = 0

  if ranges_to_remove == "" then ranges_to_remove = nil end
  if ranges_to_add == "" then ranges_to_add = nil end
  if cur_ranges == "" then cur_ranges = nil end

  ranges_to_remove = swapKeysValues(string.split(ranges_to_remove or '', ',') or {ranges_to_remove})
  ranges_to_add = swapKeysValues(string.split(ranges_to_add or '', ',') or {ranges_to_add})
  cur_ranges = string.split(cur_ranges or '', ',') or {cur_ranges}
  num_ranges = #cur_ranges
  cur_ranges = swapKeysValues(cur_ranges)

  for k in pairs(ranges_to_remove) do
    if not ranges_to_add[k] then
      cur_ranges[k] = nil
    end
  end

  for k in pairs(ranges_to_add) do
    num_ranges = num_ranges + 1
    cur_ranges[k] = num_ranges
  end

  local sorted_ranges = {}

  -- NOTE: the sort order in cur_ranges should stay unchanged
  for k in pairsByValues(cur_ranges, asc) do
    sorted_ranges[#sorted_ranges + 1] = k
  end

  dhcp_utils.setRanges(ifid, table.concat(sorted_ranges, ','))
end

-- ##############################################

function dhcp_utils.setRanges(ifid, ranges_str)
  ntop.setPref(getDhcpRangesKey(ifid), ranges_str)
  interface.reloadDhcpRanges()
end

-- ##############################################

-- Validates if a DHCP range bound is valid
-- @param lan_config The LAN configuration table
-- @param lan_network The LAN network address
-- @param broadcast The broadcast address
-- @param range_bound The range bound to validate (first_ip or last_ip)
-- @return true if valid, false otherwise
local function isValidDhcpRangeBound(lan_config, lan_network, broadcast, range_bound)
   local ipv4_utils = require "ipv4_utils"
   return (lan_config.ip ~= range_bound) and
      (broadcast ~= range_bound) and ipv4_utils.includes(lan_network, lan_config.netmask, range_bound)
end

-- ##############################################

-- Validates if a DHCP range is valid
-- @param lan_config The LAN configuration table
-- @param first_ip The first IP in the DHCP range
-- @param last_ip The last IP in the DHCP range
-- @return true if valid, false otherwise
function dhcp_utils.isValidDhcpRange(lan_config, first_ip, last_ip)
   local ipv4_utils = require "ipv4_utils"
   local lan_network = ntop.networkPrefix(lan_config.ip, ipv4_utils.netmask(lan_config.netmask))
   local broadcast = ipv4_utils.broadcast_address(lan_config.ip, lan_config.netmask)

   if isValidDhcpRangeBound(lan_config, lan_network, broadcast, first_ip) and
      isValidDhcpRangeBound(lan_config, lan_network, broadcast, last_ip) then
      local base_ip = ipv4_utils.maskIp(lan_config.ip, lan_config.netmask)
      return (ipv4_utils.cmp(base_ip,   first_ip) < 0) and
             (ipv4_utils.cmp(broadcast, last_ip) > 0) and
             (ipv4_utils.cmp(first_ip,  last_ip) <= 0)
   end

   return false
end

-- ##############################################

-- Validates if a DHCP range is valid for any of the provided LAN configurations
-- @param lan_configs Array of LAN configuration tables
-- @param first_ip The first IP in the DHCP range
-- @param last_ip The last IP in the DHCP range
-- @return true if valid for at least one LAN, false otherwise
function dhcp_utils.hasValidDhcpRange(lan_configs, first_ip, last_ip)
   for _, lan_config in ipairs(lan_configs) do
      if dhcp_utils.isValidDhcpRange(lan_config, first_ip, last_ip) then
         return true
      end
   end

   return false
end

-- ##############################################

return dhcp_utils
