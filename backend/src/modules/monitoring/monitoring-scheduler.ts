import { MonitoringScheduleWindow } from './entities/monitoring-schedule-window.entity';
import { toZonedTime, fromZonedTime, format } from 'date-fns-tz';

export class MonitoringScheduler {
  /**
   * Safely convert a Date to a zoned Date in the specified timezone.
   * If the timezone is unrecognized or throws, falls back to fallbackTimezone ('Asia/Ho_Chi_Minh').
   */
  private static getSafeZonedDate(
    date: Date,
    timezone?: string,
    fallbackTimezone: string = 'Asia/Ho_Chi_Minh',
  ): { zonedDate: Date; effectiveTimezone: string } {
    const safeDate = date && !isNaN(date.getTime()) ? date : new Date();
    let effectiveTimezone = timezone || fallbackTimezone;
    let zonedDate: Date;

    try {
      zonedDate = toZonedTime(safeDate, effectiveTimezone);
      if (isNaN(zonedDate.getTime())) {
        effectiveTimezone = fallbackTimezone;
        zonedDate = toZonedTime(safeDate, effectiveTimezone);
      }
    } catch {
      effectiveTimezone = fallbackTimezone;
      zonedDate = toZonedTime(safeDate, effectiveTimezone);
    }

    if (isNaN(zonedDate.getTime())) {
      effectiveTimezone = fallbackTimezone;
      zonedDate = toZonedTime(new Date(), effectiveTimezone);
    }

    return { zonedDate, effectiveTimezone };
  }

  /**
   * Check if current time is inside an active monitoring schedule window.
   * If no windows are defined, defaults to 24/7 (true).
   */
  public static isWithinActiveWindow(
    date: Date,
    windows: MonitoringScheduleWindow[],
    timezone: string = 'Asia/Ho_Chi_Minh',
  ): boolean {
    if (!windows || windows.length === 0) {
      return true; // No window restrictions -> active 24/7
    }

    const enabledWindows = windows.filter((w) => w.isEnabled);
    if (enabledWindows.length === 0) {
      return false; // All windows disabled -> inactive
    }

    const { zonedDate } = this.getSafeZonedDate(date, timezone);
    const currentDayOfWeek = zonedDate.getDay(); // 0 = Sun, 1 = Mon ...
    const yesterdayDayOfWeek = (currentDayOfWeek + 6) % 7;
    const currentTimeStr = format(zonedDate, 'HH:mm'); // e.g. "14:30"

    for (const win of enabledWindows) {
      if (win.startTime <= win.endTime) {
        // Normal daytime window on current day
        if (
          win.dayOfWeek === currentDayOfWeek &&
          currentTimeStr >= win.startTime &&
          currentTimeStr <= win.endTime
        ) {
          return true;
        }
      } else {
        // Overnight window spanning midnight into the next day
        // 1. Evening portion (start day): currentDayOfWeek matches win.dayOfWeek and currentTime >= win.startTime
        if (
          win.dayOfWeek === currentDayOfWeek &&
          currentTimeStr >= win.startTime
        ) {
          return true;
        }
        // 2. Morning portion (following day): yesterday matches win.dayOfWeek and currentTime <= win.endTime
        if (
          win.dayOfWeek === yesterdayDayOfWeek &&
          currentTimeStr <= win.endTime
        ) {
          return true;
        }
      }
    }

    return false;
  }

  /**
   * Check if HH:mm time is between start and end.
   * Supports overnight windows, e.g. start="22:00", end="06:00".
   */
  public static isTimeBetween(current: string, start: string, end: string): boolean {
    if (start <= end) {
      // Normal daytime window, e.g. 07:00 -> 22:00
      return current >= start && current <= end;
    } else {
      // Overnight window, e.g. 22:00 -> 06:00
      return current >= start || current <= end;
    }
  }

  /**
   * Calculate next active window start time if currently outside.
   */
  public static getNextActiveWindowStart(
    date: Date,
    windows: MonitoringScheduleWindow[],
    timezone: string = 'Asia/Ho_Chi_Minh',
  ): Date {
    if (!windows || windows.length === 0) {
      return new Date(date.getTime() + 60 * 60 * 1000);
    }

    const { zonedDate, effectiveTimezone: effectiveTz } = this.getSafeZonedDate(
      date,
      timezone,
    );

    const enabledWindows = windows.filter((w) => w.isEnabled);
    if (enabledWindows.length === 0) {
      // If no enabled window, check again in 1 hour
      return new Date(date.getTime() + 60 * 60 * 1000);
    }

    // Look ahead across the next 7 days to find the earliest opening window
    let earliestNext: Date | null = null;

    for (let dayOffset = 0; dayOffset <= 7; dayOffset++) {
      const targetDay = (zonedDate.getDay() + dayOffset) % 7;
      const dayWindows = enabledWindows.filter((w) => w.dayOfWeek === targetDay);

      for (const win of dayWindows) {
        const [hours, minutes] = win.startTime.split(':').map(Number);
        const candidateZoned = new Date(zonedDate);
        candidateZoned.setDate(candidateZoned.getDate() + dayOffset);
        candidateZoned.setHours(hours, minutes, 0, 0);

        // Convert the candidate wall-clock date in target timezone back to true UTC
        const candidateUtc = fromZonedTime(candidateZoned, effectiveTz);

        if (candidateUtc.getTime() > date.getTime()) {
          if (!earliestNext || candidateUtc.getTime() < earliestNext.getTime()) {
            earliestNext = candidateUtc;
          }
        }
      }

      if (earliestNext) {
        break;
      }
    }

    return earliestNext || new Date(date.getTime() + 60 * 60 * 1000);
  }
}
