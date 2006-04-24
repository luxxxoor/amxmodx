#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <dbi>

new Handle:g_DbInfo
new g_QueryNum

public plugin_init()
{
	register_plugin("SQLX Test", "1.0", "BAILOPAN")
	register_srvcmd("sqlx_test_normal", "SqlxTest_Normal")
	register_srvcmd("sqlx_test_thread", "SqlxTest_Thread")
	register_srvcmd("sqlx_test_old1", "SqlxTest_Old1")
	
	new configsDir[64]
	get_configsdir(configsDir, 63)
	
	server_cmd("exec %s/sql.cfg", configsDir)
	server_exec()
}

public plugin_cfg()
{
	new host[64]
	new user[64]
	new pass[64]
	new db[64]
	
	get_cvar_string("amx_sql_host", host, 63)
	get_cvar_string("amx_sql_user", user, 63)
	get_cvar_string("amx_sql_pass", pass, 63)
	get_cvar_string("amx_sql_db", db, 63)
	
	g_DbInfo = SQL_MakeDbTuple(host, user, pass, db)
}

/**
 * Note that this function works for both threaded and non-threaded queries.
 */
PrintQueryData(Handle:query)
{
	new columns = SQL_NumColumns(query)
	new rows = SQL_NumResults(query)
	
	server_print("Query columns: %d rows: %d", columns, rows)
	
	new num
	new row
	new str[32]
	new cols[2][32]
	SQL_FieldNumToName(query, 0, cols[0], 31)
	SQL_FieldNumToName(query, 1, cols[1], 31)
	while (SQL_MoreResults(query))
	{
		num = SQL_ReadResult(query, 0)
		SQL_ReadResult(query, 1, str, 31)
		server_print("[%d]: %s=%d, %s=%s", row, cols[0], num, cols[1], str)
		SQL_NextRow(query)
		row++
	}
}

/**
 * Handler for when a threaded query is resolved.
 */
public GetMyStuff(failstate, Handle:query, error[], errnum, data[], size)
{
	server_print("Resolved query %d at: %f", data[0], get_gametime())
	if (failstate)
	{
		if (failstate == TQUERY_CONNECT_FAILED)
		{
			server_print("Connection failed!")
		} else if (failstate == TQUERY_QUERY_FAILED) {
			server_print("Query failed!")
		}
		server_print("Error code: %d (Message: ^"%s^")", errnum, error)
	} else {
		PrintQueryData(query)
	}
}

/**
 * Starts a threaded query.
 */
public SqlxTest_Thread()
{
	new query[512]
	new data[1]
	
	data[0] = g_QueryNum
	format(query, 511, "SELECT * FROM gaben")
	
	server_print("Adding to %d queue at: %f", g_QueryNum, get_gametime())
	SQL_ThreadQuery(g_DbInfo, "GetMyStuff", query, data, 1)
	
	g_QueryNum++
}

/**
 * Does a normal query.
 */
public SqlxTest_Normal()
{
	new errnum, error[255]
	
	new Handle:db = SQL_Connect(g_DbInfo, errnum, error, 254)
	if (!db)
	{
		server_print("Query failure: [%d] %s", errnum, error)
		return
	}
	
	new Handle:query = SQL_PrepareQuery(db, "SELECT * FROM gaben")
	if (!SQL_Execute(query))
	{
		errnum = SQL_QueryError(query, error, 254)
		server_print("Query failure: [%d] %s", errnum, error)
		SQL_FreeHandle(query)
		SQL_FreeHandle(db)
		return
	}

	PrintQueryData(query)	
	
	SQL_FreeHandle(query)
	SQL_FreeHandle(db)
}

/**
 * Wrapper for an old-style connection.
 */
Sql:OldInitDatabase()
{
	new host[64]
	new user[64]
	new pass[64]
	new db[64]
	
	get_cvar_string("amx_sql_host", host, 63)
	get_cvar_string("amx_sql_user", user, 63)
	get_cvar_string("amx_sql_pass", pass, 63)
	get_cvar_string("amx_sql_db", db, 63)
	
	new error[255]
	new Sql:sql = dbi_connect(host, user, pass, db, error, 254)
	if (sql < SQL_OK)
	{
		server_print("Connection failure: %s", error)
		return SQL_FAILED
	}
	
	return sql
}

/**
 * Tests index-based lookup
 */
public SqlxTest_Old1()
{
	new Sql:sql = OldInitDatabase()
	if (sql < SQL_OK)
		return
		
	new Result:res = dbi_query(sql, "SELECT * FROM gaben")
	
	if (res == RESULT_FAILED)
	{
		new error[255]
		new code = dbi_error(sql, error, 254)
		server_print("Result failed! [%d]: %s", code, error)
	} else if (res == RESULT_NONE) {
		server_print("No result set returned.")
	} else {
		new cols[2][32]
		new str[32]
		dbi_field_name(res, 1, cols[0], 31)
		dbi_field_name(res, 2, cols[1], 31)
		new row, num
		while (dbi_nextrow(res) > 0)
		{
			num = dbi_field(res, 1)
			dbi_field(res, 2, str, 31)
			server_print("[%d]: %s=%d, %s=%s", row, cols[0], num, cols[1], str)
			row++
		}
		dbi_free_result(res)
	}
		
	dbi_close(sql)
}

public plugin_end()
{
	SQL_FreeHandle(g_DbInfo)
}
