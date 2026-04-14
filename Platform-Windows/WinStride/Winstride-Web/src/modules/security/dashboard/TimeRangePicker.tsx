import { useState, useEffect } from 'react';
import DualRangeTrack from '../../../components/filter/DualRangeTrack';
import { injectFilterStyles } from '../../../components/filter/filterStyles';
import { TIME_STEPS, MAX_STEP_IDX, offsetToIdx, idxToIso } from '../../../components/filter/timeSliderSteps';

/** Sparse labels shown under the slider (every 3rd + last) */
const VISIBLE_LABELS = TIME_STEPS.filter((_, i) => i % 3 === 0 || i === MAX_STEP_IDX);

interface TimeRangePickerProps {
  timeStart: string;
  timeEnd: string;
  onTimeChange: (start: string, end: string) => void;
}

export default function TimeRangePicker({ timeStart, timeEnd, onTimeChange }: TimeRangePickerProps) {
  injectFilterStyles();

  const [startIdx, setStartIdx] = useState(() => offsetToIdx(timeStart, 0));
  const [endIdx, setEndIdx] = useState(() => offsetToIdx(timeEnd, MAX_STEP_IDX));

  useEffect(() => {
    const incoming = offsetToIdx(timeStart, 0);
    if (Math.abs(incoming - startIdx) > 1) setStartIdx(incoming);
  }, [timeStart]);

  useEffect(() => {
    const incoming = offsetToIdx(timeEnd, MAX_STEP_IDX);
    if (Math.abs(incoming - endIdx) > 1) setEndIdx(incoming);
  }, [timeEnd]);

  const minPct = (startIdx / MAX_STEP_IDX) * 100;
  const maxPct = (endIdx / MAX_STEP_IDX) * 100;

  const displayLabel = startIdx === 0 && endIdx === MAX_STEP_IDX
    ? 'All time'
    : `${TIME_STEPS[startIdx].label} — ${TIME_STEPS[endIdx].label}`;

  function commitStart(idx: number) {
    const clamped = Math.min(idx, endIdx);
    setStartIdx(clamped);
    onTimeChange(idxToIso(clamped, false), idxToIso(endIdx, true));
  }

  function commitEnd(idx: number) {
    const clamped = Math.max(idx, startIdx);
    setEndIdx(clamped);
    onTimeChange(idxToIso(startIdx, false), idxToIso(clamped, true));
  }

  return (
    <div className="flex items-center gap-4 min-w-0">
      <div className="flex items-center gap-2 flex-shrink-0 w-44">
        <span className="text-gray-200 text-sm font-medium">Time Range</span>
        <span className="text-[#58a6ff] text-xs font-semibold whitespace-nowrap">{displayLabel}</span>
      </div>

      <div className="w-64 flex-shrink-0">
        <div className="relative h-5">
          <DualRangeTrack minPct={minPct} maxPct={maxPct} />
          <input
            type="range"
            className="gf-slider-dual"
            min={0}
            max={MAX_STEP_IDX}
            step={1}
            value={startIdx}
            style={{ zIndex: startIdx <= MAX_STEP_IDX / 2 ? 4 : 3 }}
            onChange={(e) => commitStart(Number(e.target.value))}
          />
          <input
            type="range"
            className="gf-slider-dual"
            min={0}
            max={MAX_STEP_IDX}
            step={1}
            value={endIdx}
            style={{ zIndex: startIdx <= MAX_STEP_IDX / 2 ? 3 : 4 }}
            onChange={(e) => commitEnd(Number(e.target.value))}
          />
        </div>
        <div className="flex justify-between mt-0.5 px-0.5">
          {VISIBLE_LABELS.map((step) => (
            <span key={step.label} className="text-[9px] text-gray-500 select-none">
              {step.label}
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}
