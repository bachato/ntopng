/*
 *
 * (C) 2013-26 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#ifndef _TAGS_CONFIGURATION_H
#define _TAGS_CONFIGURATION_H

#include "ntop_includes.h"

/*
 * TagsConfiguration manages host-tag bitmaps.
 *
 * Data is stored in-memory in VLANAddressTree
 * and stored in redis for persistency (ntopng.prefs.host_tags_bitmap.<serialization_key>)
 */
class TagsConfiguration {
 private:
  VLANAddressTree tree;

  void store_to_redis(const char *key, u_int64_t bitmap);
  void add_to_tree(const char *key, u_int64_t bitmap);

 public:
  TagsConfiguration() = default;
  ~TagsConfiguration() = default;

  /* Scan Redis for ntopng.prefs.host_tags_bitmap.<iface_id>_* keys and initialize the tree at startup */
  void loadFromRedis(int iface_id);

  /* Direct lookups (radix tree) */
  u_int64_t getTags(const u_int8_t mac[6]);
  u_int64_t getTags(IpAddress *ip, u_int16_t vlan_id);

  /* Look up a tag bitmap by serialization key (return 0 when not found) */
  u_int64_t getTags(const char *key);

  void setTags(const char *key, u_int64_t bitmap);
};

#endif /* _TAGS_CONFIGURATION_H */
