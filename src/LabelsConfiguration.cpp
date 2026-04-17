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

#include "ntop_includes.h"

/* ***************************************************** */

/*
 * Parse a serialization key (format: <ifid>_<addr_part>)
 * addr_part is a MAC (AA:BB:CC:DD:EE:FF) or an IP (<ip>@<vlan>)
 * and insert the bitmap into the in-memory tree.
 */
void LabelsConfiguration::add_to_tree(const char* key, u_int64_t bitmap) {
  const char* addr_part = strchr(key, '_');
  if (!addr_part) return;
  addr_part++;

  const char* at = strchr(addr_part, '@');
  if (!at) {
    /* Note: AddressTree::addAddress detects MAC addresses internally */
    tree.addAddress((u_int16_t)0, addr_part, (int64_t)bitmap);
  } else {
    char ip_buf[64];
    u_int len = (u_int)(at - addr_part);
    if (len >= sizeof(ip_buf)) return;
    memcpy(ip_buf, addr_part, len);
    ip_buf[len] = '\0';

    u_int16_t vlan_id = (u_int16_t)atoi(at + 1);
    tree.addAddress(vlan_id, (const char*)ip_buf, (int64_t)bitmap);
  }
}

/* ***************************************************** */

/* Store a label on redis */
void LabelsConfiguration::store_to_redis(const char* key, u_int64_t bitmap) {
  char redis_key[CONST_MAX_LEN_REDIS_KEY];
  char val_buf[32];
  Redis* redis = ntop->getRedis();

  snprintf(redis_key, sizeof(redis_key), HOST_LABELS_BITMAP_KEY, key);

  if (bitmap == 0)
    redis->del(redis_key);
  else {
    snprintf(val_buf, sizeof(val_buf), "%llu", (unsigned long long)bitmap);
    redis->set(redis_key, val_buf);
  }
}

/* ***************************************************** */

/* Load from redis all labels for the current interface */
void LabelsConfiguration::loadFromRedis(int iface_id) {
  char pattern[128];
  char** keys = NULL;
  int nkeys;
  Redis* redis = ntop->getRedis();

  snprintf(pattern, sizeof(pattern), "%s%d_*", HOST_LABELS_BITMAP_PREFIX, iface_id);
  nkeys = redis->keys(pattern, &keys);

  for (int i = 0; i < nkeys; i++) {
    char val_buf[32];

    if (redis->get(keys[i], val_buf, sizeof(val_buf)) == 0 &&
        val_buf[0] != '\0') {
      u_int64_t bitmap = (u_int64_t)strtoull(val_buf, NULL, 10);

      if (bitmap != 0) {
        const char* ser_key = keys[i] + strlen(HOST_LABELS_BITMAP_PREFIX);
        add_to_tree(ser_key, bitmap);
      }
    }

    if (keys[i]) free(keys[i]);
  }

  if (keys) free(keys);

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Loaded %d host label bitmaps (ifid = %d)",
                               nkeys, iface_id);
}

/* ***************************************************** */

u_int64_t LabelsConfiguration::getLabels(const char *key) {
  const char *addr_part;
  const char *at;
  char ip_buf[64];
  u_int len;
  u_int16_t vlan_id;
  int64_t val;

  if (!key || !key[0]) return 0;

  addr_part = strchr(key, '_');
  if (!addr_part) return 0;
  addr_part++;

  at = strchr(addr_part, '@');
  if (!at) {
    /* No '@' means MAC key (MAC_SERIALIZED_SHORT_KEY)
     * Note: _v4/_v6 suffix is ignored by sscanf */
    u_int8_t mac[6];
    Utils::parseMac(mac, addr_part);
    val = tree.findMac(0, mac);
    return (val == -1) ? 0 : (u_int64_t)val;
  }

  len = (u_int)(at - addr_part);
  if (len >= sizeof(ip_buf)) return 0;
  memcpy(ip_buf, addr_part, len);
  ip_buf[len] = '\0';

  vlan_id = (u_int16_t) atoi(at + 1);

  if (strchr(ip_buf, '.')) {
    struct in_addr a;
    if (inet_pton(AF_INET, ip_buf, &a) != 1) return 0;
    val = tree.findAddress(vlan_id, AF_INET, &a);
  } else {
    struct in6_addr a;
    if (inet_pton(AF_INET6, ip_buf, &a) != 1) return 0;
    val = tree.findAddress(vlan_id, AF_INET6, &a);
  }

  return (val == -1) ? 0 : (u_int64_t) val;
}

/* ***************************************************** */

u_int64_t LabelsConfiguration::getLabels(const u_int8_t mac[6]) {
  int64_t val = tree.findMac(0, mac);
  return (val == -1) ? 0 : (u_int64_t)val;
}

/* ***************************************************** */

u_int64_t LabelsConfiguration::getLabels(IpAddress *ip, u_int16_t vlan_id) {
  if (!ip) return 0;
  int64_t val;

  if (ip->isIPv4()) {
    u_int32_t a = ip->get_ipv4();
    val = tree.findAddress(vlan_id, AF_INET, &a);
  } else {
    const struct ndpi_in6_addr *a = ip->get_ipv6();
    if (!a) return 0;
    val = tree.findAddress(vlan_id, AF_INET6, (void *)a);
  }

  return (val == -1) ? 0 : (u_int64_t)val;
}

/* ***************************************************** */

void LabelsConfiguration::setLabels(const char* key, u_int64_t bitmap) {
  if (!key || !key[0]) return;

  add_to_tree(key, bitmap);
  store_to_redis(key, bitmap);
}

/* ***************************************************** */
