--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local template_utils = require "template_utils"

local info = ntop.getInfo()
local page_utils = require("page_utils")
sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.about, {
   product = info.product
})
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

template_utils.render("pages/vue_page.template", {
   vue_page_name = "PageTest",
   page_context = json.encode({
      ifid = interface.getId(),
      csrf = ntop.getRandomCSRFValue()
   })
})
-- print(ntop.getASNameFromId(15169))
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
