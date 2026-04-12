const sql = require("mssql");

const rawServer = process.env.DB_SERVER || "";
const [serverHost, instanceName] = rawServer.split("\\");
const dbPort = process.env.DB_PORT ? Number(process.env.DB_PORT) : undefined;

const dbConfig = {
  server: serverHost || rawServer,
  port: dbPort,
  database: process.env.DB_DATABASE,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  options: {
    trustServerCertificate: true,
    encrypt: false,
    instanceName: dbPort ? undefined : (instanceName || undefined)
  }
};

let pool;

async function getPool() {
  if (!pool) {
    pool = await sql.connect(dbConfig);
  }
  return pool;
}

module.exports = { sql, getPool };
