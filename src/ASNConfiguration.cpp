/*
 *
 * (C) 2013-25 - ntop.org
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
#include "flow_checks_includes.h"

/* ***************************************************** */

ASNConfiguration::ASNConfiguration() { }

/* ***************************************************** */

ASNConfiguration::~ASNConfiguration() { }

/* ***************************************************** */

void ASNConfiguration::reloadASNConfiguration(char *key) {
  std::set<std::string> new_tree;
  loadConfiguration(&new_tree, key);

  /* Swap address trees */
  if (!new_tree.empty()) {
    tree_shadow = tree;
    tree = new_tree;
  }
}

/* ***************************************************** */

bool ASNConfiguration::findASN(char *asn) {
  std::set<std::string> cur_tree (tree); /* must use this as tree can be swapped */
  std::set<std::string>::iterator it;

  if (cur_tree.find(std::string(asn)) != cur_tree.end()) {
    return (true);
  }

  return (false);
}

/* ***************************************************** */

void ASNConfiguration::loadConfiguration(std::set<std::string> *tree, char *key) {
  char *rsp = NULL;
  Redis *redis = ntop->getRedis();
  u_int actual_len = redis->len(key);

  if (actual_len++ /* ++ for the \0 */ > 0 &&
      (rsp = (char *)malloc(actual_len)) != NULL) {
    redis->get(key, rsp, actual_len);
    /* Get a list of ASNs separated by commas */
    std::string asnStr(rsp);
    char charToRemove = ' ';

    /* Remove the spaces between the IPs */
    asnStr.erase(std::remove(asnStr.begin(), asnStr.end(), charToRemove), asnStr.end());

    /* Now iterate the string */
    std::stringstream asnList(asnStr);
    std::string asn;
    while (std::getline(asnList, asn, ',')) {
      std::pair<std::set<std::string>::iterator,bool> ret;

      ret = tree->insert(asn);
      if (!ret.second) {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to add ASN in ASNConfiguration [ASN: %s]", asn.c_str());
      }
    }

    if (rsp) free(rsp);
  }
}

/* ***************************************************** */

void ASNConfiguration::debugPrint(char *list_name) {
  for (const std::string& str : tree) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s] ASN Element: %s", list_name, (char *) str.c_str());
  }
}

/* ***************************************************** */
