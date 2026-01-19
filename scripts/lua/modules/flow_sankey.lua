--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
local flow_data = require "flow_data"
local format_utils = require "format_utils"
local flow_data_preset = require "flow_data_preset"
local format_utils = require "format_utils"

-- ##########################################

local root_id = "root"
local other_id = "other"
local separator = " | "
local flow_sankey = {}

-- ##########################################

local function findLink(source_node_id, target_node_id, links)
   for position, values in pairs(links) do
      if (values.source_node_id == source_node_id) and
	 (values.target_node_id == target_node_id) then
	 return position, values
      end
   end
   return nil
end

-- ##########################################

local function findNode(node_id, nodes)
   for _, values in pairs(nodes) do
      if values.node_id == node_id then return true end
   end
   return false
end

-- ##########################################

local function addRootNode(nodes, query)
   local node_id = root_id
   local key = root_id
   local id = string.format("%s_%s", key, node_id)

   -- root node already there, skipping
   for _, value in pairs(nodes) do
      if (value.node_id == id) then return nodes end
   end
   -- Format the root node
   local label = query.root.formatter(query.root.id)
   local link = nil

   nodes[#nodes + 1] = {node_id = id, label = label, link = link}
   return nodes
end

-- ##########################################

-- This function push each node given to the nodes table
local function unifyNodes(new_nodes, nodes, query, max_nodes_per_level)
   -- Iterate all the nodes
   for key, values in pairsByKeys(new_nodes or {}) do
      local current_nodes_per_level = 0
      for node_id, node_value in pairsByValues(values or {}, rev) do
	 -- Get the formatter if available
	 local formatted_data, node_link =
	    flow_data_preset.getFormattedDataAndLink(key, node_id, values)
	 local label = node_id
	 current_nodes_per_level = current_nodes_per_level + 1
	 if (formatted_data ~= node_id) then
	    label = formatted_data
	 end
	 if key == root_id then
	    nodes = addRootNode(nodes, query)
	 else
	    -- Checking for the others node
	    if max_nodes_per_level and
	       (current_nodes_per_level > max_nodes_per_level) then
	       if current_nodes_per_level == max_nodes_per_level + 1 then
		  -- Add the others node
		  nodes[#nodes + 1] = {
		     node_id = string.format("%s_%s", key, other_id),
		     label = i18n("others")
		  }
	       end
	       goto continue
	    end

	    local id = string.format("%s_%s", key, node_id)
	    -- Check if the node is already present, in case skip
	    for _, value in pairs(nodes) do
	       if (value.node_id == id) then
		  goto continue
	       end
	    end

	    nodes[#nodes + 1] = {
	       node_id = id,
	       label = label,
	       link = node_link
	    }
	 end
	 ::continue::
      end
   end
end

-- ##########################################

-- This function push each node given to the nodes table
local function unifyLinks(new_links, links, nodes)
   for key, values in pairs(new_links or {}) do
      local linked_nodes_keys = split(key, separator)
      for link_id, link_value in pairs(values or {}) do
	 local update_link = false
	 local linked_nodes = split(link_id, separator)
	 local source_node_id = string.format("%s_%s", linked_nodes_keys[1],
					      linked_nodes[1])
	 local target_node_id = string.format("%s_%s", linked_nodes_keys[2],
					      linked_nodes[2])
	 if not findNode(source_node_id, nodes) then
	    -- Node not found, it means that it's been transformed into the others node
	    source_node_id = string.format("%s_%s", linked_nodes_keys[1],
					   other_id)
	    update_link = true
	 end
	 if not findNode(target_node_id, nodes) then
	    -- Node not found, it means that it's been transformed into the others node
	    target_node_id = string.format("%s_%s", linked_nodes_keys[2],
					   other_id)
	    update_link = true
	 end

	 if update_link then
	    -- Search for the link, it could be already present
	    local position = nil
	    local already_available_link = nil
	    position, already_available_link =
	       findLink(source_node_id, target_node_id, links)
	    if position then
	       -- Link found update the value
	       already_available_link.value =
		  already_available_link.value + link_value
	       already_available_link.label =
		  format_utils.bytesToSize(already_available_link.value)
	       links[position] = already_available_link
	       -- Skip the add, already updated
	       goto continue
	    end
	 end

	 -- TODO: do not hardcode the bytes formatter
	 links[#links + 1] = {
	    source_node_id = source_node_id,
	    target_node_id = target_node_id,
	    value = link_value,
	    label = format_utils.bytesToSize(link_value)
	 }
	 ::continue::
      end
   end
end

-- ##########################################

-- @brief This function updates the weight of each node
-- @param stats List, containing all the values returned from the DB
-- @param query List, containing useful data, like where conditions, ecc
--              (e.g. see: scripts/lua/pro/rest/v2/get/as/as_table.lua) 
-- @return a list of nodes and links for the requested data
local function updateNodesAndLinks(stats, query)
   local nodes = {}
   local links = {}
   -- Iterate all the stats
   for _, values in pairs(stats or {}) do
      local total_value = 0
      -- First get the weight of the link, it's needed to update the nodes and links
      if (values["total_bytes"]) then
	 total_value = values["total_bytes"]
      else
	 for key, value in pairs(values or {}) do
	    if type(value) == "number" then
	       -- Calculate the value of the link
	       total_value = total_value + value
	    end
	 end
      end

      -- Update the nodes & the links by iterating the query, 
      -- so we know the order of the nodes
      local link_key = nil
      local general_link_key = nil
      for position, query_key in pairs(query.select_query or {}) do
	 -- Skip nil values
	 local column_name = query_key
	 if (query.rename_key_field and query.rename_key_field[position]) then
	    column_name = query.rename_key_field[position]
	 end
	 local value = values[column_name]
	 if value and type(value) == "string" then
	    local column_info = flow_data_preset.getColumn(column_name)
	    -- it's a node, so add to the list of nodes if not present,
	    -- if present update the value
	    if not nodes[column_name] then
	       nodes[column_name] = {}
	    end
	    if column_info.formatter and
	       column_info.formatter.column_dependent then
	       value = string.format("%s|%s", values[column_info.formatter
						     .column_dependent], value)
	    end
	    if not nodes[column_name][value] then
	       nodes[column_name][value] = 0
	    end
	    nodes[column_name][value] =
	       nodes[column_name][value] + total_value
	    -- Now we know the node, add the key to the link key
	    -- This is a trick to identify the nodes and links,
	    -- for example in case of multiple queries
	    if not general_link_key then
	       general_link_key = column_name
	    else
	       general_link_key = general_link_key .. separator ..
		  column_name
	    end
	    -- Same thing for the link
	    if not link_key then
	       link_key = value
	    else
	       link_key = link_key .. separator .. value
	    end
	 end
      end

      -- Requested to handle the root node
      if (query.root) then
	 -- Add the root to the nodes
	 if not nodes[root_id] then
	    nodes[root_id] = {[root_id] = 0}
	 end
	 nodes[root_id][root_id] = nodes[root_id][root_id] + total_value

	 -- Now add it to the links
	 if query.root.add_root_first then
	    link_key = "root" .. separator .. link_key
	    general_link_key = "root" .. separator .. general_link_key
	 else -- By default add to the end
	    link_key = link_key .. separator .. "root"
	    general_link_key = general_link_key .. separator .. "root"
	 end
      end

      local general_link_key_split = split(general_link_key, separator)
      local link_key_split = split(link_key, separator)

      -- Now iterate all the splitted keys, to create a link for each element
      -- e.g   src_asn | transit_asn | my_asn   we need to create 2 links:
      --     src_asn -> transit_asn
      --     transit_asn -> my_asn
      for i = 2, #general_link_key_split do
	 local all_links_id = general_link_key_split[i - 1] .. separator ..
	    general_link_key_split[i]
	 local link_id = link_key_split[i - 1] .. separator ..
	    link_key_split[i]

	 -- If not available create the link
	 if (not links[all_links_id]) then
	    links[all_links_id] = {}
	 end
	 if (not links[all_links_id][link_id]) then
	    links[all_links_id][link_id] = 0
	 end

	 -- Update the total
	 links[all_links_id][link_id] =
	    links[all_links_id][link_id] + total_value
      end
   end

   return nodes, links
end

-- ##########################################

-- @brief Given a list of queries to be run, it will generate a sankey
-- @param queries Queries to run
-- @param max_nodes_per_level number, representing the maximum number of nodes per level
--                            in case the number is surpassed, the "Other" node is added
-- @return a list composed by nodes and links
function flow_sankey.generateSankey(queries, max_nodes_per_level, isHistorical)
   -- In case of multiple queries, run each query one by one,
   -- then merge the data.
   -- In case the rename_key_field and each queries search for different data,
   -- the nodes from different queries are going to be recognized as different
   -- and so the data are not going to be merged
   local nodes = {}
   local links = {}

   if not isHistorical then interface.aggregateASNFlows() end

   for _, query in pairs(queries) do
      local table_stats = flow_data.getStats({query})
      local single_query_nodes = {}
      local single_query_links = {}
      single_query_nodes, single_query_links =
	 updateNodesAndLinks(table_stats, query, true)
      unifyNodes(single_query_nodes, nodes, query, max_nodes_per_level)
      unifyLinks(single_query_links, links, nodes)
   end

   return nodes, links
end

-- ##########################################

return flow_sankey
