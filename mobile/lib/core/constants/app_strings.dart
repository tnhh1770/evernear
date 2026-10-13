class AppStrings {
  static const String appName = 'Carely';
  static const String appTagline = 'Đồng hành & Bảo vệ bình an cho người thân';

  // Check-in (Calm 1-touch)
  static const String checkInPrompt = 'Bạn vẫn ổn chứ? Vui lòng chạm để xác nhận.';
  static const String checkInButton = 'Tôi vẫn ổn';
  static const String checkInSuccess = 'Đã gửi xác nhận bình an thành công.';
  static const String checkInDialogTitle = 'Đã gửi thông báo an tâm';
  static const String checkInDialogDesc =
      'Người thân của bạn ({name}) đã nhận được thông báo bạn vẫn bình an và sinh hoạt ổn định lúc {time}.';
  static const String checkInGuardianNotif = '{name} vừa xác nhận: "Tôi vẫn ổn"!';
  static const String checkInOfflineSuccess =
      'Đã lưu xác nhận an toàn vào bộ nhớ máy. Ứng dụng sẽ tự động gửi khi có mạng';
  static const String checkInNoteHint = 'Ghi chú thêm (không bắt buộc, vd: Đang nấu ăn...)';

  // States (Neutral, reassuring, positive)
  static const String stateActive = 'Tình trạng ổn định';
  static const String stateCheckInRequired = 'Cần kiểm tra an tâm';
  static const String stateGracePeriod = 'Chờ phản hồi';
  static const String stateAlertTriggered = 'Đã liên hệ người thân';
  static const String stateAcknowledged = 'Người thân đã tiếp nhận';
  static const String stateResolved = 'Đã hoàn tất hỗ trợ';
  static const String statePaused = 'Đang tạm dừng giám sát';

  // State descriptions & Escalation reassurance
  static const String stateActiveDesc = 'Hệ thống ghi nhận hoạt động bình thường, người thân an tâm.';
  static const String stateCheckInRequiredDesc = 'Bạn vẫn ổn chứ? Vui lòng chạm để xác nhận.';
  static const String stateGracePeriodDesc = 'Sắp hết thời gian chờ phản hồi. Vui lòng xác nhận để người thân yên tâm.';
  static const String stateAlertTriggeredDesc = 'Người thân đã được thông báo để hỗ trợ bạn.';
  static const String statePausedDesc = 'Chế độ giám sát đang tạm dừng để bảo đảm sự riêng tư.';

  // Guardian View
  static const String guardianStable = 'Tình trạng ổn định';
  static const String guardianContacted = 'Đã liên hệ người thân';

  // Schedule Setup UI
  static const String scheduleTitle = 'Lịch giám sát an toàn';
  static const String scheduleSubtitle = 'Chọn khung giờ cần hệ thống đồng hành và gửi lời hỏi thăm.';
  static const String applyToAllDays = 'Áp dụng cho cả tuần';
  static const String overnightBadge = 'Khung giờ qua đêm';
  static const String overnightDescription = 'Giám sát bảo vệ xuyên suốt đêm đến sáng hôm sau.';
  static const String dayEnabled = 'Bật giám sát ngày này';
  static const String dayDisabled = 'Tạm nghỉ giám sát ngày này';

  // Notifications & Feeds
  static const String navIncidents = 'Thông báo';
  static const String notificationsTitle = 'Thông báo';
  static const String filterAll = 'Tất cả';
  static const String filterCheckIns = 'Báo bình an';
  static const String filterIncidents = 'Sự cố';
  static const String checkInFeedTitle = 'Báo bình an: {name}';
  static const String checkInBadgePeace = 'Bình an';
  static const String checkInDetailTitle = 'Chi tiết báo bình an';
  static const String notificationsEmptyAll =
      'Chưa có thông báo nào. Mọi hoạt động của gia đình đều an toàn và ổn định.';
  static const String notificationsMarkAllRead = 'Đã đọc tất cả';
  static const String notificationUnreadBadge = 'Mới';

  // Incidents
  static const String incidentsTitle = 'Sự cố & Cảnh báo';
  static const String incidentMissedCheckIn = 'Chưa nhận thấy xác nhận hoạt động';
  static const String incidentExtendedInactivity = 'Khoảng lặng bất thường trong sinh hoạt';
  static const String acknowledgeButton = 'Xác nhận đã liên hệ';
  static const String resolveButton = 'Đóng sự cố';
  static const String incidentResolvedNotice = 'Sự cố đã được giải quyết an toàn.';

  // Calm UX Reusables
  static const String retryButton = 'Thử lại';
  static const String calmLoading = 'Đang đồng bộ dữ liệu an tâm...';
  static const String calmEmptyIncidentsTitle = 'Mọi thứ đều bình an';
  static const String calmEmptyIncidentsDesc = 'Hiện không có cảnh báo nào. Người thân đang sinh hoạt an toàn.';

  // Devices & Privacy
  static const String privacyNotice =
      'Quyền riêng tư: Không theo dõi vị trí liên tục. Không ghi âm, không camera. Chỉ kiểm tra tín hiệu hoạt động thụ động.';
  static const String serverAuthoritativeNotice =
      'Hệ thống máy chủ trung tâm tự động tính toán và cảnh báo độc lập với trạng thái pin hay mạng của điện thoại.';
}
