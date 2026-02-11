import mongoose from "mongoose";

const PlacementSchema = new mongoose.Schema({
    venue: { type: String, required: true },
    roleTitle: { type: String, required: true },
    date: { type: Date, required: true },
    startTime: String,
    endTime: String,
    hourlyRate: Number,
    totalHours: Number,
    addressLine: String,
    city: String,
    postcode: String,
    notes: String,
}, { timestamps: true });

export default mongoose.model("Placement", PlacementSchema);