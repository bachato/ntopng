--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local template_utils = require("template_utils")
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

local page = _GET["page"] or "overview"

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.assets)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- ######################################   

local base_url = ntop.getHttpPrefix() .. "/lua/assets.lua"
page_utils.print_navbar(i18n("assets"), base_url .. "?", {
    {
        active = page == "details" or page == nil,
        page_name = "details",
        label = i18n("details.details")
    }
})

-- ######################################    

local json_context = json.encode({
    ifid = interface.getId(),
    historical_available = hasClickHouseSupport(),
    csrf = ntop.getRandomCSRFValue(),
    is_admin = isAdministrator(),
    is_assets_collection_enabled = (ntop.getPref(
        'ntopng.prefs.enable_assets_collection') ~= '0')
})

template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageAssets",
    page_context = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
