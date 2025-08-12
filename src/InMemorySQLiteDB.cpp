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

/* **************************************************** */

InMemorySQLiteDB::InMemorySQLiteDB() {
  if (sqlite3_open("::memory::", &db)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to created in memory databsse: %s",
                                 sqlite3_errmsg(db));
    db = NULL;
    throw "DB creation error";
  }
}

/* **************************************************** */

InMemorySQLiteDB::~InMemorySQLiteDB() {
  if(db) sqlite3_close(db);
}

/* **************************************************** */

struct SQLiteDataRetriever {
  lua_State *vm;
  u_int32_t current_offset;
};

static int process_sqlite_row(void *data, int argc, char **argv,
                              char **azColName) {
  SQLiteDataRetriever *ar = (SQLiteDataRetriever *) data;
  lua_State *vm = ar->vm;

  lua_newtable(vm);

  for (int i = 0; i < argc; i++)
    lua_push_str_table_entry(vm, azColName[i], argv[i]);

  lua_pushinteger(vm, ++ar->current_offset);
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  return 0;
}

/* **************************************************** */

int InMemorySQLiteDB::execSQLQuery(lua_State *vm, const char *sql) {
  int rc = SQLITE_ERROR;
  SQLiteDataRetriever ar;
  char *zErrMsg = NULL;

  lua_newtable(vm);

  ar.vm = vm, ar.current_offset = 0;
  rc = sqlite3_exec(db, sql, process_sqlite_row, (void *)&ar, &zErrMsg);

  if (rc != SQLITE_OK) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "SQL Error: %s\n%s", zErrMsg, sql);
    sqlite3_free(zErrMsg);
  }

  return (rc == SQLITE_OK ? 0 : -1);
}

/* **************************************************** */
