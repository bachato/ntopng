--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_minimal()

local prefs = ntop.getPrefs()

local dbname = (prefs.clickhouse_dbname or '')

-- read the db activities to notify the user about what is going on in the database

print [[
  <div class="container-narrow">

  <style type="text/css">
      body {
        padding-top: 40px;
        padding-bottom: 40px;
        background-color: #f5f5f5;
   }

      .please-wait {
        max-width: 600px;
        padding: 9px 29px 29px;
        margin: 0 auto 20px;
        background-color: #fff;
        border: 1px solid #e5e5e5;
        -webkit-border-radius: 5px;
           -moz-border-radius: 5px;
                border-radius: 5px;
          -webkit-box-shadow: 0 1px 2px rgba(0,0,0,.05);
       -moz-box-shadow: 0 1px 2px rgba(0,0,0,.05);
      box-shadow: 0 1px 2px rgba(0,0,0,.05);
   }
      .please-wait .please-wait-heading,

    </style>

<div class="container please-wait">
  <div style="text-align: center; vertical-align: middle">
]]

addLogoSvg()

print[[
  </div>
  <div>
<br>
]]

print(" "..i18n("please_wait_page.waiting_for_db_msg", {dbname=dbname}))

print[[
  </div>
<br>
  <div>]]

local host

if not isEmptyString(_GET["referer"]) then
  host = getHttpUrlPrefix().._GET["referer"]
else
  host = _SERVER["HTTP_HOST"] .. ntop.getHttpPrefix() .. "/lua/index.lua"
end

print[[</div>
</div> <!-- /container -->

<script type="text/javascript">
var intervalID = setInterval(
  function() {
   window.location.replace("]] print(host) print[[");
  },
  5000);
</script>
</body>
</html>
]]
