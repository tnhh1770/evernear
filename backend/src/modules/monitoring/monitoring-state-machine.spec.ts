import { BadRequestException } from '@nestjs/common';
import { MonitoringStateMachine } from './monitoring-state-machine';
import { MonitoringState } from '../../common/enums';

describe('MonitoringStateMachine', () => {
  it('should allow valid transition from ACTIVE to CHECK_IN_REQUIRED', () => {
    expect(
      MonitoringStateMachine.canTransition(
        MonitoringState.ACTIVE,
        MonitoringState.CHECK_IN_REQUIRED,
      ),
    ).toBe(true);
    expect(() =>
      MonitoringStateMachine.assertTransition(
        MonitoringState.ACTIVE,
        MonitoringState.CHECK_IN_REQUIRED,
      ),
    ).not.toThrow();
  });

  it('should allow check-in recovery: CHECK_IN_REQUIRED to ACTIVE', () => {
    expect(
      MonitoringStateMachine.canTransition(
        MonitoringState.CHECK_IN_REQUIRED,
        MonitoringState.ACTIVE,
      ),
    ).toBe(true);
  });

  it('should allow escalation flow: CHECK_IN_REQUIRED -> WARNING -> ESCALATED -> ACKNOWLEDGED -> RESOLVED', () => {
    expect(
      MonitoringStateMachine.canTransition(
        MonitoringState.CHECK_IN_REQUIRED,
        MonitoringState.WARNING,
      ),
    ).toBe(true);
    expect(
      MonitoringStateMachine.canTransition(
        MonitoringState.WARNING,
        MonitoringState.ESCALATED,
      ),
    ).toBe(true);
    expect(
      MonitoringStateMachine.canTransition(
        MonitoringState.ESCALATED,
        MonitoringState.ACKNOWLEDGED,
      ),
    ).toBe(true);
    expect(
      MonitoringStateMachine.canTransition(
        MonitoringState.ACKNOWLEDGED,
        MonitoringState.RESOLVED,
      ),
    ).toBe(true);
  });

  it('should REJECT invalid direct transition from RESOLVED to ESCALATED without new incident', () => {
    expect(
      MonitoringStateMachine.canTransition(
        MonitoringState.RESOLVED,
        MonitoringState.ESCALATED,
      ),
    ).toBe(false);
    expect(() =>
      MonitoringStateMachine.assertTransition(
        MonitoringState.RESOLVED,
        MonitoringState.ESCALATED,
      ),
    ).toThrow(BadRequestException);
  });

  it('should allow suspending monitoring from any state', () => {
    expect(
      MonitoringStateMachine.canTransition(
        MonitoringState.ACTIVE,
        MonitoringState.SUSPENDED,
      ),
    ).toBe(true);
    expect(
      MonitoringStateMachine.canTransition(
        MonitoringState.CHECK_IN_REQUIRED,
        MonitoringState.SUSPENDED,
      ),
    ).toBe(true);
    expect(
      MonitoringStateMachine.canTransition(
        MonitoringState.ESCALATED,
        MonitoringState.SUSPENDED,
      ),
    ).toBe(true);
  });

  it('should provide neutral and calm descriptions for UX', () => {
    const desc = MonitoringStateMachine.getStateDescription(
      MonitoringState.CHECK_IN_REQUIRED,
    );
    expect(desc.vietnamese).toBe('Đang chờ xác nhận');
    expect(desc.isAlarm).toBe(false);
  });
});
