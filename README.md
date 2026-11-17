# Todo List

App to-do yên tĩnh, offline, không cần tài khoản: việc của người dùng chỉ lưu trên máy.

- Thêm nhanh bằng ngôn ngữ tự nhiên tiếng Việt / tiếng Anh ("Họp nhóm mai 9h", "every Monday")
- Today / Upcoming / Lists, Inbox, subtask, mức ưu tiên, lặp lại, nhắc nhở (Done / Snooze ngay trên thông báo)
- 16 ngôn ngữ (có RTL), giao diện sáng / tối

Lộ trình nâng cấp: [docs/upgrade-plan.md](docs/upgrade-plan.md).

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
    core/                  logic thuần: parser quick add, lặp lại, kế hoạch nhắc nhở
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
- Các link `todolist://quickadd | today | task?id=…` mở Home rồi đi tới đúng nơi.

**Trước khi build lên máy thật iOS:** bật App Group cho cả app lẫn extension trong Apple Developer, dùng ID:
- `group.com.vtn.todolist` cho bundle `com.vtn.todolist` và `com.vtn.todolist.TodayWidget`
- `group.com.vtn.todolist.dev` cho bundle `com.vtn.todolist.dev` và `com.vtn.todolist.dev.TodayWidget`

Nếu Xcode đang để "Automatically manage signing", nó tự đăng ký các App Group này.

## Đổi schema database

1. Sửa bảng trong `lib/src/data/local/database/tables.dart`, tăng `schemaVersion`.
2. Chạy `make make-migrations`: lưu snapshot schema mới vào `drift_schemas/`, sinh `app_database.steps.dart` và test migration trong `test/drift/`.
3. Viết bước nâng cấp trong `onUpgrade: stepByStep(...)`, chạy test cho đến khi pass.

`drift` đang được ghim ở 2.34.0 cho khớp `drift_dev` 2.34.0 (CLI của bản `drift_dev` này lỗi với `drift` mới hơn). Chỉ nâng hai gói cùng lúc, khi `freezed` hỗ trợ `analyzer` 13+.

## Test

```bash
fvm flutter test
```
