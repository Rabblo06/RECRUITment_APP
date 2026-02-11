import mongoose from "mongoose";

const auditLogSchema = new mongoose.Schema({
    actorId: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    action: { type: String, required: true },
    targetType: { type: String, required: true },
    targetId: { type: String, required: true },
    meta: { type: Object, default: {} },
}, { timestamps: true });

const AuditLog = mongoose.model("AuditLog", auditLogSchema);
export default AuditLog;