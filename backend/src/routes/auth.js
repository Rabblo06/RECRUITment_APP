import express from "express";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import User from "../models/User.js";
import { requireAuth, requireManagerOrAdmin } from "../middleware/auth.js";

const router = express.Router();

// ✅ Admin creates staff accounts (admin only)
router.post("/create-staff", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const { username, password, fullName, email, dob, managerId } = req.body;

        if (!username || !password) {
            return res.status(400).json({ message: "Username and password required" });
        }

        const exists = await User.findOne({ username });
        if (exists) return res.status(409).json({ message: "Username already exists" });

        const passwordHash = await bcrypt.hash(password, 10);

        // ✅ Ownership rule:
        // - manager creates staff => managerId = that manager
        // - admin creates staff => can pass managerId (optional)
        let ownerManagerId = null;
        if (req.user.role === "manager") ownerManagerId = req.user.id; // token has "id"
        if (req.user.role === "admin" && managerId) ownerManagerId = managerId;

        const user = await User.create({
            username,
            passwordHash,
            role: "staff",
            fullName: fullName || "",
            email: email || "",
            dob: dob || "",
            managerId: ownerManagerId,
            isActive: true,
        });

        return res.status(201).json({
            id: user._id.toString(),
            username: user.username,
            role: user.role,
            managerId: user.managerId,
        });
    } catch (err) {
        console.error("CREATE STAFF ERROR:", err);
        return res.status(500).json({ message: "Create staff failed" });
    }
});


// ✅ Login (admin / staff)
router.post("/login", async(req, res) => {
    try {
        const { username, password } = req.body || {};

        if (!username || !password) {
            return res.status(400).json({ message: "Username and password required" });
        }

        const user = await User.findOne({ username });
        if (!user) return res.status(401).json({ message: "Invalid credentials" });

        if (!user.passwordHash || typeof user.passwordHash !== "string") {
            return res.status(500).json({
                message: "User password is missing/corrupted. Recreate this user.",
            });
        }

        const ok = await bcrypt.compare(password, user.passwordHash);
        if (!ok) return res.status(401).json({ message: "Invalid credentials" });
        // 🚫 block suspended staff
        if (user.role === "staff" && user.isActive === false) {
            return res.status(403).json({
                code: "SUSPENDED",
                message: "Your account has been suspended. Please contact admin.",
            });
        }

        const token = jwt.sign({ id: user._id.toString(), username: user.username, role: user.role },
            process.env.JWT_SECRET, { expiresIn: "7d" }
        );

        return res.json({
            token,
            user: {
                id: user._id.toString(),
                username: user.username,
                role: user.role,
                isActive: user.isActive !== false,
            },
        });

    } catch (err) {
        console.error("LOGIN ERROR:", err);
        return res.status(500).json({ message: "Login failed" });
    }
});

// ✅ Admin creates manager accounts
router.post("/create-manager", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const { username, password, fullName, email, dob } = req.body;

        if (!username || !password) {
            return res.status(400).json({ message: "username and password required" });
        }

        const existing = await User.findOne({ username });
        if (existing) {
            return res.status(400).json({ message: "Username already exists" });
        }

        const passwordHash = await bcrypt.hash(password, 10);

        const user = await User.create({
            username,
            passwordHash,
            role: "manager",
            fullName: fullName || "",
            email: email || "",
            dob: dob || "",
            isActive: true,
        });

        return res.json({
            _id: user._id,
            username: user.username,
            role: user.role,
            fullName: user.fullName,
        });
    } catch (err) {
        return res.status(500).json({ message: err.message || "Server error" });
    }
});


export default router;