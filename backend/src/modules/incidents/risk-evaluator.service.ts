import { Injectable } from '@nestjs/common';

export interface RiskEvaluationFactors {
  isInactivityExceeded: boolean;
  isCheckInMissed: boolean;
  isDeviceOffline: boolean;
  isLowBattery: boolean;
  batteryLevel?: number;
  inactivityMinutes?: number;
}

export interface RiskEvaluationResult {
  riskScore: number; // 0 to 100
  factors: Record<string, number>;
  summary: string;
  disclaimer: string;
}

@Injectable()
export class RiskEvaluatorService {
  /**
   * Calculate composite operational risk score.
   * NOTE: This score is strictly an operational heuristic to prioritize notifications.
   * It does NOT represent medical diagnosis or confirmed human distress.
   */
  evaluate(factors: RiskEvaluationFactors): RiskEvaluationResult {
    let score = 0;
    const breakdown: Record<string, number> = {};

    if (factors.isInactivityExceeded) {
      score += 30;
      breakdown['noActivity'] = 30;
    }

    if (factors.isCheckInMissed) {
      score += 30;
      breakdown['missedCheckIn'] = 30;
    }

    if (factors.isDeviceOffline) {
      score += 20;
      breakdown['deviceOffline'] = 20;
    }

    if (factors.isLowBattery) {
      score += 10;
      breakdown['lowBattery'] = 10;
    }

    // Clamp score between 0 and 100
    const riskScore = Math.min(100, Math.max(0, score));

    return {
      riskScore,
      factors: breakdown,
      summary: this.getNeutralSummary(riskScore, factors),
      disclaimer:
        'Chỉ số này phản ánh mức độ thiếu hụt tín hiệu liên lạc từ thiết bị và không đại diện cho chẩn đoán y tế.',
    };
  }

  private getNeutralSummary(score: number, factors: RiskEvaluationFactors): string {
    if (factors.isDeviceOffline && !factors.isCheckInMissed) {
      return 'Thiết bị tạm thời mất kết nối với hệ thống.';
    }
    if (score >= 60) {
      return 'Chưa nhận được phản hồi xác nhận hoạt động từ người dùng và thiết bị.';
    }
    if (score >= 30) {
      return 'Hệ thống chưa ghi nhận hoạt động mới trong khung giờ theo dõi.';
    }
    return 'Trạng thái bình thường.';
  }
}
