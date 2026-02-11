import express from "express";
import User from "../models/User.js";
import { requireAuth, requireManagerOrAdmin } from "../middleware/auth.js";


const router = express.Router();

router.get("/", requireAuth, requireManagerOrAdmin, async(req, res) => {
    const users = await User.find({ role: "staff" }).select("_id username role createdAt");
    res.json(users);
});

export default router;