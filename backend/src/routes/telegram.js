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
        text,
    });

    if (!data || data.ok !== true) {
        throw new Error((data && data.description) ? data.description : "Telegram send failed");
    }
    return data;
}

// POST /telegram/check
router.post("/check", requireAuth, async(req, res) => {
    try {
        const {
            type, // "checkin" | "checkout"
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

        const t = String(type || "").toLowerCase();

        // ✅ Simple check-in message
        if (t === "checkin") {
            const msg = `${staffName} check in`;
            await sendTelegram(msg);
            return res.json({ ok: true });
        }

        // ✅ Full checkout message
        const msg =
            `👤 Staff: ${staffName} (${staffId})
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
        return res.json({ ok: true });
    } catch (e) {
        return res.status(500).json({
            message: "Telegram failed",
            error: e && e.message ? e.message : String(e),
        });
    }
});

export default router;