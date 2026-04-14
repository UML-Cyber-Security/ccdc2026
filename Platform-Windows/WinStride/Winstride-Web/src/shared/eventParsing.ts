import type { WinEvent } from '../modules/security/shared/types';

/** Extract a named field value from the Data array inside eventData. */
export function getDataField(dataArray: unknown[], fieldName: string): string {
  if (!Array.isArray(dataArray)) return '';
  for (const item of dataArray) {
    if (
      item &&
      typeof item === 'object' &&
      (item as Record<string, string>)['@Name'] === fieldName
    ) {
      return (item as Record<string, string>)['#text'] ?? '';
    }
  }
  return '';
}

/** Navigate the pre-parsed eventData object and return the Data array, or null. */
export function getDataArray(event: WinEvent): unknown[] | null {
  if (!event.eventData) return null;
  const eventObj = (event.eventData as Record<string, unknown>)?.Event ?? event.eventData;
  const eventData = (eventObj as Record<string, unknown>)?.EventData as Record<string, unknown> | undefined;
  if (!eventData) return null;
  let dataArray = eventData.Data;
  if (!dataArray) return null;
  if (!Array.isArray(dataArray)) dataArray = [dataArray];
  return dataArray as unknown[];
}

/**
 * Get a System-level field value (e.g., Provider_Name, Channel, Computer).
 * These live in Event.System rather than Event.EventData.Data.
 */
export function getSystemField(event: WinEvent, fieldName: string): string {
  if (!event.eventData) return '';
  const eventObj = (event.eventData as Record<string, unknown>)?.Event ?? event.eventData;
  const system = (eventObj as Record<string, unknown>).System as Record<string, unknown> | undefined;
  if (!system) return '';

  switch (fieldName) {
    case 'Provider_Name':
      return String((system.Provider as Record<string, string>)?.['@Name'] ?? '');
    case 'Provider_Guid':
      return String((system.Provider as Record<string, string>)?.['@Guid'] ?? '');
    case 'Channel':
      return String(system.Channel ?? '');
    case 'Computer':
      return String(system.Computer ?? '');
    case 'Execution_ProcessID':
      return String((system.Execution as Record<string, string>)?.['@ProcessID'] ?? '');
    case 'Execution_ThreadID':
      return String((system.Execution as Record<string, string>)?.['@ThreadID'] ?? '');
    default:
      return '';
  }
}
