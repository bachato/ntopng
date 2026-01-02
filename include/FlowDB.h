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

#ifndef _FLOWDB_CLASS_H_
#define _FLOWDB_CLASS_H_

#include "ntop_includes.h"

class FlowDB : public DB {
 private:
  struct timeval lastUpdateTime;
  float exportRate;
  u_int64_t exportedFlows, lastExportedFlows;
  /* Multiple threads can inc in case of view interfaces */
  std::atomic<u_int32_t> droppedFlows;
  std::atomic<u_int32_t> queueDroppedFlows;
  u_int64_t checkpointExportedFlows;
  u_int32_t checkpointDroppedFlows, checkpointQueueDroppedFlows;

 public:
  FlowDB(NetworkInterface *_iface);
  virtual ~FlowDB(){};

  /* Failures enqueueing flows for export (NetworkInterface) */
  inline void incNumQueueDroppedFlows(u_int32_t num = 1) { queueDroppedFlows += num; };
  /* Failures dumping flows to the database (ClickHouseDB) */
  inline void incNumDroppedFlows(u_int32_t num = 1)      { droppedFlows += num;      };
  /* Flows successfully dumped */
  inline void incNumExportedFlows(u_int64_t num = 1)     { exportedFlows += num;     };

  inline u_int64_t getNumExportedFlows() const { return (exportedFlows); }
  inline u_int32_t getNumDroppedFlows()  const { return (queueDroppedFlows + droppedFlows); };
  void updateStats(const struct timeval *tv);
  void checkPointCounters(bool drops_only);

  virtual const char *getEngineName() { return "Unknown"; };
  virtual bool dumpFlow(time_t when, Flow *f, char *json) { return false; };
  virtual bool startDumpLoop() { return false; }

  virtual void archiveData(time_t epoch_begin, time_t epoch_end) {}

  virtual void lua(lua_State *vm, bool since_last_checkpoint);
  virtual void getStats(u_int64_t *flow_export_count, u_int64_t *flow_export_drops,
			u_int64_t *flow_export_rate, bool since_last_checkpoint);  
};

#endif /* _FLOWDB_CLASS_H_ */
