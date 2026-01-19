--
-- (C) 2013-26 - ntop.org
--

--
-- Volatile (across ntopng restarts) in-memory cache
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local json = require "dkjson"

local cache_utils = {}

-- ##############################################

-- Loaded at startup
function cache_utils.initialize()
   local basename = "ntopng.cachedsnmp."
   local len  = string.len(basename)

   -- system
   local keys = ntop.getKeysCache(basename.."*.system")

   for k,_ in pairs(keys or {}) do
      local system = json.decode(ntop.getCache(k))
      local ipaddr = string.sub(k, len+1, string.len(k)-7)

      cache_utils.sethostname(ipaddr, system.name)
   end

   -- interfaces
   keys = ntop.getKeysCache(basename.."*.interfaces")

   for k,_ in pairs(keys or {}) do
      local ifaces = json.decode(ntop.getCache(k))
      local ipaddr = string.sub(k, len+1, string.len(k)-11)

      -- tprint("Loading "..ipaddr)
      for if_id,if_v in pairs(ifaces) do
	 local val = if_v.alias or if_v.ifname or if_v.name

	 if(val ~= nil) then
	    cache_utils.setifname(ipaddr, if_id, val)
	 end
      end
   end

   -- Debug
   -- tprint(ntop.dumpLuaCache())
end

-- ##############################################

function cache_utils.gethostname(ipaddr)
   return(ntop.getLuaCache("host."..ipaddr))
end

-- ##############################################

function cache_utils.sethostname(ipaddr, name)
   if(debugme) then
      tprint("cache_utils.sethostname(".. ipaddr .. ", ".. name..")")
   end
   
   return(ntop.setLuaCache("host."..ipaddr, name or ipaddr))
end

-- ##############################################

function cache_utils.getifname(ipaddr, ifid)
   local ret = ntop.getLuaCache("iface."..ipaddr.."@"..ifid)

   if(isEmptyString(ret)) then
      ret = ifid
   end

   if(debugme) then
      tprint(debug.traceback())
      tprint("cache_utils.getifname(".. ipaddr .. ", ".. ifid..") = "..ret)
   end
   
   return(ret)
end

-- ##############################################

function cache_utils.setifname(ipaddr, ifid, ifname)
   if(ifname == nil) then
      tprint("cache_utils.setifname() ERROR on interface "..ipaddr.." / "..ifid)
      tprint(debug.traceback())
   end
   
   return(ntop.setLuaCache("iface."..ipaddr.."@"..ifid, ifname or ifid))
end

-- ##############################################

function cache_utils.set(key, val)
   ntop.setLuaCache(key, val)
end

-- ##############################################

return cache_utils
