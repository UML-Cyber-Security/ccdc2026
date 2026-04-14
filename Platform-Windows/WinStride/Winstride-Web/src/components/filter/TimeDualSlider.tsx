import { useState, useEffect } from 'react';
import CollapsibleSection from './CollapsibleSection';
import DualRangeTrack from './DualRangeTrack';
import { injectFilterStyles } from './filterStyles';
import { TIME_STEPS, MAX_STEP_IDX, offsetToIdx } from './timeSliderSteps';

export default function TimeDualSlider({
  timeStart,
  timeEnd,
  onTimeStartChange,
  onTimeEndChange,
}: {
  timeStart: string;
  timeEnd: string;
  onTimeStartChange: (v: string) => void;
  onTimeEndChange: (v: string) => void;
}) {
  injectFilterStyles();

  const [startIdx, setStartIdx] = useState(() => offsetToIdx(timeStart, 0));
  const [endIdx, setEndIdx] = useState(() => offsetToIdx(timeEnd, MAX_STEP_IDX));

  // Sync from parent on meaningful external changes (preset load, reset)
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
    ? 'All'
    : `${TIME_STEPS[startIdx].label} — ${TIME_STEPS[endIdx].label}`;

  return (
    <CollapsibleSection
      title="Time Range"
      right={<span className="text-[12px] font-medium text-[#58a6ff]">{displayLabel}</span>}
    >
      <div className="relative h-5">
        <DualRangeTrack minPct={minPct} maxPct={maxPct} />
        <input
          type="range"
          className="gf-slider-dual"
          min={0}
          max={MAX_STEP_IDX}
          step={1}
          value={startIdx}
          style={startIdx === endIdx && startIdx >= MAX_STEP_IDX / 2 ? { zIndex: 5 } : undefined}
          onChange={(e) => {
            const idx = Math.min(Number(e.target.value), endIdx);
            setStartIdx(idx);
            const step = TIME_STEPS[idx];
            onTimeStartChange(step.offset === Infinity ? '' : new Date(Date.now() - step.offset).toISOString());
          }}
        />
        <input
          type="range"
          className="gf-slider-dual"
          min={0}
          max={MAX_STEP_IDX}
          step={1}
          value={endIdx}
          style={startIdx === endIdx && startIdx < MAX_STEP_IDX / 2 ? { zIndex: 5 } : undefined}
          onChange={(e) => {
            const idx = Math.max(Number(e.target.value), startIdx);
            setEndIdx(idx);
            const step = TIME_STEPS[idx];
            onTimeEndChange(step.offset === 0 ? '' : new Date(Date.now() - step.offset).toISOString());
          }}
        />
      </div>
      <div className="flex justify-between mt-1 px-0.5">
        {TIME_STEPS.map((step) => (
          <span key={step.label} className="text-[9px] text-gray-600 select-none">
            {step.label}
          </span>
        ))}
      </div>
    </CollapsibleSection>
  );
}
