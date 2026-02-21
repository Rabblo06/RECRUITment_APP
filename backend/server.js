import express from "express";
import cors from "cors";
import mongoose from "mongoose";
import dotenv from "dotenv";

import authRoutes from "./src/routes/auth.js";
import userRoutes from "./src/routes/users.js";
import offerRoutes from "./src/routes/offers.js";
import adminRoutes from "./src/routes/admin.js";
import telegramRoutes from "./src/routes/telegram.js";

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get("/", (req, res) => res.send("API running"));

app.use("/auth", authRoutes);
app.use("/users", userRoutes);
app.use("/offers", offerRoutes);
app.use("/admin", adminRoutes);
app.use("/telegram", telegramRoutes);

mongoose
    .connect(process.env.MONGO_URI)
    .then(() => {
        console.log("MongoDB connected");
        app.listen(process.env.PORT || 4000, () => console.log(`Server running on ${process.env.PORT || 4000}`));
    })
    .catch((err) => console.error("MongoDB connection error:", err));