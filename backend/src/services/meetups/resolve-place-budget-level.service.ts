import type { Prisma, price_level } from "@prisma/client";
import { BudgetLevel } from "../../types/meetups/meetup-preferences.js";

export type ComparablePlacePrice = {
  currency: "EGP";
  basis: "ADMISSION" | "PER_PERSON";
  categoryId: string;
  amount: number;
};

export interface CatalogBudgetData {
  category_id: string | null;
  currency: string;
  price_level: price_level | null;
  place_prices: {
    label: string;
    amount: Prisma.Decimal;
    currency: string;
    source: string;
    evidence: Prisma.JsonValue;
  }[];
}

export class ResolvePlaceBudgetLevelService {
  resolve(place: CatalogBudgetData): BudgetLevel {
    if (place.currency !== "EGP") return BudgetLevel.UNKNOWN;
    switch (place.price_level) {
      case "free":
      case "budget":
        return BudgetLevel.AFFORDABLE;
      case "moderate":
        return BudgetLevel.MODERATE;
      case "expensive":
      case "luxury":
        return BudgetLevel.EXPENSIVE;
      default:
        return BudgetLevel.UNKNOWN;
    }
  }

  comparablePrice(place: CatalogBudgetData): ComparablePlacePrice | null {
    if (!place.category_id) return null;
    const byBasis = new Map<ComparablePlacePrice["basis"], Set<number>>();
    for (const row of place.place_prices) {
      if (row.currency !== "EGP" || !row.evidence || typeof row.evidence !== "object" || Array.isArray(row.evidence)) continue;
      const amount = row.amount.toNumber();
      if (!Number.isFinite(amount) || amount < 0) continue;
      let basis: ComparablePlacePrice["basis"] | undefined;
      if (row.source === "osm" && row.label === "Admission") {
        const charge = typeof row.evidence.charge === "string"
          ? /^(\d{1,8}(?:\.\d{1,2})?)\s*EGP$/i.exec(row.evidence.charge) : null;
        if ((row.evidence.fee === "no" && amount === 0) || (charge && Number(charge[1]) === amount)) basis = "ADMISSION";
      }
      if (row.source === "manual" && row.evidence.verified === true && row.evidence.price_basis === "PER_PERSON") {
        basis = "PER_PERSON";
      }
      if (basis) {
        const amounts = byBasis.get(basis) ?? new Set<number>();
        amounts.add(amount);
        byBasis.set(basis, amounts);
      }
    }
    // A mix of measurements or conflicting amounts has no single comparable value.
    if (byBasis.size !== 1) return null;
    for (const [basis, amounts] of byBasis) {
      if (amounts.size !== 1) return null;
      const [amount] = amounts;
      return { basis, amount: amount!, categoryId: place.category_id, currency: "EGP" };
    }
    return null;
  }
}
