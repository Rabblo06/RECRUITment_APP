import mongoose from "mongoose";
import bcrypt from "bcrypt";

// ✅ CHANGE THIS import if your file name/path is different
import User from "./src/models/User.js";

const MONGO_URI = process.env.MONGO_URI;
if (!MONGO_URI) {
    console.error("❌ Missing MONGO_URI env var");
    process.exit(1);
}

const username = "admin";
const password = "admin1234";

async function main() {
    await mongoose.connect(MONGO_URI);
    console.log("✅ Connected to Mongo");

    const hash = await bcrypt.hash(password, 10);

    // Update if exists, otherwise create
    const existing = await User.findOne({ username });

    if (existing) {
        existing.passwordHash = hash; // common field name in your project
        existing.role = existing.role || "admin";
        existing.suspended = false;
        await existing.save();
        console.log("✅ Updated admin password: admin / admin1234");
    } else {
        await User.create({
            username,
            passwordHash: hash,
            role: "admin",
            suspended: false,
        });
        console.log("✅ Created admin user: admin / admin1234");
    }

    await mongoose.disconnect();
}

main().catch(async(e) => {
    console.error("❌ Error:", e);
    try { await mongoose.disconnect(); } catch {}
    process.exit(1);
});