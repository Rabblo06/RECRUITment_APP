import mongoose from "mongoose";

const OfferSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    placementId: { type: mongoose.Schema.Types.ObjectId, ref: "Placement", required: true },

    status: {
        type: String,
        enum: [
            "offered",
            "user_accepted",
            "booking_confirmed",
            "completed",
            "cancelled",
            "rejected",
        ],
        default: "offered",
    },

    cancelReason: { type: String, default: "" },
    cancelledAt: { type: Date, default: null },
    completedAt: { type: Date, default: null },
}, { timestamps: true });

export default mongoose.model("offer", OfferSchema);