/*
 *
 * (C) 2013-26 - ntop.org
 *
 *!
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

/* **************************************************** */

const char* SQLiteDB::getEngineName() { return "SQLite"; }

/* **************************************************** */

SQLiteDB::SQLiteDB(NetworkInterface* _iface) : SQLiteStoreManager(_iface) {
  char filePath[MAX_PATH + 256];

  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);

  /* Note: SQLite no longer used only for alerts (e.g. assets), however
   * we keep the path containing 'alerts' for backward compatibility*/

  /* Create the directories needed to keep the database */
  snprintf(filePath, sizeof(filePath), "%s/%d/alerts/", ntop->get_working_dir(),
           _iface->get_id());
  ntop->fixPath(filePath);
  Utils::mkdir_tree(filePath);

  /* Prepare the database path */
  snprintf(filePath, sizeof(filePath), "%s/%d/alerts/%s",
           ntop->get_working_dir(), _iface->get_id(),
           ALERTS_STORE_DB_FILE_NAME);
  ntop->fixPath(filePath);

  /* Initialize the database */
  store_initialized = init(filePath) == 0 ? true : false;
  if (!store_initialized)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to initialize store %s",
                                 filePath);

  store_opened = openStore() == 0 ? true : false;
  if (!store_opened)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to open store %s",
                                 filePath);
}

/* **************************************************** */

SQLiteDB::~SQLiteDB() {
  if (db) sqlite3_close(db);
}

/* **************************************************** */

int SQLiteDB::openStore() {
  int rc;

  if (!store_initialized) return 1;

  m.lock(__FILE__, __LINE__);

  rc = execFile(ALERTS_STORE_SCHEMA_FILE_NAME);
  rc |= execFile(ALERTS_VIEW_STORE_SCHEMA_FILE_NAME);

  m.unlock(__FILE__, __LINE__);

  return rc;
}
