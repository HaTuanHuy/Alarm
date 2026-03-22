# Flutter Clock App - Alarm Notification Fix

## Tiến độ
### 1. [x] Hiểu codebase (hệ thống báo thức hoàn chỉnh)
### 2. [x] Xác nhận vấn đề: Không có thông báo dù đã scheduleAlarm

### Đã hoàn thành
1. [x] Cập nhật pubspec.yaml (thêm permission_handler)
2. [x] notification_service.dart — dịch sang tiếng Việt, sửa _AlarmLanding thành màn hình đầy đủ, thêm xử lý thông báo nền
3. [x] alarm_page.dart — dịch toàn bộ UI sang tiếng Việt
4. [x] AndroidManifest.xml — thêm USE_EXACT_ALARM, VIBRATE, WAKE_LOCK, USE_FULL_SCREEN_INTENT, RECEIVE_BOOT_COMPLETED
5. [x] Dịch clock_page.dart, stopwatch_page.dart, countdown_page.dart, app.dart sang tiếng Việt

### Còn lại
1. [ ] Kiểm thử + git PR

**Kiểm thử:** Thiết bị Android thực, `flutter run`, đặt báo thức 1 phút, kiểm tra `flutter logs | grep ĐÃ LÊN LỊCH`
