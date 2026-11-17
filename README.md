# Todo List

App to-do yên tĩnh, offline, không cần tài khoản: việc của người dùng chỉ lưu trên máy. Mọi tính năng "thông minh" đều chạy trên máy, không gọi server, không tải model.

Lộ trình và lý do từng quyết định: [docs/upgrade-plan.md](docs/upgrade-plan.md).

## Tính năng

### Việc và danh sách
- Ba tab: **Hôm nay** (việc quá hạn + hôm nay, thẻ tóm tắt tiến độ), **Sắp tới** (danh sách hoặc lịch tháng), **Danh sách** (Inbox, Đã xong, danh sách có màu).
- Mỗi việc có: ghi chú, ngày, giờ, mức ưu tiên (3 mức), lặp lại, nhắc nhở, thời lượng ước tính, việc con (1 cấp), danh sách.
- **Lặp lại:** hằng ngày, ngày thường, hằng tuần theo thứ, hằng tháng (theo ngày hoặc ngày cuối tháng), hằng năm, và theo **âm lịch**. Hoàn thành một việc lặp sẽ dời nó sang kỳ kế tiếp và giữ một bản trong lịch sử.
- Vuốt phải để hoàn thành, vuốt trái để dời sang ngày mai hoặc xoá; mọi thao tác xoá/hoàn thành đều có Hoàn tác.
- Kéo thả để sắp xếp trong danh sách; "Dời hết việc quá hạn sang hôm nay".
- **Tìm kiếm** theo chữ, có lịch sử tìm và bộ lọc nhanh (ưu tiên cao, có nhắc nhở).
- **Đã xong:** lịch sử theo ngày, bấm tick để khôi phục, thẻ tóm tắt 7 ngày.

### Thêm việc nhanh (tiếng Việt và tiếng Anh)
- Gõ tự nhiên: "Họp nhóm mai 9h", "nộp báo cáo thứ 6 9h !!", "every Monday", "mỗi ngày 7h". App tách ngày, giờ, lặp lại, mức ưu tiên ra khỏi tiêu đề và cho xem trước.
- Hiểu ngày **âm lịch**: "rằm", "mùng 2 Tết", "rằm tháng giêng", "23/12 âm", "Giỗ ông 10/3 âm lịch" (tự lặp hằng năm), "mỗi rằm".
- **Gợi ý thông minh** (học từ chính lịch sử việc của người dùng, tắt được): gợi ý danh sách, mức ưu tiên, giờ và thời lượng dưới dạng chip; báo khi việc đang gõ có vẻ trùng một việc đang mở.
- **Brain dump:** dán hoặc gõ nhiều việc một lúc, app tách thành từng việc để duyệt rồi lưu.
- **Lên kế hoạch ngày:** xếp các việc hôm nay vào khung giờ theo ưu tiên và thời lượng, có Hoàn tác.

### Lịch và âm lịch
- **Lịch tháng** ở tab Sắp tới: chấm màu theo ưu tiên, bấm một ngày để xem việc, nhấn giữ một việc rồi thả lên ngày khác để dời.
- **Âm lịch Việt Nam** (múi giờ +7, đã kiểm tra mọi ngày 1900–2100): ngày âm dưới ngày dương, 8 ngày lễ âm lịch, ngày âm trên tiêu đề Hôm nay. Mặc định bật khi dùng tiếng Việt.

### Nhắc nhở
- **Nhiều nhắc nhở cho mỗi việc** (đúng giờ, trước 5 phút … 1 ngày; việc cả ngày tính từ 9:00).
- Nút trên thông báo: **Xong**, **hoãn** 10 phút / 1 giờ / tối nay / sáng mai, hoặc chọn giờ khác.
- **Nhắc kiểu báo thức** cho từng việc: chuông báo thức lặp đến khi bấm, hiện toàn màn hình khi máy khoá (Android); vượt chế độ Tập trung (iOS).
- **Tổng kết buổi sáng:** "Hôm nay có N việc" vào giờ tự chọn, tắt được, ngày trống thì không gửi.
- **Kiểm tra nhắc nhở:** quyền thông báo, nhắc đúng giờ, tối ưu hoá pin, trang tự khởi chạy theo hãng (Xiaomi, Samsung, OPPO, vivo, HUAWEI…), nút gửi thông báo thử.
- Tự lên lịch lại sau khi khởi động lại máy, cập nhật app, đổi múi giờ (Android); iOS lên lịch lại khi mở app.

### Widget và lối tắt
- **Android:** widget "Hôm nay" (tick xong ngay trên widget), widget "Thêm việc", ô Quick Settings.
- **iOS 17+:** widget "Hôm nay" nhỏ/vừa/lớn có nút tick, widget "Thêm việc", widget màn hình khoá.
- Giữ icon app: lối tắt "Thêm việc".

### Tập trung và thống kê
- **Bộ đếm tập trung (Pomodoro)**, gắn được với một việc: 25/5 phút mặc định, đổi được. Chạy đúng cả khi thoát hay tắt app; hết giờ có thông báo.
- **Thống kê:** biểu đồ 7 ngày, thời gian tập trung, khung giờ hay hoàn thành việc nhất, heatmap 16 tuần, tiến độ từng danh sách. Chỉ đếm, **không có streak**.

### Sao lưu và khôi phục (không cần tài khoản)
- Tự sao lưu mỗi ngày, giữ 7 bản trên máy; chép thêm vào thư mục tự chọn (Google Drive, iCloud Drive…).
- Xuất file `.todobackup` qua share sheet; nhập lại trên máy khác, kể cả khác nền tảng.
- Khôi phục kiểu **gộp** (không xoá gì) hoặc **thay thế**; dữ liệu hiện tại luôn được lưu lại trước.

### Giao diện
- 16 ngôn ngữ (ar, de, en, es, fr, hi, id, it, ja, ko, pt, ru, th, tr, vi, zh), có RTL.
- Sáng / tối / theo hệ thống. Chuyển động có chủ đích (hàng thêm/bớt mượt, gạch ngang khi xong, chuyển tab) và tự tắt khi bật "giảm chuyển động". Rung phản hồi tắt được.

### Tình trạng
| | |
|---|---|
| Đã làm | M0 (nền móng, Flutter 3.47), M1 (chuyển động), M2 (gợi ý thông minh), M3 (widget), M4 (lịch + âm lịch), M5 (nhắc nhở), M6 (sao lưu), M9 (tập trung + thống kê) |
| Đang hoãn | M7 (nhập bằng giọng nói, tìm theo nghĩa), M8 (LLM chạy trên máy) |
| Backlog | M10: mẫu việc, nhãn, Siri / App Intents, bố cục tablet, mở file `.todobackup` từ app khác |

**Chưa kiểm chứng:** từ M0 chưa có lần build nào thành công và chưa module nào được chạy trên máy thật. Code Kotlin (widget, nhắc nhở, thư mục sao lưu) và Swift (widget) chưa từng được biên dịch trong project. Phần đã kiểm chứng là logic Dart, qua `flutter test` và `flutter analyze`.

## Yêu cầu

| | |
|---|---|
| Flutter | **3.47.9** qua [fvm](https://fvm.app) (`.fvmrc`) |
| iOS | 15.0+ |
| Android | minSdk 26, compileSdk 36 |

## Cài đặt

### 1. Quyền truy cập gói nội bộ

`flutter_ads` và `flutter_iap` là repo Bitbucket riêng tư. `pubspec.yaml` chỉ chứa URL không có thông tin đăng nhập. Mỗi máy tự cấp quyền bằng **một** trong hai cách:

- **Credential helper của git** (khuyên dùng): lưu access token Bitbucket vào keychain, git tự dùng khi `pub get`.
- **`pubspec_overrides.yaml`** (đã gitignore, không bao giờ commit):

  ```yaml
  dependency_overrides:
    flutter_ads:
      git:
        url: https://x-token-auth:<TOKEN>@bitbucket.org/innofyapp/flutter_ads.git
        ref: version/2.1.7
    flutter_iap:
      git:
        url: https://x-token-auth:<TOKEN>@bitbucket.org/innofyapp/flutter_iap.git
        ref: version/2.0.5
  ```

### 2. Sinh code

```bash
make reset
```

Lệnh này chạy `flutter clean`, `pub get`, `gen-l10n` và `build_runner` (Drift, injectable, auto_route, freezed, flutter_gen). File sinh ra không được commit.

## Chạy app

Hai flavor `dev` và `prod` ([flavorizr.yaml](flavorizr.yaml)). Cấu hình chạy sẵn cho Android Studio nằm trong `run_config/`.

```bash
fvm flutter run --flavor dev -t lib/main.dart
```

Build APK: `make build_apk_dev_normal`, `make build_apk_prod_normal`, `make build_aab`.

## Cấu trúc

```
lib/
  app_initializer.dart     khởi tạo Firebase, DI, Remote Config, nhắc nhở
  module/                  quảng cáo, Adjust, Remote Config (từ bộ khung)
  src/
    config/                DI (get_it + injectable), router (auto_route), theme
    core/                  logic thuần: parser quick add, lặp lại, âm lịch, gợi ý,
                           nhắc nhở, sao lưu, bộ đếm tập trung, thống kê
    data/                  Drift (bảng, database), repository
    presentation/          màn hình
    shared/                cubit, helper, widget dùng chung
assets/l10n/               chuỗi giao diện 16 ngôn ngữ (ARB)
drift_schemas/             snapshot schema DB qua từng phiên bản
test/                      test logic + repository
```

Quy ước:
- Màn hình đọc dữ liệu trực tiếp qua `Stream` của repository; cubit chỉ giữ trạng thái giao diện (ngôn ngữ, theme, rung).
- Animation dùng token trong `AppMotion` (`lib/src/config/theme/app_theme.dart`) để tự tắt khi người dùng bật giảm chuyển động.
- Rung phản hồi chỉ gọi qua `AppHaptics`, để công tắc trong Settings có hiệu lực ở mọi nơi.
- Từ Flutter 3.47, widget Material/Cupertino import từ `package:material_ui/material_ui.dart` / `package:cupertino_ui/cupertino_ui.dart`.

## Widget màn hình chính và lối tắt

| Nền tảng | Có gì | Mã nguồn |
|---|---|---|
| Android | Widget "Hôm nay" (tick xong ngay trên widget, nút +), widget "Thêm việc", ô Quick Settings | `android/app/src/main/kotlin/com/vtn/todolist/widget/` (Glance) |
| iOS 17+ | Widget "Hôm nay" (nhỏ/vừa/lớn, có nút tick), widget "Thêm việc", widget màn hình khoá | `ios/TodayWidget/` (WidgetKit), target `TodayWidgetExtension` |
| Cả hai | Lối tắt khi giữ icon app: "Thêm việc" | `lib/src/shared/helpers/shortcut_utils.dart` |

Luồng dữ liệu:
- App ghi danh sách việc hôm nay thành JSON (`WidgetSnapshot`, đã dịch sẵn mọi chữ) mỗi khi task, ngày hoặc ngôn ngữ thay đổi. Widget chỉ hiển thị JSON đó.
- **Android:** tick trên widget chạy Dart ở nền (`widgetInteraction`): hoàn thành task, cập nhật nhắc nhở, ghi lại snapshot.
- **iOS:** tick trên widget ẩn dòng đó ngay, huỷ nhắc nhở của task và ghi id vào `pending_done`. App hoàn thành các task này ở lần mở kế tiếp.
- Các link `todolist://quickadd | today | task?id=… | alarm?id=… | snooze?id=… | focus` mở Home rồi đi tới đúng nơi (widget, lối tắt và thông báo dùng chung).

**Trước khi build lên máy thật iOS:** bật App Group cho cả app lẫn extension trong Apple Developer, dùng ID:
- `group.com.vtn.todolist` cho bundle `com.vtn.todolist` và `com.vtn.todolist.TodayWidget`
- `group.com.vtn.todolist.dev` cho bundle `com.vtn.todolist.dev` và `com.vtn.todolist.dev.TodayWidget`

Nếu Xcode đang để "Automatically manage signing", nó tự đăng ký các App Group này.

## Cần cấu hình trước khi phát hành

| Việc | Vì sao |
|---|---|
| Bật **App Groups** (iOS) cho app và widget, ID ở mục trên | Widget đọc dữ liệu của app |
| Bật **Time Sensitive Notifications** (iOS) | Nhắc kiểu báo thức vượt chế độ Tập trung; đã khai báo trong `Runner.entitlements` |
| Điền form `USE_FULL_SCREEN_INTENT` trong Play Console | Nhắc kiểu báo thức hiện toàn màn hình; không được duyệt thì vẫn kêu, chỉ không toàn màn hình |
| Đổi product ID mua trong app | Đang là giá trị giữ chỗ `com.vtn.todolist.premium.weekly` |

## Đổi schema database

1. Sửa bảng trong `lib/src/data/local/database/tables.dart`, tăng `schemaVersion`.
2. Chạy `make make-migrations`: lưu snapshot schema mới vào `drift_schemas/`, sinh `app_database.steps.dart` và test migration trong `test/drift/`.
3. Viết bước nâng cấp trong `onUpgrade: stepByStep(...)`, chạy test cho đến khi pass.

`drift` đang được ghim ở 2.34.0 cho khớp `drift_dev` 2.34.0 (CLI của bản `drift_dev` này lỗi với `drift` mới hơn). Chỉ nâng hai gói cùng lúc, khi `freezed` hỗ trợ `analyzer` 13+.

Schema hiện tại: **v4** (v2 thêm thời lượng ước tính, v3 nhiều nhắc nhở + kiểu báo thức, v4 phiên tập trung).

## Test

```bash
fvm flutter test
```

Khoảng 200 test: parser quick add (Việt/Anh/âm lịch), lặp lại, âm lịch 1900–2100, gợi ý thông minh, kế hoạch nhắc nhở, sao lưu (xuất rồi nhập lại, file hỏng, gộp/thay thế), bộ đếm tập trung, thống kê, migration DB và một số widget test.
