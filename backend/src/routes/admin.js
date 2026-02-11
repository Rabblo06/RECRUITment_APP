// src/routes/admin.js
import express from 'express';
import User from '../models/User.js';
import Offer from '../models/offer.js';
import AuditLog from '../models/AuditLog.js';
import VenueTemplate from "../models/VenueTemplate.js";
import { PAYROLL_CALENDER_2026 } from "../config/payrollCalender.js";
import { requireAuth, requireManagerOrAdmin } from "../middleware/auth.js";

const router = express.Router();

/**
 * Small helper: write audit logs safely (won't crash app if AuditLog fails)
 */
async function audit(actorId, action, targetType, targetId, meta) {
    try {
        await AuditLog.create({
            actorId,
            action,
            targetType,
            targetId,
            meta: meta || {},
        });
    } catch (err) {
        // ignore audit failures
    }
}

/**
 * 1) Staff Profile + Calculated Stats
 * GET /admin/staff/:id
 * Returns:
 *  - username, fullName, email, dob, createdAt, isActive, availability
 *  - totalJobsWorked, totalHoursWorked, totalEarnings
 */
router.get("/dashboard", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const staffTotal = await User.countDocuments({ role: "staff" });
        const offersPending = await Offer.countDocuments({ status: "pending" });
        const offersAccepted = await Offer.countDocuments({ status: "accepted" });
        const offersCompleted = await Offer.countDocuments({ status: "completed" });

        return res.json({
            staffTotal,
            offersPending,
            offersAccepted,
            offersCompleted
        });
    } catch (err) {
        return res.status(500).json({ message: err.message || "Server error" });
    }
});



router.get('/staff/:id', requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const staff = await User.findById(req.params.id).select(
            "username fullName email dob createdAt isActive availability role managerId"
        );

        if (!staff) return res.status(404).json({ message: "Staff not found" });
        if (staff.role !== "staff") return res.status(400).json({ message: "User is not staff" });

        // 🔒 Manager can only view their own staff
        if (req.user.role === "manager") {
            if (!staff.managerId || staff.managerId.toString() !== String(req.user.id)) {
                return res.status(403).json({ message: "Forbidden: not your staff" });
            }
        }



        // Completed jobs only
        const completedOffers = await Offer.find({
            userId: staff._id,
            status: 'completed',
        }).select('placementId').populate('placementId');

        let totalJobsWorked = completedOffers.length;
        let totalHoursWorked = 0;
        let totalEarnings = 0;

        for (let i = 0; i < completedOffers.length; i += 1) {
            const o = completedOffers[i];
            const placement = o.placementId || {};
            const hrs = Number(placement.totalHours || 0);
            const rate = Number(placement.hourlyRate || 0);
            totalHoursWorked += hrs;
            totalEarnings += hrs * rate;
        }

        res.json({
            ...staff.toObject(),
            totalJobsWorked,
            totalHoursWorked,
            totalEarnings: Number(totalEarnings.toFixed(2)),
        });
    } catch (err) {
        res.status(500).json({ message: err.message || 'Server error' });
    }
});

/**
 * Staff list (search + active filter + optional sort)
 * GET /admin/staff?q=&active=true/false&sort=hours|lastJob
 */
router.get('/staff', requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const q = (req.query.q || '').toString().trim();
        const active = req.query.active; // "true" | "false" | undefined
        const sort = (req.query.sort || '').toString().trim(); // "hours" | "lastJob"

        const filter = { role: 'staff' };
        // ✅ Managers only see their own staff
        if (req.user.role === "manager") {
            filter.managerId = req.user.id;
        }

        if (active === 'true') filter.isActive = true;
        if (active === 'false') filter.isActive = false;

        if (q) filter.username = { $regex: q, $options: 'i' };

        const staffList = await User.find(filter).select(
            'username fullName email dob createdAt isActive availability'
        );

        // If no special sorting requested, return directly
        if (sort !== 'hours' && sort !== 'lastJob') {
            return res.json(staffList);
        }

        // Compute stats for sorting (hours / lastJob)
        const staffIds = staffList.map(s => s._id);
        const offers = await Offer.find({ userId: { $in: staffIds } }).select(
            'userId status placementId createdAt'
        );

        const stats = {};
        for (let i = 0; i < staffList.length; i += 1) {
            stats[String(staffList[i]._id)] = { hours: 0, lastJobAt: '' };
        }

        for (let i = 0; i < offers.length; i += 1) {
            const o = offers[i];
            const sid = String(o.userId);
            if (!stats[sid]) continue;

            // hours only from completed
            if (o.status === 'completed') {
                const placement = o.placementId || {};
                stats[sid].hours += Number(placement.totalHours || 0);
            }

            // last job time = latest offer createdAt
            const createdAt = o.createdAt ? new Date(o.createdAt).toISOString() : '';
            if (!stats[sid].lastJobAt || createdAt > stats[sid].lastJobAt) {
                stats[sid].lastJobAt = createdAt;
            }
        }

        const enriched = staffList.map(s => {
            const sid = String(s._id);
            return {
                ...s.toObject(),
                totalHoursWorked: stats[sid] ? stats[sid].hours : 0,
                lastJobAt: stats[sid] ? stats[sid].lastJobAt : '',
            };
        });

        if (sort === 'hours') {
            enriched.sort((a, b) => Number(b.totalHoursWorked || 0) - Number(a.totalHoursWorked || 0));
        } else if (sort === 'lastJob') {
            enriched.sort((a, b) => String(b.lastJobAt || '').localeCompare(String(a.lastJobAt || '')));
        }

        return res.json(enriched);
    } catch (err) {
        return res.status(500).json({ message: err.message || 'Server error' });
    }
});

/**
 * Update availability
 * PATCH /admin/staff/:id/availability
 * Body: { availability: { days:[], timeFrom:"", timeTo:"", unavailableDates:[] } }
 */
router.patch('/staff/:id/availability', requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const availability = (req.body && req.body.availability) ? req.body.availability : {};

        const u = await User.findByIdAndUpdate(
            req.params.id, { availability }, { new: true }
        ).select('username availability');

        if (!u) return res.status(404).json({ message: 'Staff not found' });

        await audit(req.user.id, 'UPDATE_AVAILABILITY', 'User', String(u._id), availability);
        return res.json(u);
    } catch (err) {
        return res.status(500).json({ message: err.message || 'Server error' });
    }
});

/**
 * Deactivate / Reactivate staff
 * PATCH /admin/staff/:id/active
 * Body: { isActive: true/false }
 */
router.patch('/staff/:id/active', requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const isActive = !!(req.body && req.body.isActive);

        const u = await User.findByIdAndUpdate(
            req.params.id, { isActive }, { new: true }
        ).select('username isActive');

        if (!u) return res.status(404).json({ message: 'Staff not found' });

        await audit(req.user.id, 'SET_STAFF_ACTIVE', 'User', String(u._id), { isActive });
        return res.json(u);
    } catch (err) {
        return res.status(500).json({ message: err.message || 'Server error' });
    }
});

/**
 * 2) Offer history per staff
 * GET /admin/offers/by-staff/:staffId
 */
router.get("/offers/by-staff/:staffId", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const staffId = req.params.staffId;

        // ✅ Manager can only view their own staff history
        if (req.user.role === "manager") {
            const staff = await User.findById(staffId).select("managerId role");
            if (!staff) return res.status(404).json({ message: "Staff not found" });
            if (staff.role !== "staff") return res.status(400).json({ message: "User is not staff" });

            if (!staff.managerId || staff.managerId.toString() !== req.user.id.toString()) {
                return res.status(403).json({ message: "Forbidden: not your staff" });
            }
        }

        const offers = await Offer.find({ userId: staffId })
            .populate("placementId") // ✅ THIS is the key fix
            .sort({ createdAt: -1 })
            .limit(200);

        return res.json(offers);
    } catch (err) {
        return res.status(500).json({ message: err.message || "Server error" });
    }
});

/**
 * 3) Edit offer (pending only)
 * PATCH /admin/offers/:offerId
 * Body: { placementId: { venue?, date?, startTime?, endTime?, hourlyRate?, totalHours?, addressLine?, city?, postcode?, notes? } }
 */
// 3) Edit offer (allowed while offered/user_accepted)
// PATCH /admin/offers/:offerId
// Body: { placementId: { venue?, date?, startTime?, endTime?, hourlyRate?, totalHours?, addressLine?, city?, postcode?, notes? } }
router.patch("/offers/:offerId", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const offer = await Offer.findById(req.params.offerId);
        if (!offer) return res.status(404).json({ message: "Offer not found" });

        // ✅ allow edit while it's not finalized
        const editableStatuses = ["offered", "user_accepted"];
        if (!editableStatuses.includes(offer.status)) {
            return res.status(400).json({ message: "Only offered/user_accepted offers can be edited" });
        }

        const patch = req.body && req.body.placementId ? req.body.placementId : null;
        if (!patch || typeof patch !== "object") {
            return res.status(400).json({ message: "placementId patch object required" });
        }

        // ✅ placementId is an ObjectId -> update Placement document
        const updatedPlacement = await Placement.findByIdAndUpdate(
            offer.placementId, { $set: patch }, { new: true }
        );

        if (!updatedPlacement) {
            return res.status(404).json({ message: "Placement not found" });
        }

        // return the offer with populated placement for UI
        const updatedOffer = await Offer.findById(offer._id)
            .populate("placementId")
            .populate("userId", "username");

        return res.json(updatedOffer);
    } catch (err) {
        return res.status(500).json({ message: err.message || "Server error" });
    }
});


/**
 * 3) Cancel offer
 * POST /admin/offers/:offerId/cancel
 * Body: { reason: "" }
 */
router.post('/offers/:offerId/cancel', requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const offer = await Offer.findById(req.params.offerId);
        if (!offer) return res.status(404).json({ message: 'Offer not found' });

        if (offer.status === 'completed') {
            return res.status(400).json({ message: 'Completed offers cannot be cancelled' });
        }

        const reason = (req.body && req.body.reason) ? String(req.body.reason) : '';

        offer.status = 'cancelled';
        offer.cancelReason = reason;
        offer.cancelledAt = new Date();

        await offer.save();
        await audit(req.user.id, 'CANCEL_OFFER', 'Offer', String(offer._id), { reason });

        return res.json(offer);
    } catch (err) {
        return res.status(500).json({ message: err.message || 'Server error' });
    }
});

/**
 * Mark job as completed (accepted only)
 * POST /admin/offers/:offerId/complete
 */
router.post('/offers/:offerId/complete', requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const offer = await Offer.findById(req.params.offerId);
        if (!offer) return res.status(404).json({ message: 'Offer not found' });

        if (!["booking_confirmed", "user_accepted"].includes(offer.status)) {
            return res.status(400).json({
                message: `Cannot complete offer from status: ${offer.status}`,
            });
        }


        offer.status = 'completed';
        offer.completedAt = new Date();

        await offer.save();
        await audit(req.user.id, 'COMPLETE_OFFER', 'Offer', String(offer._id));

        return res.json(offer);
    } catch (err) {
        return res.status(500).json({ message: err.message || 'Server error' });
    }
});

/**
 * 4) Calendar / Weekly schedule
 * GET /admin/calendar?from=YYYY-MM-DD&to=YYYY-MM-DD
 * Returns offers in the date window (excluding cancelled), with populated userId.username
 */
router.get('/calendar', requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const from = (req.query.from || '').toString().trim();
        const to = (req.query.to || '').toString().trim();

        if (!from || !to) {
            return res.status(400).json({ message: 'from and to are required' });
        }

        const offers = await Offer.find({
            'placementId.date': { $gte: from, $lte: to },
            status: { $ne: 'cancelled' },
        }).populate('userId', 'username');

        return res.json(offers);
    } catch (err) {
        return res.status(500).json({ message: err.message || 'Server error' });
    }
});

/**
 * 7) Payroll summary (NO optional chaining)
 * GET /admin/payroll?from=YYYY-MM-DD&to=YYYY-MM-DD
 * Returns rows: staffId, username, date, venue, totalHours, hourlyRate, pay
 */
router.get('/payroll', requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const from = (req.query.from || '').toString().trim();
        const to = (req.query.to || '').toString().trim();

        const filter = { status: 'completed' };

        // placementId.date is stored as YYYY-MM-DD string → string compare works safely
        if (from || to) {
            filter['placementId.date'] = {};
            if (from) filter['placementId.date'].$gte = from;
            if (to) filter['placementId.date'].$lte = to;
        }

        const offers = await Offer.find(filter).populate('userId', 'username');

        const rows = offers.map(o => {
            const placement = o.placementId || {};
            const user = o.userId || {};

            const hrs = Number(placement.totalHours || 0);
            const rate = Number(placement.hourlyRate || 0);

            return {
                staffId: user._id || null,
                username: user.username || 'Unknown',
                date: placement.date || '',
                venue: placement.venue || '',
                totalHours: hrs,
                hourlyRate: rate,
                pay: Number((hrs * rate).toFixed(2)),
            };
        });

        return res.json(rows);
    } catch (err) {
        return res.status(500).json({ message: err.message || 'Server error' });
    }
});

/**
 * 10) Audit log (last 200)
 * GET /admin/audit
 */
router.get('/audit', requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const logs = await AuditLog.find()
            .sort({ createdAt: -1 })
            .limit(200)
            .populate('actorId', 'username');

        return res.json(logs);
    } catch (err) {
        return res.status(500).json({ message: err.message || 'Server error' });
    }
});

router.post("/create-manager", requireAuth, requireManagerOrAdmin, async(req, res) => {
    const { username, password, fullName } = req.body;

    if (!username || !password) {
        return res.status(400).json({ message: "username and password required" });
    }

    // hash password like your create-staff route
    const passwordHash = await bcrypt.hash(password, 10);

    const user = await User.create({
        username,
        passwordHash,
        role: "manager",
        fullName: fullName || "",
    });

    res.json({ _id: user._id, username: user.username, role: user.role });
});

// DELETE offer + placement (admin/manager)
router.delete("/offers/:offerId", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const offer = await Offer.findById(req.params.offerId);
        if (!offer) return res.status(404).json({ message: "Offer not found" });

        // Only allow delete if not completed
        if (["completed"].includes(offer.status)) {
            return res.status(400).json({ message: "Cannot delete completed offer" });
        }

        const placementId = offer.placementId;

        await Offer.deleteOne({ _id: offer._id });

        if (placementId) {
            await Placement.deleteOne({ _id: placementId });
        }

        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: "Delete failed" });
    }
});

// ✅ List payroll pay dates
router.get("/payroll/periods", requireAuth, requireManagerOrAdmin, (req, res) => {
    res.json(PAYROLL_CALENDER_2026);
});

// ✅ Payroll summary by pay date
router.get("/payroll/period/:payDate", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const payDate = req.params.payDate;
        const period = PAYROLL_CALENDER_2026.find(p => p.payDate === payDate);

        if (!period) {
            return res.status(404).json({ message: "Payroll period not found" });
        }

        const offers = await Offer.find({ status: "completed" })
            .populate("userId", "username")
            .populate("placementId");

        const summary = {};

        for (const o of offers) {
            const p = o.placementId;
            if (!p || !p.date) continue;

            const iso = new Date(p.date).toISOString().slice(0, 10);
            if (iso < period.from || iso > period.to) continue;

            const name = (o.userId && o.userId.username) ? o.userId.username : "Unknown";
            const hrs = Number(p.totalHours || 0);
            const rate = Number(p.hourlyRate || 0);

            if (!summary[name]) summary[name] = { hours: 0, pay: 0 };
            summary[name].hours += hrs;
            summary[name].pay += hrs * rate;
        }

        res.json({
            period,
            staff: Object.entries(summary).map(([username, s]) => ({
                username,
                totalHours: Number(s.hours.toFixed(2)),
                totalPay: Number(s.pay.toFixed(2)),
            })),
        });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// payroll detail for ONE staff in ONE pay period
router.get(
    "/payroll/period/:payDate/staff/:username",
    requireAuth,
    requireManagerOrAdmin,
    async(req, res) => {
        try {
            const { payDate, username } = req.params;

            const period = PAYROLL_CALENDER_2026.find(p => p.payDate === payDate);
            if (!period) {
                return res.status(404).json({ message: "Payroll period not found" });
            }

            const offers = await Offer.find({ status: "completed" })
                .populate("userId", "username")
                .populate("placementId");

            const rows = [];

            for (const o of offers) {
                if (!o.userId || o.userId.username !== username) continue;

                const p = o.placementId;
                if (!p || !p.date) continue;

                const d = new Date(p.date).toISOString().slice(0, 10);
                if (d < period.from || d > period.to) continue;

                const hrs = Number(p.totalHours || 0);
                const rate = Number(p.hourlyRate || 0);

                rows.push({
                    date: d,
                    venue: p.venue || "",
                    startTime: p.startTime || "",
                    endTime: p.endTime || "",
                    hours: hrs,
                    rate,
                    pay: Number((hrs * rate).toFixed(2)),
                });
            }

            res.json({
                period,
                username,
                shifts: rows,
            });
        } catch (err) {
            res.status(500).json({ message: err.message });
        }
    }
);

// ---------- Venues (templates) ----------
router.get("/venues", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        // If you want per-admin venues, filter by createdBy: req.user.id
        const venues = await VenueTemplate.find({}).sort({ createdAt: -1 });
        res.json(venues);
    } catch (e) {
        res.status(500).json({ message: e.message });
    }
});

router.post("/venues", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const name = ((req.body && req.body.name) || "").trim();
        const address = ((req.body && req.body.address) || "").trim();
        const note = ((req.body && req.body.note) || "").trim();

        if (!name) {
            return res.status(400).json({ message: "name is required" });
        }

        // Optional: stop duplicates by name (case-insensitive)
        const exists = await VenueTemplate.findOne({ name: new RegExp(`^${name}$`, "i") });
        if (exists) {
            return res.status(409).json({ message: "Venue already exists" });
        }

        const created = await VenueTemplate.create({
            name,
            address,
            note,
            createdBy: req.user && req.user.id ? req.user.id : null,
        });

        return res.json(created);
    } catch (e) {
        return res.status(500).json({ message: e.message });
    }
});


router.patch("/venues/:id", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const { name, address, note } = req.body;

        const updated = await VenueTemplate.findByIdAndUpdate(
            req.params.id, {
                name: (name || "").trim(),
                address: (address || "").trim(),
                note: (note || "").trim(),
            }, { new: true }
        );

        if (!updated) return res.status(404).json({ message: "Venue not found" });
        res.json(updated);
    } catch (e) {
        res.status(500).json({ message: e.message });
    }
});


router.delete("/venues/:id", requireAuth, requireManagerOrAdmin, async(req, res) => {
    try {
        const deleted = await VenueTemplate.findByIdAndDelete(req.params.id);
        if (!deleted) return res.status(404).json({ message: "Venue not found" });
        res.json({ ok: true });
    } catch (e) {
        res.status(500).json({ message: e.message });
    }
});



export default router;