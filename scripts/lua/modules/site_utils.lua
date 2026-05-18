--
-- (C) 2013-26 - ntop.org
--
-- Required modules for site management
require("ntop_utils")
local json = require("dkjson")
local rest_utils = require("rest_utils")

-- Module definition - this module provides utilities for managing sites
local site_utils = {}

-- Redis cache keys configuration for persistent storage
local REDIS_HASH_NAME = "ntopng.prefs.sites" -- Stores all sites as hash: id -> JSON
local REDIS_COUNTER_KEY = "ntopng.prefs.sites_counter" -- Auto-increment counter for site IDs

-- Configuration limits for sites
local MAX_DESCRIPTION_SIZE = 256 -- Maximum character length for site descriptions
local MAX_PROFILES_NUM = 1024 -- Maximum number of sites allowed in the system

-- Default site configuration - system reserved site used when no site is assigned
-- This site cannot be modified or deleted and serves as a fallback
local DEFAULT_SITE = {
	id = "0", -- System reserved ID (always string "0")
	name = "Default", -- Display name
	description = "", -- Optional description
	longitude = 0, -- Geographic coordinates (0,0 by default)
	latitude = 0,
	reserved = true, -- Flag indicating this is a system-reserved site
}

-- ##############################################
-- Private Helper Functions
-- ##############################################

-- Validates all parameters for a Site before creation or modification
-- This comprehensive validation ensures data integrity and prevents duplicates
local function validate_site(site, existing_sites, ignore_name_duplication)
   if not (site) then
      return false, "Invalid data"
   end

   -- Step 1: Validate site name
	if type(site.site_name) ~= "string" then
		return false, "Invalid name"
	end

	-- Check name length constraints (1-16 characters)
	if #site.site_name == 0 or #site.site_name > 32 then
		return false, "Invalid name, max characters: 32"
	end

	-- Validate name format (alphanumeric only)
	if not site.site_name:match("^[%w À-ÖØ-öø-ÿ]+$") then
		return false, "Invalid name, illegal character"
	end

	-- Convert to lowercase for case-insensitive duplicate checking
	local name_lower = site.site_name:lower()

	-- Step 2: Validate description
	if type(site.site_description) ~= "string" then
		return false, "Invalid description"
	end

	-- Step 3: Validate networks not needed, the validation is already done
   --         by the http_lint

	-- Check description length limit
	if #site.site_description > MAX_DESCRIPTION_SIZE then
		return false, "Invalid description, max characters: 256"
	end

	-- Step 4: Validate geographic coordinates
	if not tonumber(site.latitude) or not tonumber(site.longitude) then
		return false, "Invalid coordinates"
	end

	-- Convert to numbers for range validation
	site.latitude = tonumber(site.latitude)
	site.longitude = tonumber(site.longitude)

	-- Validate latitude range (-90 to 90 degrees)
	if site.latitude < -90 or site.latitude > 90 then
		return false, "Invalid latitude"
	end

	-- Validate longitude range (-180 to 180 degrees)
	if site.longitude < -180 or site.longitude > 180 then
		return false, "Invalid longitude"
	end

	-- Step 5: Check for duplicate site names (unless explicitly disabled for edits)
	if not ignore_name_duplication then
		for _, site in pairs(existing_sites) do
			if site.name:lower() == name_lower then
				return false, "Site " .. site.name .. " already exists"
			end
		end
	end

	-- All validation passed
	return true
end

-- ##############################################

local sites_list_cache = nil

-- Retrieves all Sites from Redis cache and prepares them for use
-- This function always includes the default site and merges it with user-defined sites
local function get_sites_from_cache()
	if sites_list_cache == nil then
		local sites_list = {}

		-- Always include the default site as ID "0"
		sites_list["0"] = site_utils.get_default_site()

		-- Retrieve all user-defined sites from Redis
		local current_defined_sites = ntop.getHashAllCache(REDIS_HASH_NAME) or {}

		-- Process each site JSON string from Redis
		for _, site in pairs(current_defined_sites) do
			-- Decode JSON string to Lua table
			local uncompressed_json = json.decode(site) or nil
			if uncompressed_json then
				-- Store site using its string ID as key for easy lookup
				sites_list[tostring(uncompressed_json.id)] = uncompressed_json
			end
		end

		sites_list_cache = sites_list
		return sites_list
	else
		return sites_list_cache
	end
end

-- ##############################################
-- Public API Functions
-- ##############################################

-- Returns the system default Site
-- Used as fallback when no site is assigned to a flow device
function site_utils.get_default_site()
	return DEFAULT_SITE
end

-- ##############################################

-- Returns all Sites as a sorted array for display purposes
-- Sites are sorted by ID in ascending order, with default site always included
function site_utils.getSites()
	local sites = get_sites_from_cache()

	local result = {}

	-- Iterate through sites sorted by ID (ascending order)
	for id, site in pairsByKeys(sites, asc) do
		local record = {}
		record["id"] = tostring(site.id) -- Ensure ID is string
		record["name"] = site.name -- Site display name
		record["description"] = site.description -- Optional description
		record["networks"] = site.networks -- List of networks associated with the Site
		record["latitude"] = site.latitude -- Geographic coordinates
		record["longitude"] = site.longitude
		record["reserved"] = site.reserved -- System-reserved flag

		-- Add to result array
		result[#result + 1] = record
	end

	return result
end

-- ##############################################

-- Edits an existing Site with new parameters
-- Performs validation and updates the site in Redis storage
function site_utils.editSite(site)
	-- Get current sites for validation
	local existing_sites = get_sites_from_cache()

	-- Validate and normalize the site ID
	if site.id and tonumber(site.id) then
		site.id = tostring(site.id) -- Convert to string for consistency
	else
		return rest_utils.consts.err.edit_site_failed, "Invalid ID"
	end

	-- Ensure the site exists
	if not existing_sites[site.id] then
		return rest_utils.consts.err.edit_site_failed, "Invalid Site"
	end

	local old_site = existing_sites[site.id]

	-- Handle empty coordinate values (default to 0)
	if isEmptyString(site.latitude) then
		site.latitude = 0
	end
	if isEmptyString(site.longitude) then
		site.longitude = 0
	end

	-- Skip duplicate name check if the name hasn't changed (edit vs rename scenario)
	local ignore_name_duplication = old_site.name == site.site_name

	-- Validate all input parameters
	local res, msg = validate_site(site, existing_sites, ignore_name_duplication)

	if res then
		-- Delete old entry first to ensure clean update
		ntop.delHashCache(REDIS_HASH_NAME, site.id)

		-- Create updated site object
		local site_json = {
			id = tostring(site.id),
			name = site.site_name,
			description = site.site_description,
         networks = site.site_networks,
			latitude = site.latitude,
			longitude = site.longitude,
		}

		-- Store updated site in Redis
		ntop.setHashCache(REDIS_HASH_NAME, id, json.encode(site_json))
	else
		return rest_utils.consts.err.edit_site_failed, msg -- Return validation error
	end

	local success_msg = "Site edited successfully"
	return rest_utils.consts.success.ok, success_msg
end

-- ##############################################

-- Creates a new Site with auto-generated ID
-- Validates input, checks system limits, and stores in Redis
function site_utils.addSite(site)
	-- Get current site counter from Redis (or default to 1)
	local current_count = tonumber(ntop.getCache(REDIS_COUNTER_KEY)) or 1

	-- Check system limit before proceeding
	if current_count + 1 > MAX_PROFILES_NUM then
		return rest_utils.consts.err.add_site_failed,
			"Adding a site would exceed maximum limit (" .. MAX_PROFILES_NUM .. "). Current: " .. current_count
	end

	-- Get existing sites for validation
	local existing_sites = get_sites_from_cache()

	-- Handle empty coordinate values
	if isEmptyString(site.latitude) then
		site.latitude = 0
	end
	if isEmptyString(site.longitude) then
		site.longitude = 0
	end

	-- Validate all input parameters
	local res, msg = validate_site(site, existing_sites, false)

	if res then
		-- Generate new site ID (use current counter value)
		local site_id = tostring(current_count)

		-- Create site object
		local site_json = {
			id = site_id,
			name = site.site_name,
			description = site.site_description,
			networks = site.site_networks,
			latitude = site.latitude,
			longitude = site.longitude,
		}

		-- Store new site in Redis
		ntop.setHashCache(REDIS_HASH_NAME, site_id, json.encode(site_json))

		-- Increment counter for next site
		ntop.setCache(REDIS_COUNTER_KEY, current_count + 1)
	else
		return rest_utils.consts.err.add_site_failed, msg -- Return validation error
	end

	local success_msg = "Site added successfully"
	return rest_utils.consts.success.ok, success_msg
end

-- ##############################################

-- Deletes an Site by ID
-- Note: Does not check if the site is currently in use by any flow devices
function site_utils.deleteSite(id)
	-- Get current sites to verify existence
	local existing_sites = get_sites_from_cache()

	-- Validate and normalize ID
	if id then
		id = tostring(id)
	else
		return rest_utils.consts.err.delete_site_failed, "Invalid ID"
	end

	-- Check if site exists before deletion
	if existing_sites[id] then
		-- Remove site from Redis
		ntop.delHashCache(REDIS_HASH_NAME, id)
	else
		return rest_utils.consts.err.delete_site_failed, "Invalid Site"
	end

	local success_msg = "Site deleted successfully"
	return rest_utils.consts.success.ok, success_msg
end

-- ##############################################

function site_utils.mapHostToSite(ip)
   -- TODO: Implement this function, given an IP returns the site associated to it
   return site_utils.get_default_site()
end

-- ##############################################

-- Export the module for use in other Lua files
return site_utils
