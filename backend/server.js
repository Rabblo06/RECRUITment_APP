// ✅ Load env FIRST (before importing routes)
import "./src/config/env.js";

import express from "express";
import cors from "cors";
import mongoose from "mongoose";

import authRoutes from "./src/routes/auth.js";
import userRoutes from "./src/routes/users.js";
import offerRoutes from "./src/routes/offers.js";
import adminRoutes from "./src/routes/admin.js";
import telegramRoutes from "./src/routes/telegram.js";
import deviceTokenRoutes from "./src/routes/deviceToken.js";

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(deviceTokenRoutes);

app.get("/", (req, res) => res.send("API running"));

app.use("/auth", authRoutes);
app.use("/users", userRoutes);
app.use("/offers", offerRoutes);
app.use("/admin", adminRoutes);
app.use("/telegram", telegramRoutes);

mongoose
    .connect(process.env.MONGO_URI)
    .then(() => {
        const port = process.env.PORT || 4000;
        app.listen(port, "0.0.0.0", () => console.log(`Server running on ${port}`));
    })
    .catch((err) => console.error("MongoDB connection error:", err));