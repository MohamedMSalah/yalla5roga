import { prisma } from "../../config/database.js";
import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import type { SavedOuting } from "../../types/outings/outing.types.js";
import { NotFoundError } from "../../utils/errors.js";

export type SavedOutingWithDetails = SavedOuting & {
  outing: {
    id: string;
    title: string;
    image_url: string;
    location_name: string | null;
    location_area: string | null;
    location_latitude: number | null;
    location_longitude: number | null;
  } | null;
};

export class ListSavedOutingsUseCase {
  async execute(userId: string): Promise<SavedOutingWithDetails[]> {
    const rows = await prisma.saved_outings.findMany({
      where: { user_id: userId },
      include: {
        outings: {
          select: {
            id: true,
            title: true,
            image_url: true,
            location_name: true,
            location_area: true,
            location_latitude: true,
            location_longitude: true,
          },
        },
      },
      orderBy: { saved_at: "desc" },
    });

    return rows.map((row) => ({
      user_id: row.user_id,
      outing_id: row.outing_id,
      saved_at: row.saved_at,
      outing: row.outings,
    }));
  }
}

export class SaveOutingUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(userId: string, outingId: string): Promise<SavedOuting> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    return this.outings.saveOuting(userId, outingId);
  }
}

export class UnsaveOutingUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  execute(userId: string, outingId: string): Promise<SavedOuting> {
    return this.outings.unsaveOuting(userId, outingId);
  }
}
