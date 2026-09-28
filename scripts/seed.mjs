import { Pool } from "pg";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SQL_PATH = join(__dirname, "..", "youpji", "data", "seed", "seed.sql");

const conn = process.env.DATABASE_URL;
if (!conn) {
  console.error("set DATABASE_URL");
  process.exit(1);
}

const pool = new Pool({ connectionString: conn });

async function main() {
  const sql = readFileSync(SQL_PATH, "utf8");
  const client = await pool.connect();
  try {
    // 分号拆分执行；只去掉“行注释”，不要因为语句前有注释就把整条语句丢掉
    const statements = sql
      .split(/;\s*(?:\r?\n|$)/)
      .map((s) =>
        s
          .split("\n")
          .filter((line) => !line.trim().startsWith("--"))
          .join("\n")
          .trim()
      )
      .filter((s) => s.length > 0);
    for (const st of statements) {
      await client.query(st + ";");
    }
    console.log("seed ok", statements.length, "statements");
  } finally {
    client.release();
    await pool.end();
  }
}
main().catch((e) => {
  console.error(e);
  process.exit(1);
});
