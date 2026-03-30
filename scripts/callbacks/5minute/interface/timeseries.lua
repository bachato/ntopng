--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

require "ntop_utils"
require "check_redis_prefs"
local ts_dump = require "ts_5min_dump_utils"

-- ########################################################

-- @brief Execute the timeseries dump for 5 min stats
--        if no high resolution Timeseries is requested
--        otherwise run this dump into the minute dump 

if not hasHighResolutionTs() then
  local when = os.time()
  local _ifname = interface.getName()
  local verbose = ntop.verboseTrace()

  ts_dump.run_5min_dump(_ifname, {
    isViewed = interface.isViewed(),
    isView = interface.isView(),
    id = interface.getId(),
    isSampledTraffic = interface.isSampledTraffic(),
    has_seen_ebpf_events = interface.hasEBPF()
  }, when, verbose)
end
