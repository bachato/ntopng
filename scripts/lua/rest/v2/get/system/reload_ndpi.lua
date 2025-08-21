--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "lua_utils_get"
local rest_utils = require "rest_utils"
local lists_utils = require "lists_utils"


-- #######################################

if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return 
end

-- #######################################

lists_utils.reloadLists()

rest_utils.answer(rest_utils.consts.success.ok)