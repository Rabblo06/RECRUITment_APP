import express from "express";
import axios from "axios";
import { requireAuth } from "../middleware/auth.js";

const router = express.Router();

const BOT = process.env.TELEGRAM_BOT_TOKEN;
const CHAT = process.env.TELEGRAM_CHAT_ID;

async function sendTelegram(text) {
    if (!BOT || !CHAT) {
        throw new Error("Missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID in .env");
    }

    const url = `https://api.telegram.org/bot${BOT}/sendMessage`;

    const { data } = await axios.post(url, {
        chat_id: CHAT,
        text: text,
    });

    // Telegram returns { ok: true/false, ... }
    if (!data || data.ok !== true) {
        throw new Error((data && data.description) ? data.description : "Telegram send failed");
    }

    return data;
}

router.post("/check", requireAuth, async(req, res) => {
    try {
        const {
            type,
            staffId,
            staffName,
            offerId,
            venue,
            role,
            date,
            startTime,
            endTime,
            checkIn,
            checkOut,
            totalHours,
            amount,
        } = req.body;

        const msg =
            `🕒 ${(type || "").toUpperCase()}

👤 Staff: ${staffName} (${staffId})
🧾 Offer: ${offerId}

🏨 Venue: ${venue}
💼 Role: ${role}
📅 Date: ${date}
⏰ Shift: ${startTime} - ${endTime}

✅ Check-in: ${checkIn || "-"}
🏁 Check-out: ${checkOut || "-"}

⌛ Hours: ${totalHours ?? "-"}
💰 Amount: £${amount ?? "-"}`;

        await sendTelegram(msg);
        res.json({ ok: true });
    } catch (e) {
        res.status(500).json({ message: "Telegram failed", error: String(e.message || e) });
    }
});

export default router;