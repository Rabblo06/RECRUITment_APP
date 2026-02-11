import mongoose from "mongoose";

const VenueTemplateSchema = new mongoose.Schema({
    name: { type: String, required: true, trim: true },
    address: { type: String, default: "", trim: true },
    note: { type: String, default: "", trim: true },

    // optional: who created it (admin/manager)
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
}, { timestamps: true });

VenueTemplateSchema.index({ name: 1 });

export default mongoose.model("VenueTemplate", VenueTemplateSchema);