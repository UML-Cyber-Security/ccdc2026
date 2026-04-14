import type { WinEvent, LogonInfo } from './types';
import { getDataArray, getDataField } from '../../../shared/eventParsing';

/** Extract LogonInfo from pre-parsed events. */
export function parseLogons(events: WinEvent[]): LogonInfo[] {
  const results: LogonInfo[] = [];
  for (const event of events) {
    const arr = getDataArray(event);
    if (!arr) continue;

    const targetUserName = getDataField(arr, 'TargetUserName');
    if (!targetUserName) continue;

    results.push({
      id: event.id,
      targetUserName,
      targetDomainName: getDataField(arr, 'TargetDomainName'),
      machineName: event.machineName,
      logonType: parseInt(getDataField(arr, 'LogonType'), 10) || -1,
      ipAddress: getDataField(arr, 'IpAddress') || '-',
      ipPort: getDataField(arr, 'IpPort'),
      timeCreated: event.timeCreated,
      eventId: event.eventId,
      subjectUserName: getDataField(arr, 'SubjectUserName'),
      subjectDomainName: getDataField(arr, 'SubjectDomainName'),
      authPackage: getDataField(arr, 'AuthenticationPackageName'),
      logonProcess: getDataField(arr, 'LogonProcessName'),
      workstationName: getDataField(arr, 'WorkstationName'),
      processName: getDataField(arr, 'ProcessName'),
      keyLength: parseInt(getDataField(arr, 'KeyLength'), 10) || -1,
      elevatedToken: getDataField(arr, 'ElevatedToken') === '%%1842',
      failureStatus: getDataField(arr, 'Status'),
      failureSubStatus: getDataField(arr, 'SubStatus'),
    });
  }
  return results;
}
