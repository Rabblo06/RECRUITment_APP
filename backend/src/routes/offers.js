import express from "express";
import Offer from "../models/offer.js";
import User from "../models/User.js";
import Placement from "../models/Placement.js";
import admin from "../config/firebaseAdmin.js";
import { requireAuth, requireManagerOrAdmin } from "../middleware/auth.js";

const router = express.Router();

function toIsoDay(d) {
    const dt = d instanceof Date ? d : new Date(d);
    if (Number.isNaN(dt.getTime())) return "";
    return dt.toISOString().slice(0, 10);
}

function hmToMin(hm) {
    if (!hm) return null;
    const s = String(hm).trim();
    const m = s.match(/^(\d{1,2}):(\d{2})$/);
    if (!m) return null;
    const h = Number(m[1]);
    const min = Number(m[2]);
    if (h < 0 || h > 23 || min < 0 || min > 59) return null;
    return h * 60 + min;
}

function overlap(aStart, aEnd, bStart, bEnd) {
    // overlaps if start < otherEnd AND end > otherStart
    return aStart < bEnd && aEnd > bStart;
}

/**
 * Send a push notification to one device token.
 * This won't crash your route if FCM fails.
 */
async function sendPush(token, title, body, data = {}) {
    if (!token) return;

    try {
        await admin.messaging().send({
            token,
            notification: { title, body },
            // data values MUST be strings
            data: Object.fromEntries(
                Object.entries(data).map(([k, v]) => [k, String(v)])
            ),
        });
    } catch (err) {
        console.error("FCM send error:", (err && err.message) ? err.message : err);
    }
}

// ✅ Admin sends offer (creates placement + offer)
router.post("/send", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const { userId, placement } = req.body;

        if (!userId || !placement) {
            return res.status(400).json({ message: "userId and placement required" });
        }

        // 🚫 block suspended staff from receiving offers
        const targetStaff = await User.findById(userId).select(
            "role isActive managerId fcmToken username fullName"
        );
        if (!targetStaff) return res.status(404).json({ message: "Staff not found" });
        if (targetStaff.role !== "staff")
            return res.status(400).json({ message: "Target user is not staff" });

        if (targetStaff.isActive === false) {
            return res.status(403).json({
                message: "This staff account is suspended. Reactivate to send offers.",
            });
        }

        // 🔒 manager ownership rule (optional but recommended)
        if (req.user.role === "manager") {
            if (!targetStaff.managerId || targetStaff.managerId.toString() !== String(req.user.id)) {
                return res.status(403).json({ message: "Forbidden: not your staff" });
            }
        }

        const force = !!(req.body && req.body.force);

        // Normalize incoming shift time
        const day = toIsoDay(placement.date);
        const newStart = hmToMin(placement.startTime);
        const newEnd = hmToMin(placement.endTime);

        if (!day || newStart === null || newEnd === null) {
            return res.status(400).json({
                message: "Valid date/startTime/endTime required (YYYY-MM-DD, HH:MM)",
            });
        }

        // If end <= start, treat as overnight shift (e.g., 22:00-06:00)
        let ns = newStart;
        let ne = newEnd;
        if (ne <= ns) ne += 24 * 60;

        // Find existing shifts for this staff (ignore cancelled/rejected)
        const existing = await Offer.find({
                userId,
                status: { $nin: ["cancelled", "rejected"] },
            })
            .populate("placementId")
            .sort({ createdAt: -1 })
            .limit(200);

        const conflicts = [];

        for (const o of existing) {
            const p = o.placementId;
            if (!p) continue;

            const pDay = toIsoDay(p.date);
            if (pDay !== day) continue;

            const es0 = hmToMin(p.startTime);
            const ee0 = hmToMin(p.endTime);
            if (es0 === null || ee0 === null) continue;

            let es = es0;
            let ee = ee0;
            if (ee <= es) ee += 24 * 60;

            if (overlap(ns, ne, es, ee)) {
                conflicts.push({
                    offerId: o._id.toString(),
                    status: o.status,
                    venue: p.venue || "",
                    date: pDay,
                    startTime: p.startTime || "",
                    endTime: p.endTime || "",
                });
            }
        }

        if (conflicts.length && !force) {
            return res.status(409).json({
                code: "CONFLICT",
                message: "Staff already has a booking at the same time.",
                conflicts,
            });
        }

        // ✅ map desktop fields -> Placement schema fields
        const createdPlacement = await Placement.create({
            venue: placement.venue || "",
            roleTitle: placement.roleTitle || placement.position || "",
            date: new Date(placement.date),
            startTime: placement.startTime || "",
            endTime: placement.endTime || "",

            hourlyRate: placement.hourlyRate !== undefined && placement.hourlyRate !== null ?
                placement.hourlyRate : 0,

            totalHours: placement.totalHours !== undefined && placement.totalHours !== null ?
                placement.totalHours : 0,

            addressLine: placement.addressLine || "",
            city: placement.city || "",
            postcode: placement.postcode || "",

            notes: placement.notes || placement.note || placement._note || "",
        });

        const offer = await Offer.create({
            userId,
            placementId: createdPlacement._id,
            status: "offered",
        });

        // 🔔 Send push to staff
        await sendPush(
            targetStaff.fcmToken,
            "New Offer",
            `${createdPlacement.roleTitle || "Shift"} • ${createdPlacement.venue || ""}`, { offerId: offer._id.toString() }
        );

        return res.json({ offerId: offer._id.toString() });
    } catch (err) {
        console.error("SEND OFFER ERROR:", err);
        return res.status(500).json({ message: err.message || "Send offer failed" });
    }
});

// ✅ Staff: get my offers (optional status filter)
router.get("/my", requireAuth, async(req, res) => {
    try {
        const status = req.query.status;
        const q = { userId: req.user.id };
        if (status) q.status = status;

        const offers = await Offer.find(q)
            .populate("placementId")
            .sort({ createdAt: -1 });

        res.json(offers);
    } catch (err) {
        console.error("GET MY OFFERS ERROR:", err);
        res.status(500).json({ message: "Failed to load offers" });
    }
});

// ✅ Staff: accept/reject offer
router.patch("/:id/respond", requireAuth, async(req, res) => {
    try {
        const { action } = req.body; // "accept" | "reject"

        const offer = await Offer.findById(req.params.id);
        if (!offer) return res.status(404).json({ message: "Offer not found" });

        if (offer.userId.toString() !== req.user.id) {
            return res.status(403).json({ message: "Not yours" });
        }

        if (action === "accept") offer.status = "user_accepted";
        else if (action === "reject") offer.status = "rejected";
        else return res.status(400).json({ message: "Invalid action" });

        await offer.save();
        res.json({ ok: true, status: offer.status });
    } catch (err) {
        console.error("RESPOND ERROR:", err);
        res.status(500).json({ message: "Failed to respond" });
    }
});

// ✅ Admin: pending confirmations
router.get("/pending", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const filter = { status: "user_accepted" };

        // ✅ Manager should only see offers for their own staff
        if (req.user.role === "manager") {
            const staffIds = await User.find({ role: "staff", managerId: req.user.id }).select("_id");
            filter.userId = { $in: staffIds.map((s) => s._id) };
        }

        const offers = await Offer.find(filter)
            .sort({ createdAt: -1 })
            .populate("userId", "username fullName managerId")
            .populate("placementId");

        return res.json(offers);
    } catch (err) {
        console.error("PENDING OFFERS ERROR:", err);
        return res.status(500).json({ message: err.message || "Server error" });
    }
});

// ✅ Admin: approve/reject
router.patch("/:id/decision", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const { decision } = req.body; // "approve" | "reject"

        const offer = await Offer.findById(req.params.id);
        if (!offer) return res.status(404).json({ message: "Offer not found" });

        if (decision === "approve") offer.status = "booking_confirmed";
        else if (decision === "reject") offer.status = "rejected";
        else return res.status(400).json({ message: "Invalid decision" });

        await offer.save();
        res.json({ ok: true, status: offer.status });
    } catch (err) {
        console.error("DECISION ERROR:", err);
        res.status(500).json({ message: "Failed to decide" });
    }
});

// ADMIN – edit pending or existing offer
router.put("/admin/offers/:id", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const offer = await Offer.findById(req.params.id).populate("placementId");
        if (!offer) return res.status(404).json({ message: "Offer not found" });

        if (!offer.placementId)
            return res.status(400).json({ message: "Placement missing" });

        const editable = ["offered", "pending", "pending_approval", "user_accepted"];
        if (!editable.includes(offer.status)) {
            return res.status(400).json({ message: "Cannot edit this offer" });
        }

        Object.assign(offer.placementId, req.body);
        await offer.placementId.save();

        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: "Edit failed" });
    }
});

// ✅ Staff: checkout -> mark offer completed (and store hours/amount)
// Business rule: calculate from scheduled shift start time (not from tap time)
router.post("/:id/checkout", requireAuth, async(req, res) => {
    try {
        const offer = await Offer.findById(req.params.id).populate("placementId");
        if (!offer) return res.status(404).json({ message: "Offer not found" });

        if (offer.userId.toString() !== req.user.id) {
            return res.status(403).json({ message: "Not yours" });
        }

        if (offer.status !== "booking_confirmed") {
            return res.status(400).json({ message: "Offer is not booking_confirmed" });
        }

        const p = offer.placementId;
        if (!p) return res.status(400).json({ message: "Placement missing" });

        // build Date from Placement.date + startTime ("HH:MM")
        const base = new Date(p.date);
        const m = String(p.startTime || "").trim().match(/^(\d{1,2}):(\d{2})$/);
        if (Number.isNaN(base.getTime()) || !m) {
            return res.status(400).json({ message: "Invalid placement start" });
        }

        const h = Number(m[1]);
        const min = Number(m[2]);
        const scheduledStart = new Date(
            base.getFullYear(),
            base.getMonth(),
            base.getDate(),
            h,
            min,
            0,
            0
        );

        const now = new Date();
        const minutes = Math.max(0, Math.floor((now.getTime() - scheduledStart.getTime()) / 60000));
        const totalHours = minutes / 60;

        const hourlyRate = Number(p.hourlyRate || p.payRate || p.rate || 0);
        const amount = totalHours * hourlyRate;

        // Save for admin/payroll
        if (!offer.checkInAt) offer.checkInAt = scheduledStart;
        offer.checkOutAt = now;
        offer.totalHoursWorked = Number(totalHours.toFixed(2));
        offer.amountWorked = Number(amount.toFixed(2));
        offer.completedAt = now;

        offer.status = "completed";
        await offer.save();

        return res.json({ ok: true, status: offer.status });
    } catch (err) {
        console.error("CHECKOUT ERROR:", err);
        return res.status(500).json({ message: "Checkout failed" });
    }
});

export default router;