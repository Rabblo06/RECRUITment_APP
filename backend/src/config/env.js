import fs from "fs";
import path from "path";
import dotenv from "dotenv";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(
    import.meta.url);
const __dirname = path.dirname(__filename);

// backend/.env is one level above src/
const envPath = path.join(__dirname, "..", "..", ".env");

dotenv.config({ path: envPath });

// Helpful logs (keep for now, remove later if you want)
console.log("ENV file path:", envPath);
console.log("ENV exists:", fs.existsSync(envPath));
console.log("ENV TELEGRAM_BOT_TOKEN loaded?", !!process.env.TELEGRAM_BOT_TOKEN);
console.log("ENV TELEGRAM_CHAT_ID loaded?", !!process.env.TELEGRAM_CHAT_ID);