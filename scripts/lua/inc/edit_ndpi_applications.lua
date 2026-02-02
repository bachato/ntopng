--
-- (C) 2017-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template_utils = require "template_utils"
local protos_utils = require "protos_utils"
local json = require "dkjson"

local has_protos_file = protos_utils.hasProtosFile()
local context = {
   page_csrf = ntop.getRandomCSRFValue(),
   ifid = interface.getId(),
   has_protos_file = has_protos_file
}

template_utils.render("pages/vue_page.template", {
   vue_page_name = "PageEditApplications",
   page_context = json.encode(context)
})
