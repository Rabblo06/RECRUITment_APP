import jwt from "jsonwebtoken";

export function requireAuth(req, res, next) {
    try {
        const auth = req.headers.authorization || "";
        const parts = auth.split(" ");

        if (parts.length !== 2 || parts[0] !== "Bearer") {
            return res.status(401).json({ message: "Missing token" });
        }

        const token = parts[1];
        const decoded = jwt.verify(token, process.env.JWT_SECRET);

        // decoded should contain: { id, role, username } (depends how you sign it)
        req.user = decoded;

        // In case you sign as { userId: ... }
        if (!req.user.id && req.user.userId) req.user.id = req.user.userId;

        return next();
    } catch (err) {
        return res.status(401).json({ message: "Invalid token" });
    }
}

export function requireManagerOrAdmin(req, res, next) {
    const role = req.user && req.user.role ? req.user.role : "";
    if (role !== "admin" && role !== "manager") {
        return res.status(403).json({ message: "Manager/Admin only" });
    }
    return next();

}