import { prisma } from "../../config/database.js";
import { ValidationError } from "../../utils/errors.js";

export class RegisterFcmTokenUseCase {
  async execute(
    userId: string,
    token: string,
    platform?: string | null,
  ): Promise<{ user_id: string; token: string; platform: string | null }> {
    const cleaned = token.trim();
    if (cleaned.length < 10 || cleaned.length > 512) {
      throw new ValidationError("Invalid FCM token");
    }

    // A globally unique token can move between accounts in a single write.
    const row = await prisma.user_fcm_tokens.upsert({
      where: { token: cleaned },
      create: {
        user_id: userId,
        token: cleaned,
        platform: platform?.slice(0, 20) ?? null,
      },
      update: {
        user_id: userId,
        platform: platform?.slice(0, 20) ?? null,
        updated_at: new Date(),
      },
    });

    return {
      user_id: row.user_id,
      token: row.token,
      platform: row.platform,
    };
  }
}

export class UnregisterFcmTokenUseCase {
  async execute(userId: string, token: string): Promise<{ deleted: number }> {
    const cleaned = token.trim();
    if (!cleaned) throw new ValidationError("token is required");
    const result = await prisma.user_fcm_tokens.deleteMany({
      where: { user_id: userId, token: cleaned },
    });
    return { deleted: result.count };
  }
}
