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

## Đổi schema database

1. Sửa bảng trong `lib/src/data/local/database/tables.dart`, tăng `schemaVersion`.
2. Chạy `make make-migrations`: lưu snapshot schema mới vào `drift_schemas/`, sinh `app_database.steps.dart` và test migration trong `test/drift/`.
3. Viết bước nâng cấp trong `onUpgrade: stepByStep(...)`, chạy test cho đến khi pass.

`drift` đang được ghim ở 2.34.0 cho khớp `drift_dev` 2.34.0 (CLI của bản `drift_dev` này lỗi với `drift` mới hơn). Chỉ nâng hai gói cùng lúc, khi `freezed` hỗ trợ `analyzer` 13+.

## Test

```bash
fvm flutter test
```
