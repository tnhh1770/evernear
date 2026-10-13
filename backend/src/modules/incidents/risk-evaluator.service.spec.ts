import { RiskEvaluatorService } from './risk-evaluator.service';

describe('RiskEvaluatorService', () => {
  let service: RiskEvaluatorService;

  beforeEach(() => {
    service = new RiskEvaluatorService();
  });

  it('should calculate 0 risk when all factors normal', () => {
    const result = service.evaluate({
      isInactivityExceeded: false,
      isCheckInMissed: false,
      isDeviceOffline: false,
      isLowBattery: false,
    });
    expect(result.riskScore).toBe(0);
    expect(result.summary).toBe('Trạng thái bình thường.');
  });

  it('should calculate composite score with inactivity and missed check-in (+60)', () => {
    const result = service.evaluate({
      isInactivityExceeded: true,
      isCheckInMissed: true,
      isDeviceOffline: false,
      isLowBattery: false,
    });
    expect(result.riskScore).toBe(60);
    expect(result.factors['noActivity']).toBe(30);
    expect(result.factors['missedCheckIn']).toBe(30);
  });

  it('should add offline (+20) and low battery (+10)', () => {
    const result = service.evaluate({
      isInactivityExceeded: true,
      isCheckInMissed: true,
      isDeviceOffline: true,
      isLowBattery: true,
      batteryLevel: 8,
    });
    expect(result.riskScore).toBe(90);
    expect(result.factors['deviceOffline']).toBe(20);
    expect(result.factors['lowBattery']).toBe(10);
    expect(result.disclaimer).toBeDefined();
  });
});
