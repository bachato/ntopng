--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "ntop_utils"

local page_utils = require "page_utils"
local json = require "dkjson"
local template_utils = require("template_utils")
local checks = require "checks"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(
    page_utils.menu_entries.asn_configuration)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"]

page_utils.print_navbar(i18n("checks.asn_configuration"),
                        ntop.getHttpPrefix() ..
                            "/lua/admin/asn_configuration.lua", {
    {
        active = (page == nil or page == 'asn_configuration'),
        page_name = "asn_configuration",
        label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
            i18n("checks.asn_configuration") .. "\"></i>"
    }
})

local context = {ifid = interface.getId(), csrf = ntop.getRandomCSRFValue()}

local checks_config = checks.getConfigset()["config"]
local interface_config = checks_config["interface"]
local flow_config = checks_config["flow"]
local is_check_enabled = true

--[[
    if (flow_config) then
        -- Interface alerts
        if (flow_config["unexpected_dns"]) and (flow_config["unexpected_dns"]["all"]["enabled"]) or
            (flow_config["unexpected_ntp"]) and (flow_config["unexpected_ntp"]["all"]["enabled"]) or
            (flow_config["unexpected_smtp"]) and (flow_config["unexpected_smtp"]["all"]["enabled"]) or
            (flow_config["unexpected_gateway"]) and (flow_config["unexpected_gateway"]["all"]["enabled"]) or
            (flow_config["unexpected_dhcp"]) and (flow_config["unexpected_dhcp"]["all"]["enabled"]) then
            is_check_enabled = true
        end
    end
]]
context.is_check_enabled = is_check_enabled
local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageASNConfiguration",
    page_context = json_context

})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
