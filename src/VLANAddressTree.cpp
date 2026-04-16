/*
 *
 * (C) 2017-26 - ntop.org
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

/* **************************************** */

VLANAddressTree::VLANAddressTree(ndpi_void_fn_t data_free_func,
                                 bool use_locking) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  free_func = data_free_func;
  lock_enabled = use_locking;
  tree = new (std::nothrow) AddressTree*[MAX_NUM_VLAN];
  memset(tree, 0, sizeof(AddressTree*) * MAX_NUM_VLAN);
  num_addresses = 0;
}

/* **************************************** */

VLANAddressTree::~VLANAddressTree() {
  for (int i = 0; i < MAX_NUM_VLAN; i++)
    if (tree[i]) delete tree[i];

  delete[] tree;
}

/* **************************************** */

/* Create a per-VLAN AddressTree if not present
 * Note: AddressTree has lock disabled to avoid double-locks (VLANAddressTree takes care of that). */
static inline AddressTree* getOrCreate(AddressTree**& tree, u_int16_t vlan_id,
                                       ndpi_void_fn_t free_func) {
  if (!tree[vlan_id])
    tree[vlan_id] = new (std::nothrow) AddressTree(true, free_func,
                                                   false /* do not use lock */);
  return tree[vlan_id];
}

/* **************************************** */

bool VLANAddressTree::addAddress(u_int16_t vlan_id, char* _net,
                                 const int16_t user_data) {
  vlan_id &= 0xFFF; /* Make sure we use 12 bits */

  if (lock_enabled) updateLock.wrlock(__FILE__, __LINE__);
  AddressTree* t = getOrCreate(tree, vlan_id, free_func);
  bool ret = false;
  if (t) {
    num_addresses++;
    ret = t->addAddress(_net, user_data);
  }
  if (lock_enabled) updateLock.unlock(__FILE__, __LINE__);

  return ret;
}

/* **************************************** */

bool VLANAddressTree::addVLANAddressAndData(u_int16_t vlan_id,
                                            const char* _what,
                                            void* user_data) {
  vlan_id &= 0xFFF; /* Make sure we use 12 bits */

  if (lock_enabled) updateLock.wrlock(__FILE__, __LINE__);
  AddressTree* t = getOrCreate(tree, vlan_id, free_func);
  bool ret = false;
  if (t) {
    num_addresses++;
    ret = t->addAddressAndData(_what, user_data);
  }
  if (lock_enabled) updateLock.unlock(__FILE__, __LINE__);

  return ret;
}

/* **************************************** */

bool VLANAddressTree::addAddresses(u_int16_t vlan_id, char* net,
                                   const int16_t user_data) {
  vlan_id &= 0xFFF; /* Make sure we use 12 bits */

  if (lock_enabled) updateLock.wrlock(__FILE__, __LINE__);
  AddressTree* t = getOrCreate(tree, vlan_id, free_func);
  bool ret = false;
  if (t) {
    num_addresses++;
    ret = t->addAddresses(net, user_data);
  }
  if (lock_enabled) updateLock.unlock(__FILE__, __LINE__);

  return ret;
}

/* **************************************** */

int16_t VLANAddressTree::findAddress(u_int16_t vlan_id, int family, void* addr,
                                     u_int8_t* network_mask_bits) {
  vlan_id &= 0xFFF; /* Make sure we use 12 bits */

  if (lock_enabled) updateLock.rdlock(__FILE__, __LINE__);
  int16_t ret = tree[vlan_id]
                    ? tree[vlan_id]->findAddress(family, addr, network_mask_bits)
                    : -1;
  if (lock_enabled) updateLock.unlock(__FILE__, __LINE__);

  return ret;
}

/* **************************************** */

int16_t VLANAddressTree::findMac(u_int16_t vlan_id, const u_int8_t addr[]) {
  vlan_id &= 0xFFF; /* Make sure we use 12 bits */

  if (lock_enabled) updateLock.rdlock(__FILE__, __LINE__);
  int16_t ret = tree[vlan_id] ? tree[vlan_id]->findMac(addr) : -1;
  if (lock_enabled) updateLock.unlock(__FILE__, __LINE__);

  return ret;
}

/* **************************************** */

void* VLANAddressTree::findAndGetData(u_int16_t vlan_id, IpAddress* ipa) {
  vlan_id &= 0xFFF; /* Make sure we use 12 bits */

  if (lock_enabled) updateLock.rdlock(__FILE__, __LINE__);
  void* ret = tree[vlan_id] ? tree[vlan_id]->matchAndGetData(ipa) : NULL;
  if (lock_enabled) updateLock.unlock(__FILE__, __LINE__);

  return ret;
}

/* **************************************** */
