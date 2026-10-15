import "dotenv/config";
import app from "./app.js";
import { prisma } from "./config/database.js";

const PORT = Number(process.env.PORT) || 3000;

async function start() {
  try {
    await prisma.$connect();
    console.log("Database connected successfully");

    app.listen(PORT, () => {
      console.log(`Server running on http://localhost:${PORT}`);
    });
  } catch (error) {
    console.error("Failed to start server:", error);
    process.exit(1);
  }
}

start();
