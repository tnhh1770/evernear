import { BadRequestException } from '@nestjs/common';
import { MonitoringState } from '../../common/enums';

export class MonitoringStateMachine {
  /**
   * Valid transition map defining allowed state changes
   */
  private static readonly VALID_TRANSITIONS: Record<MonitoringState, MonitoringState[]> = {
    [MonitoringState.INACTIVE_MONITORING]: [
      MonitoringState.ACTIVE,
      MonitoringState.SUSPENDED,
    ],
    [MonitoringState.ACTIVE]: [
      MonitoringState.CHECK_IN_REQUIRED,
      MonitoringState.SUSPENDED,
    ],
    [MonitoringState.CHECK_IN_REQUIRED]: [
      MonitoringState.ACTIVE,         // user checks in
      MonitoringState.CHECK_IN_PENDING,
      MonitoringState.WARNING,        // grace period expired
      MonitoringState.SUSPENDED,
    ],
    [MonitoringState.CHECK_IN_PENDING]: [
      MonitoringState.ACTIVE,
      MonitoringState.WARNING,
      MonitoringState.SUSPENDED,
    ],
    [MonitoringState.WARNING]: [
      MonitoringState.ACTIVE,         // late check-in
      MonitoringState.ESCALATED,      // escalation delay exceeded
      MonitoringState.ACKNOWLEDGED,   // monitor acknowledges warning
      MonitoringState.RESOLVED,       // resolved directly
      MonitoringState.SUSPENDED,
    ],
    [MonitoringState.ESCALATED]: [
      MonitoringState.ACKNOWLEDGED,   // monitor acknowledges
      MonitoringState.RESOLVED,       // resolved directly
      MonitoringState.ACTIVE,         // user checks in
      MonitoringState.SUSPENDED,
    ],
    [MonitoringState.ACKNOWLEDGED]: [
      MonitoringState.RESOLVED,
      MonitoringState.ACTIVE,         // user checks in
      MonitoringState.SUSPENDED,
    ],
    [MonitoringState.RESOLVED]: [
      MonitoringState.ACTIVE,
      MonitoringState.SUSPENDED,
    ],
    [MonitoringState.SUSPENDED]: [
      MonitoringState.ACTIVE,
      MonitoringState.INACTIVE_MONITORING,
    ],
  };

  /**
   * Validate if a transition from currentState to targetState is permitted
   */
  public static canTransition(from: MonitoringState, to: MonitoringState): boolean {
    if (from === to) return true;
    const allowed = this.VALID_TRANSITIONS[from];
    return allowed ? allowed.includes(to) : false;
  }

  /**
   * Assert transition or throw BadRequestException
   */
  public static assertTransition(from: MonitoringState, to: MonitoringState): void {
    if (!this.canTransition(from, to)) {
      throw new BadRequestException(
        `Invalid state transition: Cannot change monitoring state from "${from}" to "${to}".`,
      );
    }
  }

  /**
   * Determine human-readable state summary for neutral, calm UX
   */
  public static getStateDescription(state: MonitoringState): {
    label: string;
    vietnamese: string;
    isAlarm: boolean;
  } {
    switch (state) {
      case MonitoringState.ACTIVE:
        return { label: 'Active', vietnamese: 'Đang hoạt động', isAlarm: false };
      case MonitoringState.CHECK_IN_REQUIRED:
      case MonitoringState.CHECK_IN_PENDING:
        return { label: 'Check-in Required', vietnamese: 'Đang chờ xác nhận', isAlarm: false };
      case MonitoringState.WARNING:
        return { label: 'Warning', vietnamese: 'Cần kiểm tra', isAlarm: true };
      case MonitoringState.ESCALATED:
        return { label: 'Escalated', vietnamese: 'Đã cảnh báo', isAlarm: true };
      case MonitoringState.ACKNOWLEDGED:
        return { label: 'Acknowledged', vietnamese: 'Người thân đã xác nhận', isAlarm: false };
      case MonitoringState.RESOLVED:
        return { label: 'Resolved', vietnamese: 'Đã giải quyết', isAlarm: false };
      case MonitoringState.SUSPENDED:
      case MonitoringState.INACTIVE_MONITORING:
      default:
        return { label: 'Suspended', vietnamese: 'Tạm dừng giám sát', isAlarm: false };
    }
  }
}
