import { MonitoringScheduleWindow } from './entities/monitoring-schedule-window.entity';
import { toZonedTime, fromZonedTime } from 'date-fns-tz';

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
    const h = String(zonedDate.getHours()).padStart(2, '0');
    const m = String(zonedDate.getMinutes()).padStart(2, '0');
    const currentTimeStr = `${h}:${m}`;

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

  /**
   * Calculate elapsed awake/active minutes between lastActive and now,
   * discounting overnight/quiet hours so seniors waking up after quiet hours
   * do not experience false check-in prompts or alarms.
   */
  public static calculateActiveInactiveMinutes(
    lastActive: Date,
    now: Date,
    windows: MonitoringScheduleWindow[],
    timezone: string = 'Asia/Ho_Chi_Minh',
  ): number {
    if (!lastActive || isNaN(lastActive.getTime()) || !now || isNaN(now.getTime())) {
      return 0;
    }
    if (lastActive.getTime() >= now.getTime()) {
      return 0;
    }
    if (!windows || windows.length === 0) {
      return Math.floor((now.getTime() - lastActive.getTime()) / (60 * 1000));
    }

    const enabledWindows = windows.filter((w) => w.isEnabled);
    if (enabledWindows.length === 0) {
      return 0;
    }

    const { effectiveTimezone: effectiveTz } = this.getSafeZonedDate(now, timezone);

    let startMs = lastActive.getTime();
    const maxLookbackMs = 30 * 24 * 60 * 60 * 1000;
    if (now.getTime() - startMs > maxLookbackMs) {
      startMs = now.getTime() - maxLookbackMs;
    }

    const startZoned = toZonedTime(new Date(startMs), effectiveTz);
    const endZoned = toZonedTime(now, effectiveTz);

    const curDate = new Date(startZoned);
    curDate.setHours(0, 0, 0, 0);

    const lastDay = new Date(endZoned);
    lastDay.setHours(0, 0, 0, 0);

    let totalActiveMs = 0;

    while (curDate.getTime() <= lastDay.getTime()) {
      const dow = curDate.getDay();
      const yDow = (dow + 6) % 7;
      const dayIntervals: Array<{ start: number; end: number }> = [];

      for (const win of enabledWindows) {
        if (!win.startTime || !win.endTime) continue;
        const [startH, startM] = win.startTime.split(':').map(Number);
        const [endH, endM] = win.endTime.split(':').map(Number);

        if (win.startTime <= win.endTime) {
          // Normal daytime window on current day
          if (win.dayOfWeek === dow) {
            const winStartLocal = new Date(curDate);
            winStartLocal.setHours(startH, startM, 0, 0);
            const winEndLocal = new Date(curDate);
            winEndLocal.setHours(endH, endM, 0, 0);

            const sUtc = fromZonedTime(winStartLocal, effectiveTz).getTime();
            const eUtc = fromZonedTime(winEndLocal, effectiveTz).getTime();
            if (eUtc > sUtc) {
              dayIntervals.push({ start: sUtc, end: eUtc });
            }
          }
        } else {
          // Overnight window spanning midnight into the next day
          // 1. Evening portion (start day): currentDayOfWeek matches win.dayOfWeek
          if (win.dayOfWeek === dow) {
            const winStartLocal = new Date(curDate);
            winStartLocal.setHours(startH, startM, 0, 0);
            const winEndLocal = new Date(curDate);
            winEndLocal.setHours(24, 0, 0, 0);

            const sUtc = fromZonedTime(winStartLocal, effectiveTz).getTime();
            const eUtc = fromZonedTime(winEndLocal, effectiveTz).getTime();
            if (eUtc > sUtc) {
              dayIntervals.push({ start: sUtc, end: eUtc });
            }
          }
          // 2. Morning portion (following day): yesterday matches win.dayOfWeek
          if (win.dayOfWeek === yDow) {
            const winStartLocal = new Date(curDate);
            winStartLocal.setHours(0, 0, 0, 0);
            const winEndLocal = new Date(curDate);
            winEndLocal.setHours(endH, endM, 0, 0);

            const sUtc = fromZonedTime(winStartLocal, effectiveTz).getTime();
            const eUtc = fromZonedTime(winEndLocal, effectiveTz).getTime();
            if (eUtc > sUtc) {
              dayIntervals.push({ start: sUtc, end: eUtc });
            }
          }
        }
      }

      if (dayIntervals.length > 0) {
        dayIntervals.sort((a, b) => a.start - b.start);
        const merged: Array<{ start: number; end: number }> = [];
        for (const intv of dayIntervals) {
          if (!merged.length || intv.start > merged[merged.length - 1].end) {
            merged.push({ start: intv.start, end: intv.end });
          } else {
            merged[merged.length - 1].end = Math.max(merged[merged.length - 1].end, intv.end);
          }
        }

        for (const intv of merged) {
          const overlapStart = Math.max(startMs, intv.start);
          const overlapEnd = Math.min(now.getTime(), intv.end);
          if (overlapEnd > overlapStart) {
            totalActiveMs += (overlapEnd - overlapStart);
          }
        }
      }

      curDate.setDate(curDate.getDate() + 1);
    }

    return Math.floor(totalActiveMs / (60 * 1000));
  }
}
