local sqlite3 = require('lsqlite3')
local DB = sqlite3.open('server.db')
sql = {
	db = DB
}

function sql.createPlayer(key)
	local created = false
	local sql = ([[
		SELECT pkey FROM players WHERE pkey=%q;
	]]):format(key)
	DB:exec(sql, function(_, cols)
		if cols>0 then
			created = true
		end
	end)
	if not created then
		sql = ([[
			INSERT INTO players (pkey) VALUES(%q)
		]]):format(key)
		if DB:exec(sql) ~= sqlite3.OK then
			return false, DB:errmsg()
		end
	end
	return true
end

function sql.addColumn(col, type)
	local sql = ([[
		ALTER TABLE players ADD %s %s;
	]]):format(col, type)
	local ecode = DB:exec(sql)
	if ecode == sqlite3.OK then
		return true
	else
		local err = DB:errmsg()
		if err:startsWith('duplicate')then
			return true
		else
			return false, err
		end
	end
end

function sql.getData(pkey, rows)
	local sql = ('SELECT %s FROM players WHERE pkey=%q'):format(rows, pkey)
	for row in DB:nrows(sql)do
		local _, c = rows:gsub(',','')
		if c >= 0 then
			return row
		else
			return row[rows]
		end
	end
end

function sql.insertData(pkey, rows, values)
	local dat = ''
	if #rows ~= #values then
		return false
	end
	for i=1, #rows do
		dat = dat + ('%s = %q'):format(rows[i], values[i])
		if #rows ~= i then
			dat = dat + ', '
		end
	end
	local sql = ([[
		UPDATE players SET %s WHERE pkey=%q;
	]]):format(dat, pkey)
	local ecode = DB:exec(sql)
	if ecode ~= sqlite3.OK then
		return false, DB:errmsg()
	end
	return true
end

function sql.close()
	return DB:close()
end

function sql.init()
	local ecode = DB:exec[[
	CREATE TABLE IF NOT EXISTS players (
			id                     INTEGER PRIMARY KEY AUTOINCREMENT,
			onlineTime             INTEGER default 0,
	  	pkey                   VARCHAR(64) NOT NULL,
			lastWorld              VARCHAR(64) NOT NULL default "default",
			spawnX                 float(24) default 0,
			spawnY                 float(24) default 0,
			spawnZ                 float(24) default 0,
			spawnYaw               float(24) default 0,
			spawnPitch             float(24) default 0,
			lastIP                 VARCHAR(15) NOT NULL default "0.0.0.0"
	);]]
	if ecode ~= sqlite3.OK then
		error(DB:errmsg())
	else
		assert(sql.addColumn('onlineTime', 'INTEGER default 0'))
		assert(sql.addColumn('lastIP', 'VARCHAR(15) NOT NULL default "0.0.0.0"'))
	end
	return true
end
