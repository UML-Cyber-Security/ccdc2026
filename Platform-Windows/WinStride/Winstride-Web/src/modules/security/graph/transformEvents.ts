import type { WinEvent, LogonInfo, GraphNode, GraphEdge } from '../shared/types';
import { EVENT_LABELS, LOGON_TYPE_LABELS, isSystemAccount } from '../shared/eventMeta';
import { getDataArray, getDataField } from '../../../shared/eventParsing';
import { type MachineAliasMap, resolveMachineName } from '../shared/machineAliases';

// Re-export shared symbols so existing consumers don't all break at once
export { EVENT_LABELS, LOGON_TYPE_LABELS, isSystemAccount };
export { FAILURE_STATUS_LABELS } from '../shared/eventMeta';

const GROUP_ADD_IDS = new Set([4728, 4732, 4756]);

/** Well-known privileged group SIDs (no hardcoded names). */
function isPrivilegedGroupSid(sid: string): boolean {
  if (sid === 'S-1-5-32-544') return true;               // Builtin\Administrators
  if (sid.startsWith('S-1-5-21-')) {
    const rid = sid.split('-').pop();
    if (rid === '512' || rid === '518' || rid === '519')  // Domain / Schema / Enterprise Admins
      return true;
  }
  return false;
}

export function computePrivilegedUsers(events: WinEvent[], sidMap: Map<string, string>): Set<string> {
  const privileged = new Set<string>();
  for (const event of events) {
    const dataArray = getDataArray(event);
    if (!dataArray) continue;

    if (event.eventId === 4672) {
      const name = getDataField(dataArray, 'SubjectUserName');
      if (name && !isSystemAccount(name)) privileged.add(name.toLowerCase());
    } else if (event.eventId === 4624) {
      if (getDataField(dataArray, 'ElevatedToken') === '%%1842') {
        const name = getDataField(dataArray, 'TargetUserName');
        if (name && !isSystemAccount(name)) privileged.add(name.toLowerCase());
      }
    } else if (GROUP_ADD_IDS.has(event.eventId)) {
      const targetSid = getDataField(dataArray, 'TargetSid');
      if (isPrivilegedGroupSid(targetSid)) {
        let memberName = normalizeMemberName(getDataField(dataArray, 'MemberName'), sidMap);
        if (!memberName) {
          const memberSid = getDataField(dataArray, 'MemberSid');
          if (memberSid) memberName = sidMap.get(memberSid) ?? null;
        }
        if (memberName && !isSystemAccount(memberName)) {
          privileged.add(memberName.toLowerCase());
        }
      }
    }
  }
  return privileged;
}

const GROUP_EVENT_IDS = new Set([4728, 4729, 4732, 4733, 4756, 4757]);

/** Build SID → username map from the FULL (unfiltered) event set. */
export function computeSidMap(events: WinEvent[]): Map<string, string> {
  const sidToName = new Map<string, string>();
  for (const event of events) {
    const dataArray = getDataArray(event);
    if (!dataArray) continue;
    const pairs: [string, string][] = [
      [getDataField(dataArray, 'TargetUserSid'), getDataField(dataArray, 'TargetUserName')],
      [getDataField(dataArray, 'TargetSid'), getDataField(dataArray, 'TargetUserName')],
      [getDataField(dataArray, 'SubjectUserSid'), getDataField(dataArray, 'SubjectUserName')],
    ];
    for (const [sid, name] of pairs) {
      if (sid && sid.startsWith('S-1-') && name && !isSystemAccount(name)) {
        sidToName.set(sid, name);
      }
    }
  }
  return sidToName;
}
const GROUP_REMOVE_IDS = new Set([4729, 4733, 4757]);

function normalizeMemberName(raw: string | null, sidMap: Map<string, string>): string | null {
  if (!raw || raw === '-') return null;
  // DN format: CN=John Smith,CN=Users,DC=corp,...
  const cnMatch = raw.match(/^CN=([^,]+)/i);
  if (cnMatch) {
    const cn = cnMatch[1];
    // CN might be a SID — try to resolve
    if (cn.startsWith('S-1-')) return sidMap.get(cn) ?? null;
    return cn;
  }
  // DOMAIN\user format
  if (raw.includes('\\')) return raw.split('\\').pop() || null;
  // Raw SID
  if (raw.startsWith('S-1-')) return sidMap.get(raw) ?? null;
  return raw;
}

function getEdgeLabel(eventId: number, logonType: number): string {
  const base = EVENT_LABELS[eventId] ?? `Event ${eventId}`;
  // Only append logon type for logon/failed logon, not logoff
  if ((eventId === 4624 || eventId === 4625) && logonType >= 0) {
    const lt = LOGON_TYPE_LABELS[logonType];
    if (lt) return `${base} (${lt})`;
  }
  return base;
}

function extractLogonInfo(event: WinEvent): LogonInfo | null {
  const dataArray = getDataArray(event);
  if (!dataArray) return null;

  try {
    const targetUserName = getDataField(dataArray, 'TargetUserName');
    const logonTypeStr = getDataField(dataArray, 'LogonType');
    const logonType = logonTypeStr ? parseInt(logonTypeStr, 10) : -1;
    const keyLengthStr = getDataField(dataArray, 'KeyLength');
    const elevatedStr = getDataField(dataArray, 'ElevatedToken');

    if (!targetUserName) return null;

    return {
      id: event.id,
      targetUserName,
      targetDomainName: getDataField(dataArray, 'TargetDomainName'),
      machineName: event.machineName,
      logonType,
      ipAddress: getDataField(dataArray, 'IpAddress') || '-',
      ipPort: getDataField(dataArray, 'IpPort') || '',
      timeCreated: event.timeCreated,
      eventId: event.eventId,
      subjectUserName: getDataField(dataArray, 'SubjectUserName'),
      subjectDomainName: getDataField(dataArray, 'SubjectDomainName'),
      authPackage: getDataField(dataArray, 'AuthenticationPackageName'),
      logonProcess: getDataField(dataArray, 'LogonProcessName'),
      workstationName: getDataField(dataArray, 'WorkstationName'),
      processName: getDataField(dataArray, 'ProcessName'),
      keyLength: keyLengthStr ? parseInt(keyLengthStr, 10) : -1,
      elevatedToken: elevatedStr === '%%1842' || event.eventId === 4672,
      failureStatus: getDataField(dataArray, 'Status'),
      failureSubStatus: getDataField(dataArray, 'SubStatus'),
    };
  } catch {
    return null;
  }
}

export function transformEvents(events: WinEvent[], machineAliases?: MachineAliasMap, privilegedUsers?: Set<string>, sidMap?: Map<string, string>): {
  nodes: GraphNode[];
  edges: GraphEdge[];
} {
  const aliases = machineAliases ?? {};
  const privSet = privilegedUsers ?? new Set<string>();

  // Separate group events from logon events
  const logonEvents: WinEvent[] = [];
  const groupEvents: WinEvent[] = [];
  for (const event of events) {
    if (GROUP_EVENT_IDS.has(event.eventId)) groupEvents.push(event);
    else logonEvents.push(event);
  }

  const logons = logonEvents.map(extractLogonInfo).filter(Boolean) as LogonInfo[];

  const nodeMap = new Map<string, GraphNode>();
  const edgeMap = new Map<string, GraphEdge>();

  const newNode = (id: string, label: string, type: 'user' | 'machine' | 'group', privileged: boolean): GraphNode => ({
    id, label, type, privileged,
    logonCount: 0, failedCount: 0, successCount: 0, connectedCount: 0,
    authPackages: [], hadAdminSession: false, lastIp: '', lastSeen: '',
    eventIds: [],
  });

  // Track unique connections per node
  const userMachines = new Map<string, Set<string>>();
  const machineUsers = new Map<string, Set<string>>();
  const nodeAuthPackages = new Map<string, Set<string>>();

  for (const logon of logons) {
    const userId = `user:${logon.targetUserName.toLowerCase()}`;
    const resolvedMachine = resolveMachineName(logon.machineName, aliases);
    const machineId = `machine:${resolvedMachine.toLowerCase()}`;
    const isFailed = logon.eventId === 4625;

    // Upsert user node
    if (!nodeMap.has(userId)) {
      nodeMap.set(userId, newNode(userId, logon.targetUserName, 'user', privSet.has(logon.targetUserName.toLowerCase())));
      userMachines.set(userId, new Set());
      nodeAuthPackages.set(userId, new Set());
    }
    const userNode = nodeMap.get(userId)!;
    userNode.logonCount++;
    userNode.eventIds.push(logon.id);
    if (isFailed) userNode.failedCount++;
    else userNode.successCount++;
    if (logon.elevatedToken) userNode.hadAdminSession = true;
    userMachines.get(userId)!.add(machineId);
    if (logon.authPackage) nodeAuthPackages.get(userId)!.add(logon.authPackage);
    if (logon.ipAddress && logon.ipAddress !== '-' && logon.timeCreated > userNode.lastSeen) {
      userNode.lastIp = logon.ipAddress;
      userNode.lastSeen = logon.timeCreated;
    }

    // Upsert machine node
    if (!nodeMap.has(machineId)) {
      nodeMap.set(machineId, newNode(machineId, resolvedMachine, 'machine', false));
      machineUsers.set(machineId, new Set());
      nodeAuthPackages.set(machineId, new Set());
    }
    const machineNode = nodeMap.get(machineId)!;
    machineNode.logonCount++;
    machineNode.eventIds.push(logon.id);
    if (isFailed) machineNode.failedCount++;
    else machineNode.successCount++;
    machineUsers.get(machineId)!.add(userId);
    if (logon.authPackage) nodeAuthPackages.get(machineId)!.add(logon.authPackage);
    if (logon.timeCreated > machineNode.lastSeen) {
      machineNode.lastSeen = logon.timeCreated;
    }

    // Edge keyed by user + machine + eventId + logonType
    const label = getEdgeLabel(logon.eventId, logon.logonType);
    const edgeKey = `${userId}->${machineId}::${logon.eventId}::${logon.logonType}`;
    if (!edgeMap.has(edgeKey)) {
      edgeMap.set(edgeKey, {
        id: edgeKey,
        source: userId,
        target: machineId,
        edgeType: 'logon',
        logonCount: 0,
        logonType: logon.logonType,
        logonTypeLabel: label,
        firstSeen: logon.timeCreated,
        lastSeen: logon.timeCreated,
        ipAddress: logon.ipAddress,
        ipPort: logon.ipPort,
        subjectUserName: logon.subjectUserName,
        subjectDomainName: logon.subjectDomainName,
        targetDomainName: logon.targetDomainName,
        authPackage: logon.authPackage,
        logonProcess: logon.logonProcess,
        workstationName: logon.workstationName,
        processName: logon.processName,
        keyLength: logon.keyLength,
        elevatedToken: logon.elevatedToken,
        failureStatus: logon.failureStatus,
        failureSubStatus: logon.failureSubStatus,
        eventId: logon.eventId,
        eventIds: [],
        isFailed: logon.eventId === 4625,
      });
    }
    const edge = edgeMap.get(edgeKey)!;
    edge.logonCount++;
    edge.eventIds.push(logon.id);
    if (logon.timeCreated > edge.lastSeen) {
      edge.lastSeen = logon.timeCreated;
      // Update fields from most recent event
      if (logon.ipAddress && logon.ipAddress !== '-') edge.ipAddress = logon.ipAddress;
      if (logon.ipPort) edge.ipPort = logon.ipPort;
      if (logon.processName) edge.processName = logon.processName;
      if (logon.workstationName) edge.workstationName = logon.workstationName;
      if (logon.elevatedToken) edge.elevatedToken = true;
    }
    if (logon.timeCreated < edge.firstSeen) {
      edge.firstSeen = logon.timeCreated;
    }
  }

  // Process group-change events → group nodes + membership edges
  const groupMembers = new Map<string, Set<string>>();

  for (const event of groupEvents) {
    const dataArray = getDataArray(event);
    if (!dataArray) continue;

    const groupName = getDataField(dataArray, 'TargetUserName');
    if (!groupName) continue;

    const groupId = `group:${groupName.toLowerCase()}`;
    const resolvedSidMap = sidMap ?? new Map<string, string>();
    // MemberName is often "-" on standalone machines; fall back to SID lookup
    let memberName = normalizeMemberName(getDataField(dataArray, 'MemberName'), resolvedSidMap);
    if (!memberName) {
      const memberSid = getDataField(dataArray, 'MemberSid');
      if (memberSid) memberName = resolvedSidMap.get(memberSid) ?? null;
    }

    // Always create the group node even if member can't be resolved
    if (!nodeMap.has(groupId)) {
      nodeMap.set(groupId, newNode(groupId, groupName, 'group', false));
      groupMembers.set(groupId, new Set());
    }
    const groupNode = nodeMap.get(groupId)!;
    groupNode.logonCount++;
    groupNode.eventIds.push(event.id);
    if (event.timeCreated > groupNode.lastSeen) groupNode.lastSeen = event.timeCreated;

    // Only create membership edge if we resolved the member to a real name
    if (!memberName || isSystemAccount(memberName)) continue;

    const memberId = `user:${memberName.toLowerCase()}`;
    const isRemoval = GROUP_REMOVE_IDS.has(event.eventId);
    const label = isRemoval ? 'Removed from Group' : 'Added to Group';
    const performer = getDataField(dataArray, 'SubjectUserName') || '';

    groupMembers.get(groupId)!.add(memberId);

    // Upsert member user node (may already exist from logon events)
    if (!nodeMap.has(memberId)) {
      nodeMap.set(memberId, newNode(memberId, memberName, 'user', privSet.has(memberName.toLowerCase())));
      userMachines.set(memberId, new Set());
      nodeAuthPackages.set(memberId, new Set());
    }
    const memberNode = nodeMap.get(memberId)!;
    memberNode.eventIds.push(event.id);

    // Membership edge: user → group
    const edgeKey = `${memberId}->${groupId}::${event.eventId}`;
    if (!edgeMap.has(edgeKey)) {
      edgeMap.set(edgeKey, {
        id: edgeKey,
        source: memberId,
        target: groupId,
        edgeType: 'membership',
        logonCount: 0,
        logonType: -1,
        logonTypeLabel: label,
        firstSeen: event.timeCreated,
        lastSeen: event.timeCreated,
        ipAddress: '',
        ipPort: '',
        subjectUserName: performer,
        subjectDomainName: getDataField(dataArray, 'SubjectDomainName') || '',
        targetDomainName: getDataField(dataArray, 'TargetDomainName') || '',
        authPackage: '',
        logonProcess: '',
        workstationName: '',
        processName: '',
        keyLength: -1,
        elevatedToken: false,
        failureStatus: '',
        failureSubStatus: '',
        eventId: event.eventId,
        eventIds: [],
        isFailed: false,
      });
    }
    const edge = edgeMap.get(edgeKey)!;
    edge.logonCount++;
    edge.eventIds.push(event.id);
    if (event.timeCreated > edge.lastSeen) edge.lastSeen = event.timeCreated;
    if (event.timeCreated < edge.firstSeen) edge.firstSeen = event.timeCreated;
  }

  // Finalize node stats
  for (const [id, node] of nodeMap) {
    if (node.type === 'user') {
      node.connectedCount = userMachines.get(id)?.size ?? 0;
    } else if (node.type === 'machine') {
      node.connectedCount = machineUsers.get(id)?.size ?? 0;
    } else {
      node.connectedCount = groupMembers.get(id)?.size ?? 0;
    }
    node.authPackages = Array.from(nodeAuthPackages.get(id) ?? []);
  }

  return {
    nodes: Array.from(nodeMap.values()),
    edges: Array.from(edgeMap.values()),
  };
}
