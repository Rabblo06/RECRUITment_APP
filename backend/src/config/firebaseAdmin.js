import admin from "firebase-admin";
import fs from "fs";
import path from "path";

// Resolve serviceAccountKey.json from backend root
const serviceAccountPath = path.resolve(process.cwd(), "serviceAccountKey.json");

const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });
}

export default admin;