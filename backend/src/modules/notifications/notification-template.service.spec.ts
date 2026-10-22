import { describe, it, expect } from 'vitest';
import {
  NotificationTemplateService,
  escapeRegExp,
} from './notification-template.service';

describe('NotificationTemplateService (i18n & Safe Fallback)', () => {
  const service = new NotificationTemplateService();

  it('1. should render default Vietnamese templates when locale is omitted (backwards compatibility)', () => {
    const res = service.render('CHECK_IN_PROMPT');
    expect(res.title).toBe('Evernear — Bạn vẫn ổn chứ?');
    expect(res.body).toContain('Hệ thống chưa nhận thấy hoạt động mới');
  });

  it('2. should interpolate default name when name param is omitted', () => {
    const viRes = service.render('MONITOR_INACTIVITY_WARNING', {}, 'vi');
    expect(viRes.body).toContain('Người thân');

    const enRes = service.render('MONITOR_INACTIVITY_WARNING', {}, 'en');
    expect(enRes.body).toContain('Loved one');
  });

  it('3. should interpolate custom name across languages', () => {
    const viRes = service.render('MONITOR_INACTIVITY_WARNING', { name: 'Bác Ba' }, 'vi');
    expect(viRes.body).toContain('Bác Ba');

    const enRes = service.render('MONITOR_INACTIVITY_WARNING', { name: 'Uncle Bob' }, 'en');
    expect(enRes.body).toContain('Uncle Bob');
    expect(enRes.title).toBe('Evernear — Care Notice');

    const jaRes = service.render('MONITOR_INACTIVITY_WARNING', { name: '田中' }, 'ja');
    expect(jaRes.body).toContain('田中 様');
  });

  it('4. should render all Tier-1 languages accurately for CHECK_IN_PROMPT', () => {
    const locales = ['vi', 'en', 'fr', 'de', 'es', 'pt', 'ru', 'ja', 'ko', 'zh', 'th', 'id', 'ar', 'hi'];
    for (const loc of locales) {
      const res = service.render('CHECK_IN_PROMPT', {}, loc);
      expect(res.title).toBeDefined();
      expect(res.body).toBeDefined();
      expect(res.title.length).toBeGreaterThan(0);
      expect(res.body.length).toBeGreaterThan(0);
    }
  });

  it('5. should safely normalize regional locales (e.g. en-US, pt-BR, vi-VN)', () => {
    const resUS = service.render('CHECK_IN_PROMPT', {}, 'en-US');
    expect(resUS.title).toBe('Evernear — Are you doing okay?');

    const resBR = service.render('CHECK_IN_PROMPT', {}, 'pt-BR');
    expect(resBR.title).toBe('Evernear — Está tudo bem?');
  });

  it('6. should fall back to English then Vietnamese for unsupported language codes', () => {
    // Unsupported code 'xx'
    const res = service.render('CHECK_IN_PROMPT', {}, 'xx');
    expect(res.title).toBe('Evernear — Are you doing okay?');
  });

  it('7. should fall back to default template for unknown template names', () => {
    const res = service.render('TEST_BACKOFF', {}, 'vi');
    expect(res.title).toBe('Evernear');
    expect(res.body).toBe('Thông báo mới từ hệ thống chăm sóc Evernear.');
  });

  it('8. should escape all 14 ECMAScript regex metacharacters and safely handle parameter keys with metacharacters without throwing SyntaxError', () => {
    const metacharacters = '.*+?^${}()|[]\\';
    const escaped = escapeRegExp(metacharacters);
    expect(escaped).toBe('\\.\\*\\+\\?\\^\\$\\{\\}\\(\\)\\|\\[\\]\\\\');
    expect(() => new RegExp(escaped)).not.toThrow();

    const metacharKeys = {
      '(group)': 'val1',
      '[bracket]': 'val2',
      'foo(?bar)': 'val3',
      'dot.*star': 'val4',
      'plus+': 'val5',
      'pipe|or': 'val6',
      '^caret$': 'val7',
    };

    expect(() => {
      const res = service.render('CHECK_IN_PROMPT', metacharKeys, 'vi');
      expect(res.title).toBe('Evernear — Bạn vẫn ổn chứ?');
      expect(res.body).toBeDefined();
    }).not.toThrow();
  });

  it('9. should preserve special replacement tokens ($$, $&, $\', $`) literally in parameter values', () => {
    const resDollar = service.render('MONITOR_INACTIVITY_WARNING', { name: '$$100' }, 'en');
    expect(resDollar.body).toContain('$$100');
    expect(resDollar.body).not.toContain(' $100');

    const resAmp = service.render('MONITOR_INACTIVITY_WARNING', { name: '$&' }, 'en');
    expect(resAmp.body).toContain('$&');
    expect(resAmp.body).not.toContain('{name}');

    const resQuote = service.render('MONITOR_INACTIVITY_WARNING', { name: "test$'end" }, 'en');
    expect(resQuote.body).toContain("test$'end");
  });

  it('10. should safely handle null or undefined parameter values without throwing', () => {
    const nullRes = service.render('MONITOR_INACTIVITY_WARNING', { name: null as any }, 'en');
    expect(nullRes.body).toBeDefined();
    expect(nullRes.body).not.toContain('null');

    const undefRes = service.render('MONITOR_INACTIVITY_WARNING', { name: undefined as any }, 'en');
    expect(undefRes.body).toBeDefined();
    expect(undefRes.body).not.toContain('undefined');

    const numRes = service.render('MONITOR_INACTIVITY_WARNING', { name: 0 as any }, 'en');
    expect(numRes.body).toContain('0');
  });
});
