import { Injectable } from '@nestjs/common';

export interface RenderedTemplate {
  title: string;
  body: string;
}

interface TemplateEntry {
  title: string;
  body: string;
}

/**
 * Escapes all 14 ECMAScript RegExp syntax characters to ensure literal matching in dynamic regular expressions.
 * Characters: . * + ? ^ $ { } ( ) | [ ] \
 */
export function escapeRegExp(val: string): string {
  return String(val).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

const DEFAULT_NAMES: Record<string, string> = {
  vi: 'Người thân',
  en: 'Loved one',
  fr: 'Proche',
  de: 'Angehörige(r)',
  es: 'Familiar',
  pt: 'Familiar',
  ru: 'Близкий',
  ja: 'ご家族',
  ko: '가족',
  zh: '家人',
  th: 'คนในครอบครัว',
  id: 'Keluarga',
  ar: 'القريب',
  hi: 'प्रियजन',
};

const TEMPLATE_DICTIONARIES: Record<string, Record<string, TemplateEntry>> = {
  // 1. Vietnamese (Canonical Baseline)
  vi: {
    CHECK_IN_PROMPT: {
      title: 'Carely — Bạn vẫn ổn chứ?',
      body: 'Hệ thống chưa nhận thấy hoạt động mới trong khung giờ quy định. Chạm để xác nhận bạn vẫn ổn.',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — Nhắc nhở xác nhận',
      body: 'Vui lòng chạm vào đây để xác nhận trạng thái hoạt động của bạn.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — Thông báo chăm sóc',
      body: 'Chưa ghi nhận hoạt động hoặc phản hồi từ {name}. Bạn có thể thử liên lạc thăm hỏi.',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — Cần lưu ý',
      body: 'Đã quá thời gian chờ nhưng chưa nhận được tín hiệu từ thiết bị của {name}. Vui lòng kiểm tra lại.',
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — An tâm',
      body: '{name} đã xác nhận hoạt động bình thường. Tình huống theo dõi đã hoàn tất.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — An tâm',
      body: '{name} vừa xác nhận "Tôi vẫn ổn". Mức pin: {battery}%.{note}',
    },
    default: {
      title: 'Carely',
      body: 'Thông báo mới từ hệ thống chăm sóc Carely.',
    },
  },

  // 2. English (Global Default Fallback)
  en: {
    CHECK_IN_PROMPT: {
      title: 'Carely — Are you doing okay?',
      body: 'No recent activity was detected within the scheduled window. Tap to confirm you are okay.',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — Check-in reminder',
      body: 'Please tap here to confirm your active status.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — Care Notice',
      body: 'No activity or response has been recorded from {name}. You may want to check in on them.',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — Attention Needed',
      body: "The waiting period has expired with no signal received from {name}'s device. Please check in on them.",
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — Reassured',
      body: '{name} has confirmed normal activity. The monitoring incident has been resolved.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — Reassured',
      body: '{name} confirmed "I am okay". Battery: {battery}%.{note}',
    },
    default: {
      title: 'Carely',
      body: 'New notification from Carely care system.',
    },
  },

  // 3. French
  fr: {
    CHECK_IN_PROMPT: {
      title: 'Carely — Tout va bien ?',
      body: "Aucune activité récente n'a été détectée durant la période prévue. Touchez pour confirmer que tout va bien.",
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — Rappel de confirmation',
      body: "Veuillez toucher ici pour confirmer votre état d'activité.",
    },
    MONITOR_INACTIVITY_WARNING: {
      title: "Carely — Avis d'attention",
      body: 'Aucune activité ni réponse enregistrée de la part de {name}. Vous pouvez essayer de prendre de ses nouvelles.',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — Attention requise',
      body: "Le délai d'attente est dépassé sans aucun signal de l'appareil de {name}. Veuillez vérifier.",
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — Rassuré',
      body: '{name} a confirmé une activité normale. La situation de suivi est résolue.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — Rassuré(e)',
      body: '{name} a confirmé « Tout va bien ». Batterie : {battery}%.{note}',
    },
    default: {
      title: 'Carely',
      body: 'Nouvelle notification du système de suivi Carely.',
    },
  },

  // 4. German
  de: {
    CHECK_IN_PROMPT: {
      title: 'Carely — Geht es Ihnen gut?',
      body: 'Im festgelegten Zeitraum wurde keine neue Aktivität festgestellt. Tippen Sie hier, um zu bestätigen, dass alles in Ordnung ist.',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — Erinnerung zur Bestätigung',
      body: 'Bitte tippen Sie hier, um Ihren Aktivitätsstatus zu bestätigen.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — Fürsorge-Hinweis',
      body: 'Keine Aktivität oder Rückmeldung von {name} festgestellt. Vielleicht möchten Sie kurz nachfragen.',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — Aufmerksamkeit erforderlich',
      body: 'Die Wartezeit ist abgelaufen, ohne Signal vom Gerät von {name}. Bitte sehen Sie nach.',
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — Beruhigt',
      body: '{name} hat normale Aktivität bestätigt. Der Vorfall wurde behoben.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — Beruhigt',
      body: '{name} hat „Mir geht es gut“ bestätigt. Akku: {battery}%.{note}',
    },
    default: {
      title: 'Carely',
      body: 'Neue Benachrichtigung aus dem Carely-System.',
    },
  },

  // 5. Spanish
  es: {
    CHECK_IN_PROMPT: {
      title: 'Carely — ¿Todo va bien?',
      body: 'No se ha detectado actividad reciente en el horario programado. Toca para confirmar que estás bien.',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — Recordatorio de confirmación',
      body: 'Por favor toca aquí para confirmar tu estado de actividad.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — Aviso de atención',
      body: 'No se ha registrado actividad o respuesta de {name}. Podrías intentar comunicarte con ellos.',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — Atención requerida',
      body: 'El tiempo de espera ha expirado sin señal del dispositivo de {name}. Por favor verifica.',
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — Tranquilidad',
      body: '{name} ha confirmado actividad normal. La situación de seguimiento ha sido resuelta.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — Tranquilidad',
      body: '{name} confirmó «Estoy bien». Batería: {battery}%.{note}',
    },
    default: {
      title: 'Carely',
      body: 'Nueva notificación del sistema de cuidado Carely.',
    },
  },

  // 6. Portuguese
  pt: {
    CHECK_IN_PROMPT: {
      title: 'Carely — Está tudo bem?',
      body: 'Nenhuma atividade recente foi detectada no horário programado. Toque para confirmar que está tudo bem.',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — Lembrete de confirmação',
      body: 'Por favor, toque aqui para confirmar seu estado de atividade.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — Aviso de atenção',
      body: 'Nenhuma atividade ou resposta foi registrada de {name}. Você pode tentar entrar em contato.',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — Atenção necessária',
      body: 'O tempo de espera expirou sem sinal do dispositivo de {name}. Por favor, verifique.',
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — Tranquilidade',
      body: '{name} confirmou atividade normal. A situação de monitoramento foi resolvida.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — Tranquilidade',
      body: '{name} confirmou "Estou bem". Bateria: {battery}%.{note}',
    },
    default: {
      title: 'Carely',
      body: 'Nova notificação do sistema de cuidado Carely.',
    },
  },

  // 7. Russian
  ru: {
    CHECK_IN_PROMPT: {
      title: 'Carely — С вами все в порядке?',
      body: 'За установленный период активность не зафиксирована. Нажмите, чтобы подтвердить, что все в порядке.',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — Напоминание о подтверждении',
      body: 'Пожалуйста, нажмите здесь, чтобы подтвердить, что вы активны.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — Внимание к близкому',
      body: 'Нет активности или ответа от {name}. Возможно, стоит связаться с ними.',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — Требуется внимание',
      body: 'Время ожидания истекло, сигнал с устройства {name} не поступил. Пожалуйста, проверьте ситуацию.',
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — Все спокойно',
      body: '{name} подтвердил(а) обычную активность. Ситуация наблюдения урегулирована.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — Всё в порядке',
      body: '{name} подтвердил(а) «Я в порядке». Батарея: {battery}%.{note}',
    },
    default: {
      title: 'Carely',
      body: 'Новое уведомление от службы заботы Carely.',
    },
  },

  // 8. Japanese
  ja: {
    CHECK_IN_PROMPT: {
      title: 'Carely — 大丈夫ですか？',
      body: '予定の時間内に新しい活動が検出されませんでした。タップして無事を確認してください。',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — 確認のリマインダー',
      body: 'ここをタップして活動状況を確認してください。',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — 見守り通知',
      body: '{name} 様からの活動や応答が記録されていません。連絡を取ってみてください。',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — ご確認のお願い',
      body: '待機時間を過ぎましたが、{name} 様の端末から信号が届いていません。様子を確認してください。',
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — ご安心ください',
      body: '{name} 様が通常の活動を確認しました。見守りインシデントは解消されました。',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — ご安心ください',
      body: '{name} 様が「大丈夫です」と確認しました。バッテリー: {battery}%。{note}',
    },
    default: {
      title: 'Carely',
      body: 'Carely 見守りシステムからの新しい通知です。',
    },
  },

  // 9. Korean
  ko: {
    CHECK_IN_PROMPT: {
      title: 'Carely — 괜찮으신가요?',
      body: '설정된 시간 동안 새로운 활동이 감지되지 않았습니다. 탭하여 안전을 확인해 주세요.',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — 안부 확인 알림',
      body: '여기를 탭하여 활동 상태를 확인해 주세요.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — 안부 알림',
      body: '{name} 님의 활동이나 응답이 기록되지 않았습니다. 연락을 취해 보시는 것을 권장합니다.',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — 주의 필요',
      body: '대기 시간이 초과되었으나 {name} 님의 기기에서 신호가 감지되지 않았습니다. 확인해 주시기 바랍니다.',
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — 안심',
      body: '{name} 님이 정상 활동을 확인했습니다. 모니터링 상황이 완료되었습니다.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — 안심 알림',
      body: '{name} 님이 "괜찮아요"라고 확인했습니다. 배터리: {battery}%.{note}',
    },
    default: {
      title: 'Carely',
      body: 'Carely 케어 시스템의 새로운 알림입니다.',
    },
  },

  // 10. Chinese (Simplified)
  zh: {
    CHECK_IN_PROMPT: {
      title: 'Carely — 您一切都好吗？',
      body: '在设定的时间段内未检测到新的活动。点击以确认您一切安好。',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — 确认提醒',
      body: '请点击此处以确认您的活动状态。',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — 关怀提醒',
      body: '尚未记录到来自 {name} 的活动或回应。您可以尝试联系询问。',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — 需注意',
      body: '已超出等待时间，仍未收到来自 {name} 设备的信息。请及时核实情况。',
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — 恢复安心',
      body: '{name} 已确认活动正常。关怀事件已顺利解决。',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — 报平安',
      body: '{name} 刚刚确认“我很好”。电量：{battery}%。{note}',
    },
    default: {
      title: 'Carely',
      body: '来自 Carely 关怀系统的新通知。',
    },
  },

  // 11. Thai
  th: {
    CHECK_IN_PROMPT: {
      title: 'Carely — คุณสบายดีไหม?',
      body: 'ไม่พบกิจกรรมล่าสุดในช่วงเวลาที่กำหนด แตะเพื่อยืนยันว่าคุณปลอดภัยดี',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — แจ้งเตือนการยืนยันตัวตน',
      body: 'โปรดแตะที่นี่เพื่อยืนยันสถานะการทำกิจกรรมของคุณ',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — การแจ้งเตือนความห่วงใย',
      body: 'ไม่พบกิจกรรมหรือการตอบกลับจาก {name} คุณอาจลองติดต่อสอบถามดู',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — ต้องได้รับการตรวจสอบ',
      body: 'หมดเวลารอคอยแล้วแต่ยังไม่ได้รับสัญญาณจากอุปกรณ์ของ {name} โปรดตรวจสอบโดยด่วน',
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — สบายใจได้',
      body: '{name} ได้ยืนยันการทำกิจกรรมตามปกติแล้ว การติดตามความปลอดภัยเสร็จสิ้นแล้ว',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — วางใจได้',
      body: '{name} ได้ยืนยันว่า "ฉันสบายดี" แบตเตอรี่: {battery}% {note}',
    },
    default: {
      title: 'Carely',
      body: 'การแจ้งเตือนใหม่จากระบบ Carely',
    },
  },

  // 12. Indonesian
  id: {
    CHECK_IN_PROMPT: {
      title: 'Carely — Apakah Anda baik-baik saja?',
      body: 'Tidak ada aktivitas baru yang terdeteksi dalam jadwal. Ketuk untuk mengonfirmasi bahwa Anda baik-baik saja.',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — Pengingat konfirmasi',
      body: 'Silakan ketuk di sini untuk mengonfirmasi status keaktifan Anda.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — Pemberitahuan Perhatian',
      body: 'Belum ada aktivitas atau respons yang tercatat dari {name}. Anda dapat mencoba menghubunginya.',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — Perlu Perhatian',
      body: 'Waktu tunggu telah habis tetapi belum ada sinyal dari perangkat {name}. Harap periksa.',
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — Ketenangan',
      body: '{name} telah mengonfirmasi aktivitas normal. Situasi pemantauan telah diselesaikan.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — Tenang',
      body: '{name} baru saja mengonfirmasi "Saya baik-baik saja". Baterai: {battery}%.{note}',
    },
    default: {
      title: 'Carely',
      body: 'Pemberitahuan baru dari sistem Carely.',
    },
  },

  // 13. Arabic
  ar: {
    CHECK_IN_PROMPT: {
      title: 'Carely — هل أنت بخير؟',
      body: 'لم يتم رصد أي نشاط حديث خلال الفترة المحددة. اضغط لتأكيد أنك بخير.',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — تذكير بالتأكيد',
      body: 'يرجى الضغط هنا لتأكيد حالتك النشطة.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — إشعار رعاية',
      body: 'لم يتم تسجيل أي نشاط أو استجابة من {name}. قد ترغب في التواصل والاطمئنان عليه.',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — يُرجى الانتباه',
      body: 'انتهت فترة الانتظار دون تلقي إشارة من جهاز {name}. يرجى التحقق.',
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — تم الاطمئنان',
      body: 'أكّد {name} نشاطه الطبيعي. تم إغلاق حالة المتابعة بنجاح.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — طمأنينة',
      body: '{name} أكد أنه "بخير". مستوى البطارية: {battery}%.{note}',
    },
    default: {
      title: 'Carely',
      body: 'إشعار جديد من نظام الرعاية Carely.',
    },
  },

  // 14. Hindi
  hi: {
    CHECK_IN_PROMPT: {
      title: 'Carely — क्या आप ठीक हैं?',
      body: 'निर्धारित समय में कोई नई गतिविधि नहीं पाई गई। पुष्टि करने के लिए टैप करें कि आप सुरक्षित हैं।',
    },
    CHECK_IN_REMINDER: {
      title: 'Carely — चेक-इन अनुस्मारक',
      body: 'कृपया अपनी गतिविधि की स्थिति की पुष्टि करने के लिए यहाँ टैप करें।',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Carely — देखभाल सूचना',
      body: '{name} से कोई गतिविधि या प्रतिक्रिया दर्ज नहीं की गई है। आप उनसे संपर्क करने का प्रयास कर सकते हैं।',
    },
    MONITOR_ESCALATION: {
      title: 'Carely — ध्यान देने की आवश्यकता',
      body: 'प्रतीक्षा अवधि समाप्त हो गई है लेकिन {name} के उपकरण से कोई संकेत नहीं मिला है। कृपया जांच करें।',
    },
    INCIDENT_RESOLVED: {
      title: 'Carely — निश्चिंतता',
      body: '{name} ने सामान्य गतिविधि की पुष्टि की है। निगरानी की स्थिति हल हो गई है।',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Carely — निश्चिंत रहें',
      body: '{name} ने पुष्टि की कि "मैं ठीक हूँ"। बैटरी: {battery}%।{note}',
    },
    default: {
      title: 'Carely',
      body: 'Carely देखभाल प्रणाली से नई अधिसूचना।',
    },
  },
};

@Injectable()
export class NotificationTemplateService {
  /**
   * Generates calm, respectful, localized copy avoiding alarming terms like "bạn có thể đã chết".
   * Resolves templates with safe tiered fallback: locale -> 'en' -> 'vi' -> default template.
   */
  render(
    templateName: string,
    params: Record<string, string> = {},
    locale = 'vi',
  ): RenderedTemplate {
    const normalizedLocale = (locale || 'vi').toLowerCase().split(/[-_]/)[0];

    // Tier 1: Look up in requested locale catalog
    let entry: TemplateEntry | undefined =
      TEMPLATE_DICTIONARIES[normalizedLocale]?.[templateName];
    let resolvedLang = normalizedLocale;

    // Tier 2: Fall back to English
    if (!entry && normalizedLocale !== 'en') {
      entry = TEMPLATE_DICTIONARIES['en']?.[templateName];
      resolvedLang = 'en';
    }

    // Tier 3: Fall back to Vietnamese
    if (!entry) {
      entry = TEMPLATE_DICTIONARIES['vi']?.[templateName];
      resolvedLang = 'vi';
    }

    // Tier 4: Unknown templateName fallback to default template
    if (!entry) {
      entry =
        TEMPLATE_DICTIONARIES[normalizedLocale]?.default ||
        TEMPLATE_DICTIONARIES['en']?.default ||
        TEMPLATE_DICTIONARIES['vi'].default;
      resolvedLang = TEMPLATE_DICTIONARIES[normalizedLocale]?.default ? normalizedLocale : 'vi';
    }

    // Parameter substitution ({name} and legacy ${name})
    const defaultName = DEFAULT_NAMES[resolvedLang] || DEFAULT_NAMES['vi'];
    const mergedParams: Record<string, string> = {
      name: defaultName,
      ...params,
    };

    let title = entry.title;
    let body = entry.body;

    for (const [key, value] of Object.entries(mergedParams)) {
      const escapedKey = escapeRegExp(key);
      const placeholderRegex = new RegExp(`\\$\\{${escapedKey}\\}|\\{${escapedKey}\\}`, 'g');
      const replacement = value != null ? String(value) : '';
      title = title.replace(placeholderRegex, () => replacement);
      body = body.replace(placeholderRegex, () => replacement);
    }

    return { title, body };
  }
}
