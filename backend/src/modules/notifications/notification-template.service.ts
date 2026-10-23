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
  af: 'Relatief',
  am: 'ዘመድ',
  az: 'Qohum',
  bg: 'Близък',
  bn: 'আপেক্ষিক',
  ca: 'Relatiu',
  cs: 'Relativní',
  cy: 'Cymharol',
  da: 'Relativ',
  el: 'Σχετικό',
  et: 'Sugulane',
  eu: 'Erlatiboa',
  fa: 'نسبی',
  fi: 'Suhteellinen',
  ga: 'Gaol',
  gl: 'Relativo',
  he: 'יחסית',
  hr: 'Srodnik',
  hu: 'Rokon',
  is: 'Aðstandandi',
  it: 'Relativo',
  kk: 'Туыс',
  km: 'ញាតិ',
  lo: 'ພີ່ນ້ອງ',
  lt: 'Giminaitis',
  lv: 'Radinieks',
  mn: 'Хамаатан садан',
  mr: 'नातेवाईक',
  ms: 'Relatif',
  my: 'ဆွေမျိုး',
  nl: 'Relatief',
  no: 'Slektning',
  pl: 'Względne',
  ro: 'Relativ',
  sk: 'Relatívna',
  sl: 'Sorodnik',
  sr: 'Релатив',
  sv: 'Släkting',
  sw: 'Jamaa',
  ta: 'உறவினர்',
  te: 'బంధువు',
  tl: 'Kamag-anak',
  fil: 'Kamag-anak',
  tr: 'Göreceli',
  uk: 'Родич',
  ur: 'رشتہ دار',
  uz: 'Qarindosh',
};

const TEMPLATE_DICTIONARIES: Record<string, Record<string, TemplateEntry>> = {
  // 1. Vietnamese (Canonical Baseline)
  vi: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Bạn vẫn ổn chứ?',
      body: 'Hệ thống chưa nhận thấy hoạt động mới trong khung giờ quy định. Chạm để xác nhận bạn vẫn ổn.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Nhắc nhở xác nhận',
      body: 'Vui lòng chạm vào đây để xác nhận trạng thái hoạt động của bạn.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Thông báo chăm sóc',
      body: 'Chưa ghi nhận hoạt động hoặc phản hồi từ {name}. Bạn có thể thử liên lạc thăm hỏi.',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Cần lưu ý',
      body: 'Đã quá thời gian chờ nhưng chưa nhận được tín hiệu từ thiết bị của {name}. Vui lòng kiểm tra lại.',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — An tâm',
      body: '{name} đã xác nhận hoạt động bình thường. Tình huống theo dõi đã hoàn tất.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — An tâm',
      body: '{name} vừa xác nhận "Tôi vẫn ổn". Mức pin: {battery}%.{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Thông báo mới từ hệ thống chăm sóc Evernear.',
    },
  },

  // 2. English (Global Default Fallback)
  en: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Are you doing okay?',
      body: 'No recent activity was detected within the scheduled window. Tap to confirm you are okay.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Check-in reminder',
      body: 'Please tap here to confirm your active status.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Care Notice',
      body: 'No activity or response has been recorded from {name}. You may want to check in on them.',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Attention Needed',
      body: "The waiting period has expired with no signal received from {name}'s device. Please check in on them.",
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Reassured',
      body: '{name} has confirmed normal activity. The monitoring incident has been resolved.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Reassured',
      body: '{name} confirmed "I am okay". Battery: {battery}%.{note}',
    },
    default: {
      title: 'Evernear',
      body: 'New notification from Evernear care system.',
    },
  },

  // 3. French
  fr: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Tout va bien ?',
      body: "Aucune activité récente n'a été détectée durant la période prévue. Touchez pour confirmer que tout va bien.",
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Rappel de confirmation',
      body: "Veuillez toucher ici pour confirmer votre état d'activité.",
    },
    MONITOR_INACTIVITY_WARNING: {
      title: "Evernear — Avis d'attention",
      body: 'Aucune activité ni réponse enregistrée de la part de {name}. Vous pouvez essayer de prendre de ses nouvelles.',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Attention requise',
      body: "Le délai d'attente est dépassé sans aucun signal de l'appareil de {name}. Veuillez vérifier.",
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Rassuré',
      body: '{name} a confirmé une activité normale. La situation de suivi est résolue.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Rassuré(e)',
      body: '{name} a confirmé « Tout va bien ». Batterie : {battery}%.{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Nouvelle notification du système de suivi Evernear.',
    },
  },

  // 4. German
  de: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Geht es Ihnen gut?',
      body: 'Im festgelegten Zeitraum wurde keine neue Aktivität festgestellt. Tippen Sie hier, um zu bestätigen, dass alles in Ordnung ist.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Erinnerung zur Bestätigung',
      body: 'Bitte tippen Sie hier, um Ihren Aktivitätsstatus zu bestätigen.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Fürsorge-Hinweis',
      body: 'Keine Aktivität oder Rückmeldung von {name} festgestellt. Vielleicht möchten Sie kurz nachfragen.',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Aufmerksamkeit erforderlich',
      body: 'Die Wartezeit ist abgelaufen, ohne Signal vom Gerät von {name}. Bitte sehen Sie nach.',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Beruhigt',
      body: '{name} hat normale Aktivität bestätigt. Der Vorfall wurde behoben.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Beruhigt',
      body: '{name} hat „Mir geht es gut“ bestätigt. Akku: {battery}%.{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Neue Benachrichtigung aus dem Evernear-System.',
    },
  },

  // 5. Spanish
  es: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — ¿Todo va bien?',
      body: 'No se ha detectado actividad reciente en el horario programado. Toca para confirmar que estás bien.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Recordatorio de confirmación',
      body: 'Por favor toca aquí para confirmar tu estado de actividad.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Aviso de atención',
      body: 'No se ha registrado actividad o respuesta de {name}. Podrías intentar comunicarte con ellos.',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Atención requerida',
      body: 'El tiempo de espera ha expirado sin señal del dispositivo de {name}. Por favor verifica.',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Tranquilidad',
      body: '{name} ha confirmado actividad normal. La situación de seguimiento ha sido resuelta.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Tranquilidad',
      body: '{name} confirmó «Estoy bien». Batería: {battery}%.{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Nueva notificación del sistema de cuidado Evernear.',
    },
  },

  // 6. Portuguese
  pt: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Está tudo bem?',
      body: 'Nenhuma atividade recente foi detectada no horário programado. Toque para confirmar que está tudo bem.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Lembrete de confirmação',
      body: 'Por favor, toque aqui para confirmar seu estado de atividade.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Aviso de atenção',
      body: 'Nenhuma atividade ou resposta foi registrada de {name}. Você pode tentar entrar em contato.',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Atenção necessária',
      body: 'O tempo de espera expirou sem sinal do dispositivo de {name}. Por favor, verifique.',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Tranquilidade',
      body: '{name} confirmou atividade normal. A situação de monitoramento foi resolvida.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Tranquilidade',
      body: '{name} confirmou "Estou bem". Bateria: {battery}%.{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Nova notificação do sistema de cuidado Evernear.',
    },
  },

  // 7. Russian
  ru: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — С вами все в порядке?',
      body: 'За установленный период активность не зафиксирована. Нажмите, чтобы подтвердить, что все в порядке.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Напоминание о подтверждении',
      body: 'Пожалуйста, нажмите здесь, чтобы подтвердить, что вы активны.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Внимание к близкому',
      body: 'Нет активности или ответа от {name}. Возможно, стоит связаться с ними.',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Требуется внимание',
      body: 'Время ожидания истекло, сигнал с устройства {name} не поступил. Пожалуйста, проверьте ситуацию.',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Все спокойно',
      body: '{name} подтвердил(а) обычную активность. Ситуация наблюдения урегулирована.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Всё в порядке',
      body: '{name} подтвердил(а) «Я в порядке». Батарея: {battery}%.{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Новое уведомление от службы заботы Evernear.',
    },
  },

  // 8. Japanese
  ja: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — 大丈夫ですか？',
      body: '予定の時間内に新しい活動が検出されませんでした。タップして無事を確認してください。',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — 確認のリマインダー',
      body: 'ここをタップして活動状況を確認してください。',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — 見守り通知',
      body: '{name} 様からの活動や応答が記録されていません。連絡を取ってみてください。',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — ご確認のお願い',
      body: '待機時間を過ぎましたが、{name} 様の端末から信号が届いていません。様子を確認してください。',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — ご安心ください',
      body: '{name} 様が通常の活動を確認しました。見守りインシデントは解消されました。',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — ご安心ください',
      body: '{name} 様が「大丈夫です」と確認しました。バッテリー: {battery}%。{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Evernear 見守りシステムからの新しい通知です。',
    },
  },

  // 9. Korean
  ko: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — 괜찮으신가요?',
      body: '설정된 시간 동안 새로운 활동이 감지되지 않았습니다. 탭하여 안전을 확인해 주세요.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — 안부 확인 알림',
      body: '여기를 탭하여 활동 상태를 확인해 주세요.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — 안부 알림',
      body: '{name} 님의 활동이나 응답이 기록되지 않았습니다. 연락을 취해 보시는 것을 권장합니다.',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — 주의 필요',
      body: '대기 시간이 초과되었으나 {name} 님의 기기에서 신호가 감지되지 않았습니다. 확인해 주시기 바랍니다.',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — 안심',
      body: '{name} 님이 정상 활동을 확인했습니다. 모니터링 상황이 완료되었습니다.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — 안심 알림',
      body: '{name} 님이 "괜찮아요"라고 확인했습니다. 배터리: {battery}%.{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Evernear 케어 시스템의 새로운 알림입니다.',
    },
  },

  // 10. Chinese (Simplified)
  zh: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — 您一切都好吗？',
      body: '在设定的时间段内未检测到新的活动。点击以确认您一切安好。',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — 确认提醒',
      body: '请点击此处以确认您的活动状态。',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — 关怀提醒',
      body: '尚未记录到来自 {name} 的活动或回应。您可以尝试联系询问。',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — 需注意',
      body: '已超出等待时间，仍未收到来自 {name} 设备的信息。请及时核实情况。',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — 恢复安心',
      body: '{name} 已确认活动正常。关怀事件已顺利解决。',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — 报平安',
      body: '{name} 刚刚确认“我很好”。电量：{battery}%。{note}',
    },
    default: {
      title: 'Evernear',
      body: '来自 Evernear 关怀系统的新通知。',
    },
  },

  // 11. Thai
  th: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — คุณสบายดีไหม?',
      body: 'ไม่พบกิจกรรมล่าสุดในช่วงเวลาที่กำหนด แตะเพื่อยืนยันว่าคุณปลอดภัยดี',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — แจ้งเตือนการยืนยันตัวตน',
      body: 'โปรดแตะที่นี่เพื่อยืนยันสถานะการทำกิจกรรมของคุณ',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — การแจ้งเตือนความห่วงใย',
      body: 'ไม่พบกิจกรรมหรือการตอบกลับจาก {name} คุณอาจลองติดต่อสอบถามดู',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — ต้องได้รับการตรวจสอบ',
      body: 'หมดเวลารอคอยแล้วแต่ยังไม่ได้รับสัญญาณจากอุปกรณ์ของ {name} โปรดตรวจสอบโดยด่วน',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — สบายใจได้',
      body: '{name} ได้ยืนยันการทำกิจกรรมตามปกติแล้ว การติดตามความปลอดภัยเสร็จสิ้นแล้ว',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — วางใจได้',
      body: '{name} ได้ยืนยันว่า "ฉันสบายดี" แบตเตอรี่: {battery}% {note}',
    },
    default: {
      title: 'Evernear',
      body: 'การแจ้งเตือนใหม่จากระบบ Evernear',
    },
  },

  // 12. Indonesian
  id: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Apakah Anda baik-baik saja?',
      body: 'Tidak ada aktivitas baru yang terdeteksi dalam jadwal. Ketuk untuk mengonfirmasi bahwa Anda baik-baik saja.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Pengingat konfirmasi',
      body: 'Silakan ketuk di sini untuk mengonfirmasi status keaktifan Anda.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Pemberitahuan Perhatian',
      body: 'Belum ada aktivitas atau respons yang tercatat dari {name}. Anda dapat mencoba menghubunginya.',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Perlu Perhatian',
      body: 'Waktu tunggu telah habis tetapi belum ada sinyal dari perangkat {name}. Harap periksa.',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Ketenangan',
      body: '{name} telah mengonfirmasi aktivitas normal. Situasi pemantauan telah diselesaikan.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Tenang',
      body: '{name} baru saja mengonfirmasi "Saya baik-baik saja". Baterai: {battery}%.{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Pemberitahuan baru dari sistem Evernear.',
    },
  },

  // 13. Arabic
  ar: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — هل أنت بخير؟',
      body: 'لم يتم رصد أي نشاط حديث خلال الفترة المحددة. اضغط لتأكيد أنك بخير.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — تذكير بالتأكيد',
      body: 'يرجى الضغط هنا لتأكيد حالتك النشطة.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — إشعار رعاية',
      body: 'لم يتم تسجيل أي نشاط أو استجابة من {name}. قد ترغب في التواصل والاطمئنان عليه.',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — يُرجى الانتباه',
      body: 'انتهت فترة الانتظار دون تلقي إشارة من جهاز {name}. يرجى التحقق.',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — تم الاطمئنان',
      body: 'أكّد {name} نشاطه الطبيعي. تم إغلاق حالة المتابعة بنجاح.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — طمأنينة',
      body: '{name} أكد أنه "بخير". مستوى البطارية: {battery}%.{note}',
    },
    default: {
      title: 'Evernear',
      body: 'إشعار جديد من نظام الرعاية Evernear.',
    },
  },

  // 14. Hindi
  hi: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — क्या आप ठीक हैं?',
      body: 'निर्धारित समय में कोई नई गतिविधि नहीं पाई गई। पुष्टि करने के लिए टैप करें कि आप सुरक्षित हैं।',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — चेक-इन अनुस्मारक',
      body: 'कृपया अपनी गतिविधि की स्थिति की पुष्टि करने के लिए यहाँ टैप करें।',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — देखभाल सूचना',
      body: '{name} से कोई गतिविधि या प्रतिक्रिया दर्ज नहीं की गई है। आप उनसे संपर्क करने का प्रयास कर सकते हैं।',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — ध्यान देने की आवश्यकता',
      body: 'प्रतीक्षा अवधि समाप्त हो गई है लेकिन {name} के उपकरण से कोई संकेत नहीं मिला है। कृपया जांच करें।',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — निश्चिंतता',
      body: '{name} ने सामान्य गतिविधि की पुष्टि की है। निगरानी की स्थिति हल हो गई है।',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — निश्चिंत रहें',
      body: '{name} ने पुष्टि की कि "मैं ठीक हूँ"। बैटरी: {battery}%।{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Evernear देखभाल प्रणाली से नई अधिसूचना।',
    },
  },
  af: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Inklok nodig',
      body: 'Gaan dit goed? Tik om te bevestig.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Veiligheidsinklok',
      body: 'Tik op die knoppie om jou geliefdes te verseker dat jy veilig is.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Geen aktiwiteitsbevestiging ontvang nie',
      body: 'Ongebruikelike tydperk van onaktiwiteit bespeur ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Familie in kennis gestel',
      body: 'Jou gesin is gewaarsku om bystand te verleen. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Opgelos',
      body: '{name}: Voorval veilig opgelos.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Vreedsaam',
      body: '{name} het bevestig: "Ek is oukei"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Begeleiding en beskerming van gemoedsrus vir geliefdes',
    },
  },
  am: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — ማረጋገጫ ያስፈልጋል',
      body: 'ደህና ኖት? ለማረጋገጥ ይንኩ።',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — የደህንነት ማረጋገጫ',
      body: 'ደህንነትዎ የተጠበቀ መሆኑን ለቤተሰብዎ ለማረጋገጥ አዝራሩን ይንኩ።',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — ምንም የእንቅስቃሴ ማረጋገጫ አልደረሰም',
      body: 'ያልተለመደ የእንቅስቃሴ-አልባነት ጊዜ ተገኝቷል ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — ቤተሰብ እንዲያውቀው ተደርጓል',
      body: 'ቤተሰብዎ ድጋፍ እንዲሰጥዎ ማንቂያ ተልኮለታል። ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — ተፈትቷል',
      body: '{name}: ክስተቱ በሰላም ተፈትቷል።',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — ሰላማዊ',
      body: '{name} አረጋግጧል፡ "ደህና ነኝ"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'የውድ ሰዎችዎን የአእምሮ ሰላም ማጀብ እና መጠበቅ',
    },
  },
  az: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Qeydiyyat tələb olunur',
      body: 'Hər şey qaydasındadırmı? Təsdiq üçün toxunun.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Təhlükəsizlik Qeydiyyatı',
      body: 'Doğmalarınızı təhlükəsiz olduğunuza əmin etmək üçün düyməyə toxunun.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Heç bir fəaliyyət təsdiqi alınmadı',
      body: 'Qeyri-adi hərəkətsizlik dövrü aşkar edildi ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Ailəyə xəbərdarlıq göndərildi',
      body: 'Dəstək göstərməsi üçün ailənizə xəbərdarlıq göndərildi. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Həll edildi',
      body: '{name}: Hadisə təhlükəsiz şəkildə həll edildi.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Dinc',
      body: '{name} təsdiqlədi: "Mən yaxşıyam"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Yaxınlarınız üçün könül rahatlığının qorunması və müşayiət',
    },
  },
  bg: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Необходимо е потвърждение',
      body: 'Добре ли сте? Докоснете за потвърждение.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Проверка за безопасност',
      body: 'Докоснете бутона, за да уверите близките си, че сте в безопасност.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Не е получено потвърждение за активност',
      body: 'Отчетен е необичаен период на неактивност ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Семейството е уведомено',
      body: 'Вашето семейство беше предупредено, за да ви окаже подкрепа. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Разрешено',
      body: '{name}: Инцидентът е разрешен успешно.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Спокойно',
      body: '{name} потвърди: „Добре съм“! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Придружаване и защита на спокойствието за любимите хора',
    },
  },
  bn: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — চেক-ইন প্রয়োজন',
      body: 'আপনি ভালো আছেন? নিশ্চিত করতে স্পর্শ করুন।',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — নিরাপত্তা চেক-ইন',
      body: 'আপনি নিরাপদে আছেন তা আপনার প্রিয়জনদের আশ্বস্ত করতে বোতামটিতে ট্যাপ করুন।',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — কোনো কার্যকলাপ নিশ্চিতকরণ পাওয়া যায়নি',
      body: 'অস্বাভাবিক নিষ্ক্রিয়তার সময় শনাক্ত হয়েছে ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — পরিবারকে অবহিত করা হয়েছে',
      body: 'সহায়তা প্রদানের জন্য আপনার পরিবারকে সতর্ক করা হয়েছে। ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — সমাধান হয়েছে',
      body: '{name}: ঘটনাটি নিরাপদে সমাধান হয়েছে।',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — শান্তিপূর্ণ',
      body: '{name} নিশ্চিত করেছেন: "আমি ঠিক আছি"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'প্রিয়জনদের মনের শান্তি রক্ষা ও সঙ্গ প্রদান',
    },
  },
  ca: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Cal confirmació',
      body: 'Tot va bé? Toca per confirmar.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Confirmació de seguretat',
      body: 'Toca el botó per tranquil·litzar els teus éssers estimats que estàs fora de perill.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — No s\'ha rebut cap confirmació d\'activitat',
      body: 'S\'ha detectat un període inusual d\'inactivitat ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Família notificada',
      body: 'La teva família ha estat alertada per oferir ajuda. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Resolt',
      body: '{name}: Incident resolt de manera segura.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Tranquil',
      body: '{name} ha confirmat: "Estic bé"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Acompanyant i protegint la tranquil·litat dels teus éssers estimats',
    },
  },
  cs: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Nutná kontrola',
      body: 'Jste v pořádku? Klepnutím potvrďte.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Bezpečnostní kontrola',
      body: 'Klepnutím na tlačítko ujistěte své blízké, že jste v bezpečí.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Nebylo přijato žádné potvrzení aktivity',
      body: 'Zjištěna neobvyklá doba neaktivního stavu ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Rodina upozorněna',
      body: 'Vaše rodina byla upozorněna, aby vám poskytla pomoc. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Vyřešeno',
      body: '{name}: Incident byl bezpečně vyřešen.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Poklidný',
      body: '{name} potvrdil: „Jsem v pořádku“! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Doprovázení a ochrana klidu na duši pro vaše blízké',
    },
  },
  cy: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Angen cadarnhau',
      body: 'Ydych chi’n iawn? Tapiwch i gadarnhau.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Cofrestru Diogelwch',
      body: 'Tapiwch y botwm i dawelu meddwl eich anwyliaid eich bod yn ddiogel.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Ni dderbyniwyd cadarnhad o weithgaredd',
      body: 'Cyfnod anarferol o anweithgarwch wedi\'i ganfod ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Teulu wedi\'i hysbysu',
      body: 'Mae eich teulu wedi\'i rybuddio i gynnig cymorth. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Wedi\'i ddatrys',
      body: '{name}: Digwyddiad wedi\'i ddatrys yn ddiogel.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Heddychlon',
      body: '{name}: "Rwy\'n iawn"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Cyd-fynd a Diogelu heddwch meddwl i anwyliaid',
    },
  },
  da: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Check-in påkrævet',
      body: 'Har du det godt? Tryk for at bekræfte.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Sikkerhedstjek',
      body: 'Tryk på knappen for at berolige dine kære med, at du er i sikkerhed.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Ingen aktivitetsbekræftelse modtaget',
      body: 'Ukarakteristisk periode med inaktivitet registreret ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Familie underrettet',
      body: 'Din familie er blevet alarmeret for at yde hjælp. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Løst',
      body: '{name}: Hændelse løst sikkert.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Fredeligt',
      body: '{name} bekræftede: "Jeg er okay"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Ledsager og beskytter trygheden for dine kære',
    },
  },
  el: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Απαιτείται check-in',
      body: 'Είστε καλά; Πατήστε επιβεβαίωση.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Έλεγχος ασφαλείας',
      body: 'Πατήστε το κουμπί για να καθησυχάσετε τους αγαπημένους σας ότι είστε ασφαλείς.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Δεν ελήφθη επιβεβαίωση δραστηριότητας',
      body: 'Εντοπίστηκε ασυνήθιστη περίοδος αδράνειας ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Η οικογένεια ειδοποιήθηκε',
      body: 'Η οικογένειά σας έχει ειδοποιηθεί για να παράσχει υποστήριξη. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Επιλύθηκε',
      body: '{name}: Το συμβάν επιλύθηκε με ασφάλεια.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Ειρηνικό',
      body: '{name} επιβεβαίωσε: "Είμαι εντάξει"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Συνοδεύοντας & Προστατεύοντας την ηρεμία των αγαπημένων σας προσώπων',
    },
  },
  et: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Kinnitamine vajalik',
      body: 'Kas kõik on korras? Puuduta kinnitamiseks.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Ohutuskontroll',
      body: 'Puudutage nuppu, et kinnitada lähedastele, et olete turvaliselt hoitud.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Tegevuse kinnitust ei saabunud',
      body: 'Tuvastati ebatavaliselt pikk tegevusetus ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Perekonda teavitatud',
      body: 'Teie perekonnale on saadetud hoiatus abi osutamiseks. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Lahendatud',
      body: '{name}: Juhtum on turvaliselt lahendatud.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Rahulik',
      body: '{name} kinnitas: "Minuga on kõik korras"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Lähedaste saatmine ja meelerahu kaitsmine',
    },
  },
  eu: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Egiaztapena beharrezkoa',
      body: 'Ondo zaude? Ukitu berresteko.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Segurtasun-egiaztapena',
      body: 'Sakatu botoia zure hurbilekoei seguru zaudela jakinarazteko.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Ez da jarduera-baieztapenik jaso',
      body: 'Ezohiko jarduerarik eza detektatu da ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Familia jakinarazia',
      body: 'Zure familiari alerta bidali zaio laguntza eman diezazun. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Ebatzita',
      body: '{name}: Gertaera segurtasunez ebatzi da.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Baketsua',
      body: '{name}-k baieztatu du: "Ongi nago"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Maiteen bidelagun izaten eta lasaitasuna babesten',
    },
  },
  fa: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — نیاز به اعلام وضعیت',
      body: 'حالتان خوب است؟ برای تأیید ضربه بزنید.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — اعلام وضعیت ایمنی',
      body: 'روی دکمه ضربه بزنید تا به عزیزانتان اطمینان دهید که ایمن هستید.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — هیچ تأیید فعالیتی دریافت نشد',
      body: 'دوره عدم فعالیت غیرعادی شناسایی شد ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — خانواده مطلع شدند',
      body: 'به خانواده شما هشدار داده شد تا برای پشتیبانی اقدام کنند. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — حل شده',
      body: '{name}: حادثه با خیال راحت حل و فصل شد.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — صلح آمیز',
      body: '{name} تایید کرد: "من خوبم"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'همراهی و محافظت از آرامش خاطر عزیزان',
    },
  },
  fi: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Kirjautuminen tarvitaan',
      body: 'Onko kaikki hyvin? Vahvista napauttamalla.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Turvallisuuskirjautuminen',
      body: 'Napauta painiketta kertoaksesi läheisillesi, että olet turvassa.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Aktiivisuusvahvistusta ei saatu',
      body: 'Havaittu poikkeuksellinen toimettomuusjakso ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Perheelle ilmoitettu',
      body: 'Perheellesi on ilmoitettu avun tarjoamiseksi. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Ratkaistu',
      body: '{name}: Tapahtuma ratkaistu turvallisesti.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Rauhallista',
      body: '{name} vahvisti: "Olen kunnossa"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Läheisten tukena ja mielenrauhan turvana',
    },
  },
  ga: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Seiceáil isteach de dhíth',
      body: 'An bhfuil tú ceart go leor? Tapáil le deimhniú.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Seiceáil Sábháilteachta',
      body: 'Tapáil an cnaipe chun a chur in iúl do do mhuintir go bhfuil tú sábháilte.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Ní bhfuarthas aon deimhniú gníomhaíochta',
      body: 'Tréimhse neamhghníomhaíochta neamhghnách braite ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Fógra curtha chuig an teaghlach',
      body: 'Cuireadh foláireamh chuig do theaghlach chun tacaíocht a thabhairt. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Réitithe',
      body: '{name}: Eachtra réitithe go sábháilte.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Síochánta',
      body: '{name} dheimhnigh: "Tá mé ceart go leor"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Ag tacú le daoine muinteartha agus ag cosaint a suaimhneas intinne',
    },
  },
  gl: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Precísase confirmación',
      body: 'Vai todo ben? Toca para confirmar.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Rexistro de seguranza',
      body: 'Toca o botón para darlle tranquilidade á túa familia de que estás ben.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Non se recibiu confirmación de actividade',
      body: 'Detectouse un período inusual de inactividade ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Familia avisada',
      body: 'Avisouse á túa familia para prestar axuda. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Resolto',
      body: '{name}: Incidente resolto con seguranza.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Tranquilo',
      body: '{name} confirmou: "Estou ben"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Acompañando e protexendo a tranquilidade dos teus seres queridos',
    },
  },
  he: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — נדרשת בדיקה',
      body: 'האם הכל כשורה? הקש לאישור.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — בדיקת ביטחון',
      body: 'הקש על הכפתור כדי להרגיע את יקיריך שאתה בטוח.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — לא התקבל אישור פעילות',
      body: 'זוהתה תקופה חריגה של חוסר פעילות ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — המשפחה עודכנה',
      body: 'המשפחה שלך קיבלה התראה כדי להושיט עזרה. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — נפתר',
      body: '{name}: האירוע נפתר בבטחה.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — שליו',
      body: '{name} אישר: "אני בסדר"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'ליווי והגנה על השקט הנפשי של האנשים היקרים לך',
    },
  },
  hr: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Potrebna prijava',
      body: 'Jeste li dobro? Dodirnite za potvrdu.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Sigurnosna prijava',
      body: 'Dodirnite gumb kako biste umirili svoje najmilije da ste na sigurnom.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Nije primljena potvrda aktivnosti',
      body: 'Otkriveno je neuobičajeno razdoblje neaktivnosti ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Obitelj je obaviještena',
      body: 'Vaša obitelj je upozorena kako bi vam pružila podršku. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Riješeno',
      body: '{name}: Incident je sigurno riješen.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Mirno',
      body: '{name} potvrdio: "Dobro sam"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Praćenje i zaštita duševnog mira za vaše najmilije',
    },
  },
  hu: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Bejelentkezés szükséges',
      body: 'Minden rendben? Érintse meg a megerősítéshez.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Biztonsági bejelentkezés',
      body: 'Koppintson a gombra, hogy megnyugtassa szeretteit, hogy biztonságban van.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Nem érkezett aktivitási megerősítés',
      body: 'Szokatlanul hosszú inaktivitás észlelve ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Család értesítve',
      body: 'A családja értesítést kapott a segítségnyújtáshoz. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Megoldva',
      body: '{name}: Incidens biztonságosan megoldva.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Békés',
      body: '{name} megerősítette: "Jól vagyok"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Szerettei kísérése és lelki békéjének védelme',
    },
  },
  is: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Innritunar krafist',
      body: 'Er allt í lagi? Pikkaðu til að staðfesta.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Öryggisinnritun',
      body: 'Ýttu á hnappinn til að fullvissa ástvini þína um að þú sért óhultur.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Engin virknistaðfesting barst',
      body: 'Óvenjuleg óvirkni greind ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Fjölskyldu tilkynnt',
      body: 'Fjölskyldu þinni hefur verið gert viðvart til að veita aðstoð. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Leyst',
      body: '{name}: Atvik leyst á öruggan hátt.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Friðsælt',
      body: '{name} staðfesti: „Ég er í lagi“! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Fylgjumst með og tryggjum hugarró fyrir ástvini',
    },
  },
  it: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Richiesto check-in',
      body: 'Va tutto bene? Tocca per confermare.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Conferma sicurezza',
      body: 'Premi il pulsante per rassicurare i tuoi cari che stai bene.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Nessuna conferma di attività ricevuta',
      body: 'Inattività prolungata insolita ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Famiglia notificata',
      body: 'I familiari sono stati allertati per offrire supporto. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Risolto',
      body: '{name}: Incidente risolto in sicurezza.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Tranquillo',
      body: '{name} ha confermato: "Sto bene"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Accompagnare e proteggere la serenità dei tuoi cari',
    },
  },
  kk: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Растау қажет',
      body: 'Жағдайыңыз қалай? Растау үшін басыңыз.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Қауіпсіздікті растау',
      body: 'Жақындарыңызға аман-есен екеніңізді білдіру үшін түймені басыңыз.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Белсенділік туралы растау алынбады',
      body: 'Белсенділіктің ұзақ уақыт бойы болмауы анықталды ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Отбасына хабарланды',
      body: 'Көмек көрсету үшін отбасыңызға ескерту жіберілді. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Шешілді',
      body: '{name}: Оқиға сәтті әрі қауіпсіз шешілді.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Бейбіт',
      body: '{name} растады: "Менде бәрі жақсы"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Жақындарыңызға қамқорлық жасау және көңіл тыныштығын қорғау',
    },
  },
  km: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — ត្រូវការការបញ្ជាក់សុខទុក្ខ',
      body: 'តើអ្នកសុខសប្បាយទេ? ចុចដើម្បីបញ្ជាក់។',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — ការបញ្ជាក់សុវត្ថិភាព',
      body: 'ចុចប៊ូតុងដើម្បីឱ្យមនុស្សជាទីស្រឡាញ់របស់អ្នកដឹងថាអ្នកសុខសប្បាយជាទេ។',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — មិនបានទទួលការបញ្ជាក់សកម្មភាពទេ',
      body: 'បានរកឃើញរយៈពេលអសកម្មខុសពីធម្មតា ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — បានជូនដំណឹងដល់គ្រួសារ',
      body: 'ក្រុមគ្រួសាររបស់អ្នកត្រូវបានជូនដំណឹងដើម្បីផ្តល់ការគាំទ្រ។ ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — បានដោះស្រាយ',
      body: '{name}: ឧប្បត្តិហេតុត្រូវបានដោះស្រាយដោយសុវត្ថិភាព។',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — សន្តិភាព',
      body: '{name} បញ្ជាក់៖ "ខ្ញុំមិនអីទេ"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'រួមដំណើរ និងការពារភាពស្ងប់ចិត្តសម្រាប់មនុស្សជាទីស្រឡាញ់',
    },
  },
  lo: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — ຕ້ອງການການຢືນຢັນ',
      body: 'ເຈົ້າສະບາຍດີບໍ່? ແຕະເພື່ອຢືນຢັນ.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — ການຢືນຢັນຄວາມປອດໄພ',
      body: 'ແຕະປຸ່ມເພື່ອໃຫ້ຄົນທີ່ທ່ານຮັກອຸ່ນໃຈວ່າທ່ານປອດໄພດີ.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — ບໍ່ໄດ້ຮັບການຢືນຢັນການເຄື່ອນໄຫວ',
      body: 'ກວດພົບຊ່ວງເວລາທີ່ບໍ່ມີການເຄື່ອນໄຫວຜິດປົກກະຕິ ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — ແຈ້ງເຕືອນຄອບຄົວແລ້ວ',
      body: 'ຄອບຄົວຂອງທ່ານໄດ້ຮັບການແຈ້ງເຕືອນເພື່ອໃຫ້ການຊ່ວຍເຫຼືອ. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — ແກ້ໄຂແລ້ວ',
      body: '{name}: ແກ້ໄຂເຫດການຢ່າງປອດໄພແລ້ວ.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — ສັນຕິພາບ',
      body: '{name} ຢືນຢັນ: "ຂ້ອຍບໍ່ເປັນຫຍັງ"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'ຮ່ວມເດີນທາງ ແລະ ປົກປ້ອງຄວາມອຸ່ນໃຈໃຫ້ຄົນທີ່ທ່ານຮັກ',
    },
  },
  lt: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Reikalingas patvirtinimas',
      body: 'Ar viskas gerai? Palieskite patvirtinti.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Saugumo patvirtinimas',
      body: 'Palieskite mygtuką, kad nuramintumėte artimuosius, jog esate saugūs.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Negautas aktyvumo patvirtinimas',
      body: 'Užfiksuotas neįprastai ilgas neaktyvumo laikotarpis ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Šeimai pranešta',
      body: 'Jūsų šeimai pranešta, kad suteiktų pagalbą. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Išspręsta',
      body: '{name}: Įvykis sėkmingai išspręstas.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Ramus',
      body: '{name} patvirtino: „Man viskas gerai“! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Rūpestis ir ramybės saugojimas jūsų artimiesiems',
    },
  },
  lv: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Nepieciešama reģistrēšanās',
      body: 'Vai viss kārtībā? Pieskarieties apstiprināšanai.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Drošības reģistrēšanās',
      body: 'Pieskarieties pogai, lai nomierinātu tuviniekus, ka esat drošībā.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Nav saņemts aktivitātes apstiprinājums',
      body: 'Konstatēts neparasti ilgs bezdarbības periods ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Ģimenei paziņots',
      body: 'Jūsu ģimene ir brīdināta, lai sniegtu atbalstu. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Atrisināts',
      body: '{name}: Incidents veiksmīgi atrisināts.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Mierīgs',
      body: '{name} apstiprināja: "Ar mani viss kārtībā"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Rūpes un sirdsmiera aizsardzība jūsu mīļajiem',
    },
  },
  mn: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Баталгаажуулалт шаардлагатай',
      body: 'Таны бие сайн уу? Баталгаажуулах товч дарна уу.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Аюулгүй байдлаа мэдэгдэх',
      body: 'Хайртай хүмүүстээ зүгээр байгаагаа мэдэгдэхийн тулд товчийг дарна уу.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Идэвхтэй байдлын баталгаажуулалт ирээгүй',
      body: 'Хэт удаан хөдөлгөөнгүй байдал илэрсэн ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Гэр бүлд мэдэгдсэн',
      body: 'Танд тусламж үзүүлэхээр гэр бүлд тань сэрэмжлүүлэг илгээлээ. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Шийдвэрлэсэн',
      body: '{name}: Тохиолдлыг аюулгүй шийдвэрлэлээ.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Амар амгалан',
      body: '{name} баталсан: "Би зүгээр"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Хайртай дотны хүмүүсийнхээ амар амгаланг хамгаалж, хамтдаа',
    },
  },
  mr: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — पुष्टी आवश्यक आहे',
      body: 'सर्व ठीक आहे ना? पुष्टी करण्यासाठी स्पर्श करा.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — सुरक्षितता तपासणी',
      body: 'तुम्ही सुरक्षित आहात याची आपल्या प्रियजनांना खात्री देण्यासाठी बटणावर स्पर्श करा.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — कोणतीही हालचालीची पुष्टी मिळाली नाही',
      body: 'असामान्य काळासाठी कोणतीही हालचाल आढळली नाही ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — कुटुंबाला सूचित केले',
      body: 'मदत करण्यासाठी तुमच्या कुटुंबाला सतर्क करण्यात आले आहे. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — निराकरण झाले',
      body: '{name}: घटनेचे सुरक्षितपणे निराकरण झाले.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — शांततापूर्ण',
      body: '{name} पुष्टी केली: "मी ठीक आहे"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'आपल्या प्रियजनांची काळजी आणि सुरक्षिततेची खात्री',
    },
  },
  ms: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Daftar masuk diperlukan',
      body: 'Adakah anda sihat? Ketik untuk sahkan.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Daftar Masuk Keselamatan',
      body: 'Ketik butang untuk meyakinkan insan tersayang bahawa anda selamat.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Tiada pengesahan aktiviti diterima',
      body: 'Tempoh tidak aktif yang luar biasa dikesan ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Keluarga telah dimaklumkan',
      body: 'Keluarga anda telah dimaklumkan untuk memberikan bantuan. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Diselesaikan',
      body: '{name}: Insiden diselesaikan dengan selamat.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Damai',
      body: '{name} mengesahkan: "Saya okay"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Mendampingi & Menjamin ketenangan jiwa insan tersayang',
    },
  },
  my: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — အတည်ပြုချက် လိုအပ်သည်',
      body: 'နေကောင်းရဲ့လား။ အတည်ပြုရန် နှိပ်ပါ။',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — ဘေးကင်းရေး အတည်ပြုချက်',
      body: 'သင်ဘေးကင်းကြောင်း ချစ်ရသူများ စိတ်ချစေရန် ခလုတ်ကို နှိပ်ပါ။',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — လှုပ်ရှားမှု အတည်ပြုချက် မရရှိပါ',
      body: 'ပုံမှန်မဟုတ်သော မလှုပ်မရှား အချိန်ကာလကို တွေ့ရှိသည် ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — မိသားစုထံ အကြောင်းကြားပြီးပါပြီ',
      body: 'သင့်အား ကူညီနိုင်ရန် သင့်မိသားစုထံ သတိပေးချက် ပို့ထားပါသည်။ ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — ဖြေရှင်းပြီး',
      body: '{name}: ဖြစ်ရပ်ကို ဘေးကင်းစွာ ဖြေရှင်းပြီးပါပြီ။',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — ငြိမ်းချမ်းခြင်း။',
      body: '{name} အတည်ပြုခဲ့သည်- "ကျွန်တော် အဆင်ပြေပါတယ်"။ ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'ချစ်ရသူများအတွက် အတူရှိပေးခြင်းနှင့် စိတ်အေးချမ်းမှုကို ကာကွယ်ပေးခြင်း',
    },
  },
  nl: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Check-in vereist',
      body: 'Gaat alles goed? Tik om te bevestigen.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Veiligheidsbevestiging',
      body: 'Tik op de knop om uw dierbaren gerust te stellen dat u veilig bent.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Geen activiteitsbevestiging ontvangen',
      body: 'Ongebruikelijk lange inactiviteit ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Familie gewaarschuwd',
      body: 'Uw familie is gewaarschuwd om u te helpen. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Opgelost',
      body: '{name}: Incident veilig opgelost.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Vreedzaam',
      body: '{name} bevestigde: "Het gaat goed met mij"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Gemoedsrust en veiligheid voor uw dierbaren',
    },
  },
  no: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Innsjekking nødvendig',
      body: 'Har du det bra? Trykk for å bekrefte.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Sikkerhetssjekk',
      body: 'Trykk på knappen for å berolige dine nærmeste om at du har det bra.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Ingen aktivitetsbekreftelse mottatt',
      body: 'Uvanlig lang periode med inaktivitet oppdaget ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Familien er varslet',
      body: 'Familien din er varslet for å kunne gi støtte. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Løst',
      body: '{name}: Hendelsen er trygt løst.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Fredelig',
      body: '{name} bekreftet: "Jeg er ok"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Omsorg og trygghet for dine nærmeste',
    },
  },
  pl: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Wymagane potwierdzenie',
      body: 'Czy wszystko u Ciebie dobrze? Dotknij, aby potwierdzić.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Potwierdzenie bezpieczeństwa',
      body: 'Dotknij przycisku, aby uspokoić bliskich, że czujesz się dobrze.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Brak potwierdzenia aktywności',
      body: 'Niezwykle długa bezczynność ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Powiadomiono bliskich',
      body: 'Bliscy zostali powiadomieni, aby udzielić Ci wsparcia. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Rozwiązano',
      body: '{name}: Incydent bezpiecznie rozwiązany.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Spokojnie',
      body: '{name} potwierdził: „U mnie wszystko w porządku”! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Troska i bezpieczeństwo dla Twoich bliskich',
    },
  },
  ro: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Este necesară confirmarea',
      body: 'Ești bine? Atinge pentru a confirma.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Confirmare de siguranță',
      body: 'Atinge butonul pentru a-i asigura pe cei dragi că ești în siguranță.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Nicio confirmare de activitate primită',
      body: 'S-a detectat o perioadă neobișnuită de inactivitate ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Familia a fost notificată',
      body: 'Familia ta a fost alertată pentru a oferi sprijin. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Rezolvat',
      body: '{name}: Incidentul a fost rezolvat în siguranță.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Pașnic',
      body: '{name} a confirmat: „Sunt bine”! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Însoțire și protejare a liniștii sufletești pentru cei dragi',
    },
  },
  sk: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Potrebný check-in',
      body: 'Ste v poriadku? Ťuknutím potvrďte.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Bezpečnostný check-in',
      body: 'Ťuknite na tlačidlo, aby ste uistili svojich blízkych, že ste v bezpečí.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Nebolo prijaté žiadne potvrdenie aktivity',
      body: 'Zistené nezvyčajné obdobie nečinnosti ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Rodina bola upozornená',
      body: 'Vaša rodina bola upozornená, aby vám poskytla pomoc. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Vyriešené',
      body: '{name}: Incident bol bezpečne vyriešený.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Pokojný',
      body: '{name} potvrdil: „Som v poriadku“! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Sprevádzanie a ochrana pokoja v duši pre vašich blízkych',
    },
  },
  sl: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Potrebna prijava',
      body: 'Ste v redu? Dotaknite se za potrditev.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Varnostna prijava',
      body: 'Dotaknite se gumba, da pomirite svoje ljubljene, da ste na varnem.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Ni prejete potrditve aktivnosti',
      body: 'Zaznano nenavadno obdobje neaktivnosti ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Družina obveščena',
      body: 'Vaša družina je bila opozorjena, da nudi pomoč. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Razrešeno',
      body: '{name}: Dogodek varno razrešen.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Mirno',
      body: '{name} potrjen: "V redu sem"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Spremljanje in varovanje duševnega miru za vaše ljubljene',
    },
  },
  sr: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Потребна пријава',
      body: 'Да ли сте добро? Додирните за потврду.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Безбедносна пријава',
      body: 'Додирните дугме да уверите своје вољене да сте безбедни.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Није примљена потврда активности',
      body: 'Откривен је необичан период неактивности ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Породица обавештена',
      body: 'Ваша породица је обавештена да пружи помоћ. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Решено',
      body: '{name}: Инцидент је безбедно решен.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Мирно',
      body: '{name} потврдио: „Ја сам добро“! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Праћење и заштита душевног мира за ваше вољене',
    },
  },
  sv: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Incheckning krävs',
      body: 'Mår du bra? Tryck för att bekräfta.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Trygghetsincheckning',
      body: 'Tryck på knappen för att försäkra dina nära och kära om att du är trygg.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Ingen aktivitetsbekräftelse mottagen',
      body: 'Ovanlig inaktivitetsperiod upptäckt ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Familj meddelad',
      body: 'Din familj har larmats för att ge stöd. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Löst',
      body: '{name}: Händelsen löstes tryggt.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Fridfullt',
      body: '{name} bekräftade: "Jag är okej"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Följeslagare och trygghet för nära och kära',
    },
  },
  sw: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Ukaguzi unahitajika',
      body: 'Uko salama? Gusa ili kuthibitisha.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Ukaguzi wa Usalama',
      body: 'Gusa kitufe ili kuwahakikishia wapendwa wako kuwa uko salama.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Hakuna uthibitisho wa shughuli uliopokelewa',
      body: 'Kipindi kisicho cha kawaida cha kutokuwa na shughuli kimegunduliwa ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Familia imearifiwa',
      body: 'Familia yako imearifiwa ili kutoa usaidizi. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Imetatuliwa',
      body: '{name}: Tukio limetatuliwa kwa usalama.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Mwenye amani',
      body: '{name} alithibitisha: "Niko sawa"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Kuandamana na Kulinda amani ya akili kwa wapendwa',
    },
  },
  ta: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — செக்-இன் தேவை',
      body: 'சரியாக இருக்கிறீர்களா? உறுதிப்படுத்த தொடவும்.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — பாதுகாப்பு செக்-இன்',
      body: 'நீங்கள் பாதுகாப்பாக இருப்பதை அன்புக்குரியவர்களுக்கு உறுதிப்படுத்த பொத்தானைத் தட்டவும்.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — செயல்பாட்டு உறுதிப்படுத்தல் எதுவும் பெறப்படவில்லை',
      body: 'வழக்கத்திற்கு மாறான செயலற்ற நேரம் கண்டறியப்பட்டது ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — குடும்பத்தினருக்கு தெரிவிக்கப்பட்டது',
      body: 'உங்களுக்கு உதவ உங்கள் குடும்பத்தினருக்கு எச்சரிக்கை விடுக்கப்பட்டுள்ளது. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — தீர்க்கப்பட்டது',
      body: '{name}: சம்பவம் பாதுகாப்பாகத் தீர்க்கப்பட்டது.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — அமைதியான',
      body: '{name} உறுதிப்படுத்தினார்: "நான் நன்றாக இருக்கிறேன்"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'அன்புக்குரியவர்களின் மன அமைதிக்கான பாதுகாப்பு மற்றும் துணை',
    },
  },
  te: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — చెక్-ఇన్ అవసరం',
      body: 'బాగున్నారా? నిర్ధారించడానికి నొక్కండి.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — సేఫ్టీ చెక్-ఇన్',
      body: 'మీరు క్షేమంగా ఉన్నారని మీ ప్రియమైనవారికి తెలియజేయడానికి బటన్‌ను నొక్కండి.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — ఎటువంటి కార్యాచరణ నిర్ధారణ అందలేదు',
      body: 'అసాధారణ నిష్క్రియా కాలం గుర్తించబడింది ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — కుటుంబానికి తెలియజేయబడింది',
      body: 'మీకు మద్దతు ఇవ్వడానికి మీ కుటుంబానికి హెచ్చరిక పంపబడింది. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — పరిష్కరించబడింది',
      body: '{name}: సంఘటన సురక్షితంగా పరిష్కరించబడింది.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — శాంతియుతమైనది',
      body: '{name} ధృవీకరించారు: "నేను బాగానే ఉన్నాను"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'ప్రియమైనవారి భద్రత మరియు మనశ్శాంతికి తోడుగా',
    },
  },
  tl: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Kailangan ng pag-check-in',
      body: 'Maayos ka ba? I-tap upang kumpirmahin.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Pag-check-in sa Kaligtasan',
      body: 'I-tap ang button para tiyakin sa iyong mga mahal sa buhay na ligtas ka.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Walang natanggap na kumpirmasyon ng aktibidad',
      body: 'Di-karaniwang tagal ng kawalan ng aktibidad ang natukoy ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Naabisuhan ang pamilya',
      body: 'Naalerto ang iyong pamilya upang magbigay ng tulong. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Nalutas',
      body: '{name}: Ligtas na nalutas ang insidente.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Mapayapa',
      body: '{name} kinumpirma: "Okay lang ako"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Kaagapay at Nagpoprotekta sa kapayapaan ng isip para sa mga mahal sa buhay',
    },
  },
  fil: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Kailangan ng pag-check-in',
      body: 'Maayos ka ba? I-tap upang kumpirmahin.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Pag-check-in sa Kaligtasan',
      body: 'I-tap ang button para tiyakin sa iyong mga mahal sa buhay na ligtas ka.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Walang natanggap na kumpirmasyon ng aktibidad',
      body: 'Di-karaniwang tagal ng kawalan ng aktibidad ang natukoy ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Naabisuhan ang pamilya',
      body: 'Naalerto ang iyong pamilya upang magbigay ng tulong. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Nalutas',
      body: '{name}: Ligtas na nalutas ang insidente.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Mapayapa',
      body: '{name} kinumpirma: "Okay lang ako"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Kaagapay at Nagpoprotekta sa kapayapaan ng isip para sa mga mahal sa buhay',
    },
  },
  tr: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Yoklama gerekiyor',
      body: 'İyi misiniz? Onaylamak için dokunun.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Güvenlik Bildirimi',
      body: 'Güvende olduğunuzu sevdiklerinize bildirmek için dokunun.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Aktivite onayı alınamadı',
      body: 'Alışılmadık uzun hareketsizlik ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Aileye bildirildi',
      body: 'Destek olmaları için ailenize haber verildi. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Çözüldü',
      body: '{name}: Olay güvenle çözüldü.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Huzurlu',
      body: '{name} onayladı: "İyiyim"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Sevdikleriniz için huzur ve güvenlik',
    },
  },
  uk: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Потрібна перевірка',
      body: 'У вас все добре? Торкніться для підтвердження.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Підтвердження безпеки',
      body: 'Натисніть кнопку, щоб заспокоїти близьких.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Немає підтвердження активності',
      body: 'Незвична тривала бездіяльність ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Рідні сповіщені',
      body: 'Рідних сповіщено для надання допомоги. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Вирішено',
      body: '{name}: Подію безпечно вирішено.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Спокійно',
      body: '{name} підтвердив: "Я в порядку"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Турбота та безпека ваших близьких',
    },
  },
  ur: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — چیک ان درکار ہے',
      body: 'کیا آپ خیریت سے ہیں؟ تصدیق کے لیے ٹیپ کریں۔',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — حفاظتی چیک ان',
      body: 'اپنے پیاروں کو یقین دلانے کے لیے بٹن دبائیں کہ آپ محفوظ ہیں۔',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — کوئی سرگرمی کی تصدیق موصول نہیں ہوئی',
      body: 'غیر معمولی غیر فعال مدت کا پتہ چلا ہے ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — خاندان کو مطلع کر دیا گیا',
      body: 'آپ کی مدد کے لیے آپ کے خاندان کو الرٹ کر دیا گیا ہے۔ ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — حل شدہ',
      body: '{name}: واقعہ بحفاظت حل ہو گیا۔',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — پرامن',
      body: '{name} نے تصدیق کی: "میں ٹھیک ہوں"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'پیاروں کے ذہنی سکون کی دیکھ بھال اور حفاظت کا ساتھی',
    },
  },
  uz: {
    CHECK_IN_PROMPT: {
      title: 'Evernear — Tasdiqlash kerak',
      body: 'Ahvolingiz yaxshimi? Tasdiqlash uchun bosing.',
    },
    CHECK_IN_REMINDER: {
      title: 'Evernear — Xavfsizlikni tasdiqlash',
      body: 'Yaqinlaringizga xavfsiz ekanligingizni bildirish uchun tugmani bosing.',
    },
    MONITOR_INACTIVITY_WARNING: {
      title: 'Evernear — Faollik tasdigʻi qabul qilinmadi',
      body: 'Noodatiy uzoq nofaollik vaqti aniqlandi ({name})',
    },
    MONITOR_ESCALATION: {
      title: 'Evernear — Oilaga xabar berildi',
      body: 'Sizga yordam berish uchun oilangizga ogohlantirish yuborildi. ({name})',
    },
    INCIDENT_RESOLVED: {
      title: 'Evernear — Hal qilindi',
      body: '{name}: Hodisa xavfsiz tarzda hal qilindi.',
    },
    CHECK_IN_CONFIRMED: {
      title: 'Evernear — Tinch',
      body: '{name} tasdiqladi: "Men yaxshiman"! ({battery}%).{note}',
    },
    default: {
      title: 'Evernear',
      body: 'Yaqinlaringiz xotirjamligini himoya qilish va hamroh boʻlish',
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
    locale = 'en',
  ): RenderedTemplate {
    const normalizedLocale = (locale || 'en').toLowerCase().split(/[-_]/)[0];

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
      resolvedLang = TEMPLATE_DICTIONARIES[normalizedLocale]?.default ? normalizedLocale : 'en';
    }

    // Parameter substitution ({name} and legacy ${name})
    const defaultName = DEFAULT_NAMES[resolvedLang] || DEFAULT_NAMES['en'];
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
