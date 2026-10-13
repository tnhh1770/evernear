import { BadRequestException } from '@nestjs/common';
import { IncidentStatus } from '../../common/enums';

export class IncidentStateMachine {
  private static readonly VALID_TRANSITIONS: Record<IncidentStatus, IncidentStatus[]> = {
    [IncidentStatus.OPEN]: [
      IncidentStatus.ESCALATED,
      IncidentStatus.ACKNOWLEDGED,
      IncidentStatus.RESOLVED,
      IncidentStatus.CANCELLED,
    ],
    [IncidentStatus.ESCALATED]: [
      IncidentStatus.ACKNOWLEDGED,
      IncidentStatus.RESOLVED,
      IncidentStatus.CANCELLED,
    ],
    [IncidentStatus.ACKNOWLEDGED]: [
      IncidentStatus.RESOLVED,
      IncidentStatus.CANCELLED,
    ],
    [IncidentStatus.RESOLVED]: [], // Terminal state
    [IncidentStatus.CANCELLED]: [], // Terminal state
  };

  public static canTransition(from: IncidentStatus, to: IncidentStatus): boolean {
    if (from === to) return true;
    const allowed = this.VALID_TRANSITIONS[from];
    return allowed ? allowed.includes(to) : false;
  }

  public static assertTransition(from: IncidentStatus, to: IncidentStatus): void {
    if (!this.canTransition(from, to)) {
      throw new BadRequestException(
        `Invalid incident transition: Cannot change status from "${from}" to "${to}".`,
      );
    }
  }
}
