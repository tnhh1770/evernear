class AppStrings {
  static const String appName = 'Evernear';
  static const String appTagline = 'Đồng hành & Bảo vệ bình an cho người thân';
  static const String appDescription =
      'Evenear là ứng dụng giám sát không xâm phạm quyền riêng tư, giúp bạn và người thân luôn an tâm với hệ thống theo dõi hoạt động thông minh, nhẹ nhàng và đáng tin cậy.';

  // Check-in (Calm 1-touch)
  static const String checkInPrompt = 'Bạn vẫn ổn chứ? Vui lòng chạm để xác nhận.';
  static const String checkInButton = 'Tôi vẫn ổn';
  static const String checkInSubPrompt = 'Nhấn để xác nhận';
  static const String checkInSuccess = 'Đã gửi xác nhận bình an thành công.';
  static const String checkInDialogTitle = 'Tuyệt vời!\nBạn vẫn ổn!';
  static const String checkInDialogDesc =
      'Người thân của bạn ({name}) đã nhận được thông báo bạn vẫn bình an và sinh hoạt ổn định lúc {time}.';
  static const String checkInGuardianNotif = '{name} vừa xác nhận: "Tôi vẫn ổn"!';
  static const String checkInOfflineSuccess =
      'Đã lưu xác nhận an toàn vào bộ nhớ máy. Ứng dụng sẽ tự động gửi khi có mạng';
  static const String checkInNoteHint = 'Ghi chú thêm (không bắt buộc, vd: Đang nấu ăn...)';

  // States (Neutral, reassuring, positive)
  static const String stateActive = 'Bạn đang được bảo vệ';
  static const String stateCheckInRequired = 'Cần kiểm tra';
  static const String stateGracePeriod = 'Chờ phản hồi';
  static const String stateAlertTriggered = 'Không nhận được xác nhận';
  static const String stateAcknowledged = 'Đã liên hệ người thân';
  static const String stateResolved = 'Đã khôi phục trạng thái';
  static const String statePaused = 'Chế độ tạm dừng';

  // State descriptions & Escalation reassurance
  static const String stateActiveDesc = 'Hệ thống ghi nhận hoạt động bình thường, người thân an tâm.';
  static const String stateCheckInRequiredDesc = 'Bạn vẫn ổn chứ? Vui lòng chạm để xác nhận.';
  static const String stateGracePeriodDesc = 'Sắp hết thời gian chờ phản hồi. Vui lòng xác nhận để người thân yên tâm.';
  static const String stateAlertTriggeredDesc = 'Người thân đã được thông báo để hỗ trợ bạn.';
  static const String statePausedDesc = 'Chế độ giám sát đang tạm dừng để bảo đảm sự riêng tư.';

  // Guardian View
  static const String guardianStable = 'Đang được bảo vệ';
  static const String guardianContacted = 'Đã liên hệ người thân';

  // Schedule Setup UI
  static const String scheduleTitle = 'Cài đặt giám sát';
  static const String scheduleSubtitle = 'Chọn khung giờ hoạt động và nhắc nhở kiểm tra.';
  static const String applyToAllDays = 'Áp dụng cho cả tuần';
  static const String overnightBadge = 'Khung giờ qua đêm';
  static const String overnightDescription = 'Giám sát bảo vệ xuyên suốt đêm đến sáng hôm sau.';
  static const String dayEnabled = 'Bật giám sát ngày này';
  static const String dayDisabled = 'Tạm nghỉ giám sát ngày này';

  // Notifications & Feeds
  static const String navStatus = 'Trang chủ';
  static const String navFamily = 'Người thân';
  static const String navIncidents = 'Thông báo';
  static const String navSettings = 'Cài đặt';
  static const String notificationsTitle = 'Thông báo & sự kiện';
  static const String filterAll = 'Tất cả';
  static const String filterCheckIns = 'An toàn';
  static const String filterIncidents = 'Cảnh báo';
  static const String filterResolved = 'Xử lý';
  static const String checkInFeedTitle = '{name} đã xác nhận an toàn';
  static const String checkInBadgePeace = 'An toàn';
  static const String checkInDetailTitle = 'Xác nhận an toàn';
  static const String notificationsEmptyAll =
      'Chưa có thông báo nào. Mọi hoạt động của gia đình đều an toàn và ổn định.';
  static const String notificationsMarkAllRead = 'Đã đọc tất cả';
  static const String notificationUnreadBadge = 'Mới';

  // Incidents
  static const String incidentsTitle = 'Thông báo & sự kiện';
  static const String incidentMissedCheckIn = 'Không nhận được xác nhận trong thời gian dự kiến';
  static const String incidentExtendedInactivity = 'Khoảng lặng bất thường trong sinh hoạt';
  static const String acknowledgeButton = 'Xác nhận đã liên hệ';
  static const String resolveButton = 'Đánh dấu đã giải quyết';
  static const String incidentResolvedNotice = 'Đã khôi phục trạng thái • Hiện tại: An toàn';

  // Calm UX Reusables
  static const String retryButton = 'Thử lại';
  static const String calmLoading = 'Đang đồng bộ dữ liệu an tâm...';
  static const String calmEmptyIncidentsTitle = 'Mọi thứ đều bình an';
  static const String calmEmptyIncidentsDesc = 'Hiện không có cảnh báo nào. Người thân đang sinh hoạt an toàn.';

  // Devices & Privacy
  static const String privacyNotice =
      'Chúng tôi chỉ thu thập vị trí một lần khi bạn chủ động xác nhận hoặc có sự cố xảy ra (nếu bạn đồng ý).';
  static const String serverAuthoritativeNotice =
      'Hệ thống máy chủ trung tâm tự động tính toán và cảnh báo độc lập với trạng thái pin hay mạng của điện thoại.';
}

