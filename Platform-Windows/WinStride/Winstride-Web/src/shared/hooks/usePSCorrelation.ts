import { useQuery, useQueries } from '@tanstack/react-query';
import { useMemo } from 'react';
import { fetchEventsPaged } from '../../api/client';
import type { WinEvent } from '../../modules/security/shared/types';

const PS_QUERY_FILTER = (machineName: string, pid: number) =>
  `logName eq 'Microsoft-Windows-PowerShell/Operational' and eventId eq 4104 and machineName eq '${machineName}' and pid eq ${pid}`;

const PS_QUERY_OPTIONS = {
  $orderby: 'timeCreated desc',
  $top: '50',
} as const;

const STALE_TIME = 60_000;

/** Fetch PS 4104 script block events for a single PID. */
export function usePSScriptsForPid(pid: number, machineName: string, enabled = true) {
  return useQuery({
    queryKey: ['ps-scripts', machineName, pid],
    queryFn: () => fetchEventsPaged({
      $filter: PS_QUERY_FILTER(machineName, pid),
      ...PS_QUERY_OPTIONS,
    }),
    staleTime: STALE_TIME,
    enabled,
  });
}

export interface PidEntry {
  pid: number;
  machineName: string;
}

/** Fetch PS 4104 script block events for multiple PIDs in parallel. */
export function usePSScriptsForPids(pids: PidEntry[], enabled = true) {
  const unique = useMemo(() => {
    const seen = new Set<string>();
    return pids.filter(({ pid, machineName }) => {
      const key = `${machineName}:${pid}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }, [pids]);

  const queries = useQueries({
    queries: unique.map(({ pid, machineName }) => ({
      queryKey: ['ps-scripts', machineName, pid],
      queryFn: () => fetchEventsPaged({
        $filter: PS_QUERY_FILTER(machineName, pid),
        $select: 'id,eventId,logName,level,machineName,pid,timeCreated,eventData',
        ...PS_QUERY_OPTIONS,
      }),
      staleTime: STALE_TIME,
      enabled,
    })),
  });

  return { unique, queries };
}

/** Get events from the batch result for a specific pid+machine. */
export function getEventsForPid(
  unique: PidEntry[],
  queries: ReturnType<typeof useQueries<any>>['data'] extends any ? { data?: { events: WinEvent[] } }[] : never,
  pid: number,
  machineName: string,
): WinEvent[] {
  const idx = unique.findIndex((p) => p.pid === pid && p.machineName === machineName);
  if (idx === -1) return [];
  return queries[idx]?.data?.events ?? [];
}
