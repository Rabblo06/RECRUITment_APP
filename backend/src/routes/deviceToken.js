import express from "express";
import User from "../models/User.js";
import { requireAuth } from "../middleware/auth.js"; // adjust if path differs

const router = express.Router();

// Save FCM token for logged-in user
router.post("/device-token", requireAuth, async(req, res) => {
    try {
        const { fcmToken } = req.body;
        if (!fcmToken) {
            return res.status(400).json({ message: "Missing fcmToken" });
        }

        await User.findByIdAndUpdate(req.user.id, { fcmToken });
        return res.json({ ok: true });
    } catch (err) {
        console.error("Save FCM token error:", err);
        return res.status(500).json({ message: "Failed to save device token" });
    }
});

export default router;