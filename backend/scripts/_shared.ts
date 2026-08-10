/** Prisma returns Decimal columns as a Decimal object, not a number. */
export const asNumber = (v: unknown): number => Number(v as never);
