--
-- (C) 2013-25 - ntop.org
--

local ndpi_utils = {}

-- ##############################################

local function sql_escape(s)
   return (s or ""):gsub("'", "\\'")
end

-- ##############################################

-- Create a l7_protocols table with nDPI protocol information, to be used
-- by Grafana for queries.
function ndpi_utils.insertDBProtocols()
   if not hasClickHouseSupport() then return end

   local protos = interface.getnDPIProtocols()
   if not protos then return end

   local values = {}

   for proto_name, proto_id_str in pairs(protos) do
      local proto_id  = tonumber(proto_id_str)
      if proto_id then
         local cat       = ntop.getnDPIProtoCategory(proto_id)
         local cat_id    = (cat and cat.id)   or 0
         local cat_name  = (cat and cat.name) or ""
         local breed     = interface.getnDPIProtoBreed(proto_id) or ""

         values[#values + 1] = string.format("(%d,'%s',%d,'%s','%s')",
            proto_id,
            sql_escape(proto_name),
            cat_id,
            sql_escape(cat_name),
            sql_escape(breed))
      end
   end

   if #values == 0 then return end

   interface.execSQLWrite("TRUNCATE TABLE l7_protocols")

   local sql = "INSERT INTO l7_protocols (PROTO_ID, PROTO_NAME, CATEGORY_ID, CATEGORY_NAME, BREED) VALUES "
      .. table.concat(values, ",")

   interface.execSQLWrite(sql)
end

-- ##############################################

return ndpi_utils
