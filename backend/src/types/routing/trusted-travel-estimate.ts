import type { transportation_mode } from "@prisma/client";

/** Produced by a backend routing adapter for this exact set of authorized inputs. */
export interface TrustedTravelEstimate {
  reference: string;
  userId: string;
  outingId: string;
  venueVersion: string;
  startingLocationVersion: string;
  outingScheduleVersion: string;
  transportationMode: transportation_mode;
  durationSeconds: number;
  calculatedAt: Date;
  expiresAt: Date;
}

export type TrustedTravelEstimateInputs = Pick<TrustedTravelEstimate,
  "userId" | "outingId" | "venueVersion" | "startingLocationVersion" | "outingScheduleVersion" | "transportationMode">;

export interface TrustedTravelEstimateSource {
  find(inputs: TrustedTravelEstimateInputs): Promise<TrustedTravelEstimate | null>;
}
