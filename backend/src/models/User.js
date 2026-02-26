import mongoose from "mongoose";

const UserSchema = new mongoose.Schema({
    username: { type: String, unique: true, required: true, trim: true },
    passwordHash: { type: String, required: true },
    role: { type: String, enum: ["admin", "manager", "staff"], default: "staff" },
    fcmToken: { type: String, default: null },

    fullName: { type: String, default: "" },
    email: { type: String, default: "" },
    dob: { type: String, default: "" },

    // ✅ Who owns this staff account (only relevant for role=staff)
    managerId: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },

    isActive: { type: Boolean, default: true },
    availability: { type: Object, default: {} },
}, { timestamps: true });

export default mongoose.model("User", UserSchema);