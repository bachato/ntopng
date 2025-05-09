--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Importing the libraries
require "lua_utils"
local page_utils = require "page_utils"
local template_utils = require "template_utils"
local json = require "dkjson"

sendHTTPContentTypeHeader('text/html')
-- Setting the right active menu
page_utils.print_header_and_set_active_menu_entry(
    page_utils.menu_entries.analyze_pcap)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- Printing navbar
page_utils.print_navbar(i18n("analyze_pcap"),
                        ntop.getHttpPrefix() .. "/lua/upload_pcap.lua", {
    {
        active = page == "overview" or not page,
        page_name = "overview",
        label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
            i18n("analyze_pcap") .. "\"></i>"
    }
})

local context = {
    csrf = ntop.getRandomCSRFValue(),
    pcap_interface = interface.isPcapDumpInterface()
}

local json_context = json.encode(context)

-- Rendering the vuejs page
template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageUploadPcap",
    page_context = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
