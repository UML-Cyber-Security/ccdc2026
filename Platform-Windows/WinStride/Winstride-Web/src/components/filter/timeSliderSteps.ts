/** Shared time dual-slider steps and conversion helpers. */

export const TIME_STEPS: { label: string; offset: number }[] = [
  { label: 'All', offset: Infinity },
  { label: '30d', offset: 2_592_000_000 },
  { label: '7d',  offset: 604_800_000 },
  { label: '3d',  offset: 259_200_000 },
  { label: '48h', offset: 172_800_000 },
  { label: '24h', offset: 86_400_000 },
  { label: '12h', offset: 43_200_000 },
  { label: '6h',  offset: 21_600_000 },
  { label: '3h',  offset: 10_800_000 },
  { label: '1h',  offset: 3_600_000 },
  { label: '30m', offset: 1_800_000 },
  { label: '15m', offset: 900_000 },
  { label: 'Now', offset: 0 },
];

export const MAX_STEP_IDX = TIME_STEPS.length - 1;

export function offsetToIdx(isoStr: string, fallback: number): number {
  if (!isoStr) return fallback;
  const elapsed = Date.now() - new Date(isoStr).getTime();
  let best = fallback;
  let bestDiff = Infinity;
  for (let i = 0; i <= MAX_STEP_IDX; i++) {
    const diff = Math.abs(elapsed - TIME_STEPS[i].offset);
    if (diff < bestDiff) { bestDiff = diff; best = i; }
  }
  return best;
}

export function idxToIso(idx: number, isEnd: boolean): string {
  const step = TIME_STEPS[idx];
  if (isEnd && step.offset === 0) return '';
  if (!isEnd && step.offset === Infinity) return '';
  return new Date(Date.now() - step.offset).toISOString();
}
