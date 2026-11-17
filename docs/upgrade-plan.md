# Plan nâng cấp Todo List — bản đề xuất để duyệt

_Lập ngày 17/11/2026, dựa trên khảo sát App Store / Google Play, pub.dev và code hiện tại (commit `8124785`)._

Cách dùng tài liệu: mỗi module (M0…M10) độc lập, có mục tiêu, hạng mục, gói dùng, thay đổi dữ liệu, rủi ro và tiêu chí "xong". Bạn duyệt module nào thì tôi làm module đó, mỗi module một nhánh riêng + commit, có test.

Kích thước: **S** ≈ 1 phiên làm việc, **M** ≈ 2–3 phiên, **L** ≈ 4+ phiên.

---

## 1. Tóm tắt khảo sát

### Đối thủ chính

| App | Rating iOS (lượt) | Play (rating / cài) | Điểm mạnh | AI | Mô hình thu tiền |
|---|---|---|---|---|---|
| Todoist | 4.80 (131K) | 4.6 / 10M+ | Quick add NL, bộ lọc | Ramble: nói → task (cloud) | Free giới hạn 5 project, 10 lượt AI/tháng |
| TickTick | 4.86 (47K) | 4.6 / 10M+ | Pomodoro, thói quen, ma trận Eisenhower, lịch | Trợ lý AI, voice capture (cloud) | Free giới hạn, widget/lịch bản cơ bản |
| Microsoft To Do | 4.72 (270K) | 4.6 / 10M+ | My Day | Không có trong app | Free hoàn toàn |
| Google Tasks | 4.80 (108K) | 4.6 / 10M+ | Gắn Gmail/Calendar | Gemini tạo task | Free |
| Apple Reminders | 4.83 (1.06M) | — | Tự phân loại, gợi ý (iOS 26), NL (iOS 27) | On-device | Free |
| Structured | 4.79 (169K) | 4.6 / 1M+ | Timeline ngày, Pomodoro, Live Activity | AI planner (Pro) | **Khoá việc lặp lại** → bị chê nhiều |
| Tiimo | 4.60 (22K) | 4.5 / 100K+ | App of the Year 2025, thân thiện ADHD | Brain dump → kế hoạch (cloud) | Subscription |
| Goblin Tools | 4.76 (3.1K) | 4.5 / 100K+ | Chia nhỏ việc theo "độ cay" | Cloud | App trả phí |
| **Todoery** (giống mình nhất) | 4.61 (5.8K) | **4.7 / 10M+, có quảng cáo** | Widget, lịch, backup Drive, template | "AI planner" (chưa xác minh) | Quảng cáo + mua gỡ ads |

Thị trường Việt Nam:
- **LockDay** (indie VN, to-do trên màn hình khoá, không tài khoản, không ads) đang ở **#52** Productivity miễn phí.
- **Ứng dụng lịch âm** áp đảo mọi app to-do: Lịch Việt ~656K lượt đánh giá, so với Microsoft To Do ~8.5K. Các app này bán chạy nhờ nhắc giỗ, rằm, mùng 1.

### Người dùng chê gì (1–2★, ~2.800 review)

| Chủ đề | App Store | Google Play | Bài học cho mình |
|---|---|---|---|
| Paywall / giá | 23% | 24% | Giữ **lặp lại, nhắc nhở, widget miễn phí**: đây là điểm bán hàng |
| Nhắc nhở không đáng tin | 17% | 18% | Xiaomi/Samsung (rất phổ biến ở VN) diệt app chạy nền |
| Crash / bug | 18% | 8% | Test kỹ, bật Crashlytics |
| Mất dữ liệu / đồng bộ | 12% | 8% | App offline thì càng cần **backup** |
| Widget hỏng / thiếu | 4% | 7% | Riêng Microsoft To Do: 21% review xấu |
| Quảng cáo | 1% | 4% | Todoery: 15% review xấu vì "mỗi lần tạo task lại hiện ads" |
| AI bị ép dùng | 4% | 2% | AI phải **tự nguyện bật**, không chen vào mặt |

### Xu hướng 2025–2026

- Nhập bằng giọng nói / "brain dump" thành nhiều task đã thành chuẩn.
- AI on-device miễn phí đã có, nhưng chỉ trên máy đời mới:
  - Apple Foundation Models: iPhone 15 Pro trở lên, **có tiếng Việt**.
  - Gemini Nano: chủ yếu máy flagship, chưa xác thực tiếng Việt.
- Widget lớn hơn, tương tác được; to-do trên màn hình khoá.
- Thiết kế thân thiện ADHD: ít lựa chọn, ăn mừng nhẹ nhàng, không "bêu đỏ" việc quá hạn. Điều này khớp đúng triết lý "calm" của app.

---

## 2. Quyết định cần bạn chốt trước

| # | Câu hỏi | Đề xuất của tôi |
|---|---|---|
| Q1 | Nâng Flutter 3.41.9 → **≥3.47**? | **Có, trong M0.** Phần lớn gói mới (AI, slidable 5, animations 3, ML Kit, speech_to_text 7.5) cần ≥3.44/3.47. Đổi lại: iOS tối thiểu lên 15.0 (đang 14.0), và phải kiểm tra `flutter_ads` / `flutter_iap` (gói nội bộ). Nếu chưa muốn nâng, vẫn làm được M1–M8 bằng các bản cũ hơn (đã ghi trong từng module). |
| Q2 | Model AI tải về đặt ở đâu? | Bắt đầu với Hugging Face (miễn phí, nhưng lộ IP người dùng cho bên thứ ba). Sau đó cân nhắc Play AI Packs (tối đa 1.5 GB/pack) / Apple asset packs. |
| Q3 | Tính năng nào thuộc Premium? | Free: toàn bộ tính năng cốt lõi, kể cả lặp lại, nhắc nhở, widget, backup, AI Tier 0. Premium: gỡ quảng cáo (mua 1 lần), theme/biểu tượng, thống kê nâng cao, model AI chất lượng cao. |
| Q4 | Có làm **âm lịch** không? | **Có.** Đây là điểm khác biệt lớn ở VN mà chưa app to-do lớn nào có (M4). |

---

## 3. Lộ trình đề xuất

| Thứ tự | Module | Giá trị | Kích thước |
|---|---|---|---|
| 1 | **M0** Nền móng & dọn dẹp | Bắt buộc, mở khoá các module sau | M |
| 2 | **M1** UI/UX & animation | Cảm giác "premium" ngay | L |
| 3 | **M2** AI Tier 0: gợi ý thông minh (0 MB) | AI miễn phí, chạy mọi máy | M |
| 4 | **M3** Widget & lối tắt hệ thống | Khoảng trống #1 so với đối thủ | L |
| 5 | **M4** Lịch tháng + âm lịch | Khác biệt ở thị trường VN | L |
| 6 | **M5** Nhắc nhở đáng tin | Phàn nàn #2 của cả ngành | M |
| 7 | **M6** Sao lưu & khôi phục | Chống mất dữ liệu | M |
| 8 | **M7** AI Tier 1: giọng nói + tìm kiếm ngữ nghĩa | Xu hướng nhập liệu 2026 | M |
| 9 | **M8** AI Tier 2: LLM on-device (tự bật) | Brain dump, chia nhỏ việc | L |
| 10 | **M9** Focus timer + thống kê | Giữ chân người dùng | M |
| — | **M10** Backlog | Làm sau | — |

Thứ tự có thể đổi; ràng buộc duy nhất là **M0 trước**, và **M8 sau M2** (dùng chung lớp `AiProvider` và cách parse ngày).

---

## M0 · Nền móng & dọn dẹp — M

**Mục tiêu:** dọn rủi ro, chuẩn bị DB và hạ tầng animation/haptic cho các module sau.

Hạng mục:
1. **Bảo mật:** bạn thu hồi 2 token Bitbucket đang nằm trong `pubspec.yaml`. Tôi chuyển URL gói sang SSH hoặc credential helper.
2. **Nâng Flutter** lên ≥3.47 (nếu Q1 = Có):
   - Chạy `dart fix --apply --code=migrate_design_widgets` (Material/Cupertino tách thành gói `material_ui`).
   - iOS deployment target lên 15.0.
   - Build thử cả hai flavor, cả Android lẫn iOS.
3. **Migration DB:** `schemaVersion` 1 → 2, dùng `stepByStep` của Drift. Viết test migration bằng `drift_dev schema dump`. Mọi cột/bảng mới của các module sau đi qua cơ chế này.
4. **Motion & haptic:**
   - Mở rộng `AppMotion` (đã có) thành bộ token 150/250/400 ms kèm spring.
   - Thêm `AppHaptics` bọc `HapticFeedback`, có công tắc tắt/bật trong Settings.
   - Mọi animation đều tôn trọng reduced-motion.
5. **Dọn code thừa:**
   - Xoá `theme/light`, `theme/dark` (không còn được import).
   - Sửa IAP product ID `smartremote.sub.weekly`.
   - Viết lại `README.md`.
   - Xử lý các `TODO(all)`.
6. **Minh bạch quyền riêng tư:** câu "No account. Tasks are stored only on this device." vẫn đúng. Bổ sung một dòng nói rõ app có dùng Analytics/Crashlytics/quảng cáo.

**Xong khi:** build xanh 2 flavor × 2 nền tảng; test cũ + test migration pass; không còn token trong repo.
**Rủi ro:** gói `flutter_ads` / `flutter_iap` có thể chưa hỗ trợ Flutter mới. Khi đó giữ 3.41 và dùng các bản gói cũ.

---

## M1 · UI/UX, hiệu ứng, animation — L

**Mục tiêu:** app "đắt tiền" hơn nhưng vẫn yên tĩnh. Mỗi tương tác có phản hồi rõ, không ồn ào. Thiết kế qua skill `ui-ux-pro-max`, sau đó audit bằng bộ skill vectorlab (spacing, motion, reduced-motion, empty-states).

Gói (bản chạy được trên 3.41 → bản sau khi nâng cấp):

| Gói | Dùng cho | Phiên bản |
|---|---|---|
| `flutter_slidable` | Thay `Dismissible`: vuốt phải = hoàn thành, vuốt trái = hoãn / xoá | 4.0.3 → 5.2.0 |
| `animations` | Container transform, fade-through, shared axis | 2.2.0 → 3.0.0 |
| `animated_reorderable_list` | Chèn/xoá item có animation trên Today/Upcoming | 1.3.0 |
| `lottie` (đã có) | Khoảnh khắc "xong hết hôm nay", tối đa 1 lần/ngày | 3.7.0 |
| `HapticFeedback`, `SpringDescription` | Rung nhẹ, chuyển động lò xo (có sẵn trong Flutter, không thêm gói) | — |

**Không dùng:**
- Rive: thêm runtime native, bản free có splash.
- Gói confetti: ồn.
- Liquid Glass: tốn hiệu năng, giảm độ tương phản, trái với phong cách "calm".
- Syncfusion: giới hạn giấy phép.

12 vi tương tác:

| # | Màn | Hiệu ứng | Khi bật reduced-motion |
|---|---|---|---|
| 1 | Mọi danh sách | Tick hoàn thành: sparkle (đã có) + rung nhẹ + gạch ngang chạy trái→phải 200 ms, giữ hàng ~700 ms rồi thu lại | Gạch ngay, mờ dần |
| 2 | Today | Vòng tiến độ trên thẻ tóm tắt, số đếm chạy lò xo; đạt 100% → Lottie "xong hết" 1 lần/ngày | Dấu check tĩnh |
| 3 | List detail | Nhấc hàng khi kéo (scale 1.02 + bóng + rung), rung nhẹ khi thả | Chỉ có bóng |
| 4 | Mọi danh sách | Vuốt có ngưỡng: rung khi qua ngưỡng, icon to dần 0.8→1 | Không scale |
| 5 | Quick add / editor | Chữ nhận diện được "bật" thành chip (trượt 6 px, lệch nhau 40 ms); sheet mở bằng lò xo | Hiện ngay |
| 6 | List detail | "Magic plus": kéo nút + vào giữa danh sách để chèn đúng chỗ | Chỉ có nút bấm |
| 7 | Lists → chi tiết | Container transform từ ô list có màu | Fade-through |
| 8 | Tab bar, Search | Fade-through 250 ms giữa tab; ô search mở ra từ icon | Cắt cảnh |
| 9 | Upcoming | Đổi ngày → danh sách trượt theo hướng ngày | Cross-fade |
| 10 | Thống kê (M9) | Heatmap hiện dần 1 lần mỗi phiên | Tĩnh |
| 11 | Empty state | Minh hoạ theo từng ngữ cảnh, đứng yên sau 400 ms, có nút hành động | Tĩnh |
| 12 | Onboarding | Chấm trang co giãn, parallax 8 px, nút bấm có lò xo | Chấm thường |

Kèm theo:
- Thêm "Snooze" vào hành động vuốt.
- Nút "Dời việc quá hạn sang hôm nay" có animation gom nhóm.
- Rà lại độ tương phản trong dark mode.

**Xong khi:** 12 tương tác chạy mượt ở 60 fps trên máy tầm trung (profile mode); reduced-motion tắt hết chuyển động; audit skill không còn lỗi mức High.

---

## M2 · AI Tier 0: gợi ý thông minh, 0 MB — M

**Mục tiêu:** "AI" chạy trên mọi máy, không tải gì, không gửi gì ra ngoài. Học từ chính dữ liệu của người dùng trong Drift. Mọi gợi ý đều có thể bỏ qua hoặc tắt.

Hạng mục:
1. **Lớp `AiProvider`** (interface chung cho M2/M7/M8). Quy tắc: **chỉ parser VI/EN hiện có mới được biến chữ thành ngày giờ**; AI chỉ đề xuất, không tự ý ghi ngày.
2. **Đoán list & ưu tiên:** đếm tần suất từ khoá → list/priority theo từng người dùng. Ví dụ "sữa, trứng" → list Đi chợ. Hiện dưới dạng chip gợi ý trong quick add.
3. **Giờ quen thuộc:** "Chạy bộ" thường đặt 6:00 → gợi ý 6:00 khi gõ "chạy bộ" mà không có giờ.
4. **Brain dump theo luật:** dán/gõ nhiều dòng, hoặc nối bằng dấu phẩy / "và" / "and" → tách thành nhiều task, mỗi task qua parser → màn xem trước trước khi lưu.
5. **Phát hiện trùng:** so khớp trigram sau khi bỏ dấu tiếng Việt, cảnh báo "Có vẻ bạn đã có việc này".
6. **"Sắp xếp ngày của tôi":** xếp theo giờ hẹn → ưu tiên → thời lượng ước tính (cột mới `estimateMinutes`, tự học từ lịch sử) → gợi ý thứ tự cho Today.
7. **Tóm tắt tuần:** câu dựng từ template trong file l10n, dựa trên `ActivityDays`.

**DB:** thêm cột `estimateMinutes` và bảng `suggestion_stats` (từ khoá → list/giờ/đếm).
**Xong khi:** gợi ý chính xác ≥70% trên bộ test 100 câu VI/EN tự soạn; mọi gợi ý có nút bỏ qua; có công tắc "Gợi ý thông minh" trong Settings.

---

## M3 · Widget & lối tắt hệ thống — L

**Mục tiêu:** người dùng mở app mỗi ngày từ màn hình chính và màn hình khoá. Đây là khoảng trống #1 so với đối thủ.

Gói: `home_widget` 0.10.0 (UI widget viết native: SwiftUI trên iOS, Glance trên Android). `quick_actions` đã có sẵn.

Hạng mục:
1. **Widget "Hôm nay":** danh sách việc hôm nay, **tick hoàn thành ngay trên widget** (iOS 17+ qua AppIntent, Android qua Glance callback). Có 3 kích thước.
2. **Widget "Thêm nhanh":** 1 chạm mở quick add.
3. **Widget màn hình khoá** (iOS accessory; Android tuỳ launcher): đếm việc còn lại + việc kế tiếp.
4. **Quick Settings tile Android:** viết native Kotlin `TileService`, mở quick add.
5. **Quick actions:**
   - Đổi item test "Home" thành "Thêm việc" và "Hôm nay".
   - Item "Uninstall" (giữ chân người dùng) giữ nguyên để bạn quyết.
6. Widget được cập nhật mỗi khi DB đổi (hook vào stream của repository) và lúc qua nửa đêm.

**Kỹ thuật:** cần App Group trên iOS và đăng ký plugin trong `AppDelegate`. Callback của widget mở Drift ở isolate nền; DB đã bật `shareAcrossIsolates`.
**Xong khi:** tick trên widget → app đồng bộ ngay khi mở; widget đúng ngày sau nửa đêm; hỗ trợ dark mode.
**Để sau:** Siri / App Intents (`flutter_assistant_intents` còn non), Live Activities (gắn với focus timer ở M9).

---

## M4 · Lịch tháng + âm lịch — L

**Mục tiêu:** xem việc theo tháng; điểm khác biệt ở VN là âm lịch.

Gói: `table_calendar` 3.3.0 (Apache-2.0). Âm lịch **tự viết bằng Dart thuần**, theo thuật toán Hồ Ngọc Đức, có test đối chiếu ngày đã biết. Không phụ thuộc gói ngoài.

Hạng mục:
1. **Tab Upcoming:** thêm chế độ lịch tháng; chấm đếm việc dưới mỗi ngày; chạm vào ngày → danh sách việc của ngày đó.
2. **Kéo task sang ngày khác** để dời lịch (trong lịch tháng).
3. **Hiển thị ngày âm** (nhỏ, tuỳ chọn bật trong Settings; mặc định bật khi ngôn ngữ là tiếng Việt).
4. **Lặp theo âm lịch:** giỗ hằng năm (ngày/tháng âm), rằm và mùng 1 hằng tháng. Lưu dưới dạng mở rộng `rrule`, ví dụ `X-CAL=LUNAR`.
5. **Quick add hiểu:** "rằm", "mùng 1", "15/7 âm", "giỗ ông 10/3 âm lịch".
6. Gợi ý sẵn (tắt được): Tết, rằm tháng Giêng, Vu Lan…

**Xong khi:** chuyển đổi âm↔dương đúng 100% trên bộ test 1900–2100; tháng nhuận được xử lý đúng; nhắc giỗ chạy đúng qua nhiều năm.

---

## M5 · Nhắc nhở đáng tin — M

**Mục tiêu:** xử lý phàn nàn #2 của cả ngành (17–18%), nhất là trên Xiaomi/Samsung/Oppo.

Hạng mục:
1. **Hướng dẫn tắt tối ưu pin theo hãng:** phát hiện hãng máy → màn hướng dẫn có ảnh + nút mở thẳng trang cài đặt.
2. **Nhiều nhắc nhở cho mỗi task** (bảng mới `reminders` thay cho cột `remindOffset`; có migration chuyển dữ liệu cũ).
3. **Mốc hoãn:** 10 phút, 1 giờ, tối nay, sáng mai (thay cho "1 giờ" cố định).
4. **Nhắc kiểu báo thức** cho việc quan trọng: kênh âm thanh riêng, hiện toàn màn hình (Android); bật riêng cho từng task.
5. **Tổng kết buổi sáng:** "Hôm nay có 5 việc" lúc 8:00, giờ tuỳ chỉnh, tắt được.
6. **Nút "Gửi thông báo thử"** + màn chẩn đoán (quyền, exact alarm, tối ưu pin).

**Xong khi:** nhắc đúng giờ (±1 phút) sau khi khởi động lại máy và sau khi đổi múi giờ; nhiều nhắc nhở trên cùng một task không trùng ID; vẫn trong giới hạn 60 thông báo chờ.

---

## M6 · Sao lưu & khôi phục, không cần tài khoản — M

**Mục tiêu:** đổi máy hay mất máy không mất việc. Vẫn giữ lời hứa "không tài khoản".

Hạng mục:
1. **Xuất/nhập file** `.todobackup` (JSON nén, có số phiên bản schema) qua share sheet / Files. Người dùng tự lưu lên Google Drive, iCloud Drive, Zalo…
2. **Tự sao lưu hằng ngày** vào thư mục app, giữ 7 bản gần nhất; khôi phục từ danh sách.
3. **Chọn thư mục sao lưu tự động** (Android SAF trỏ vào Drive / thư mục người dùng chọn; iOS lưu vào iCloud Drive của app). Miễn phí, không cần server.
4. **Khôi phục an toàn:** xem trước số task/list, rồi chọn gộp hoặc thay thế; tự sao lưu bản hiện tại trước khi ghi đè.
5. Đảm bảo Android Auto Backup / iCloud device backup có bao gồm DB.

**Xong khi:** xuất trên Android → nhập trên iOS ra kết quả y hệt (test round-trip); file hỏng báo lỗi rõ ràng, không làm mất dữ liệu.

---

## M7 · AI Tier 1: giọng nói + tìm kiếm ngữ nghĩa — M

**Mục tiêu:** nói một câu → ra task, chạy offline khi có thể.

| Thành phần | Lựa chọn | Ghi chú |
|---|---|---|
| Nhận giọng nói | `speech_to_text` (7.4.0 trên 3.41 / 7.5.0) với `onDevice: true` | Dùng nhận dạng của hệ điều hành, miễn phí. **Tiếng Việt offline chưa xác minh**, sẽ kiểm tra trên máy thật |
| Dự phòng offline tiếng Việt | `sherpa_onnx` 2.0.1 + model Zipformer-vi int8 (~75 MB, tải khi cần) | Apache-2.0; iOS phải build từ source |
| Nhận diện ngôn ngữ | `google_mlkit_language_id` (0.14.0 trên 3.41) | Hỗ trợ `vi`; chọn parser VI hay EN |
| Tìm kiếm ngữ nghĩa / trùng | EmbeddingGemma 2 (~165 MB, Apache-2.0, tải khi cần) | Vector lưu BLOB trong Drift, so cosine bằng Dart; ví dụ "mua sữa" tìm ra "đi siêu thị" |

Luồng: nút mic trong quick add → nói → hiện chữ → brain dump (M2) → xem trước → lưu.
**Xong khi:** "Mai 9 giờ họp nhóm, thứ 6 nộp báo cáo" → 2 task đúng ngày; luôn hỏi trước khi tải model; tải chỉ qua Wi-Fi (có tuỳ chọn).

---

## M8 · AI Tier 2: LLM on-device, tự nguyện bật — L

**Mục tiêu:** các tính năng chỉ LLM làm được, vẫn miễn phí và chạy trên máy.

Tính năng:
1. **Brain dump nâng cao:** đoạn văn lộn xộn → danh sách task kèm list/ưu tiên. Mọi cụm ngày giờ vẫn đi qua parser của mình.
2. **Chia nhỏ việc** thành subtask, có thanh "mức chi tiết" (kiểu Goblin Tools).
3. **Viết lại tiêu đề** gọn, rõ.
4. **Tóm tắt tuần** bằng lời văn tự nhiên.

Nhà cung cấp (qua `AiProvider`, chọn tự động theo máy):

| Ưu tiên | Provider | Điều kiện | Dung lượng | Giấy phép |
|---|---|---|---|---|
| 1 | Apple Foundation Models (`apple_foundation_models` 0.5.2) | iOS 26+, iPhone 15 Pro trở lên, Apple Intelligence đang bật | 0 MB | Của hệ điều hành |
| 2 | **Qwen3.5-0.8B** (mặc định khi tải) | RAM ≥4 GB, arm64 | ~0.5–1 GB | Apache-2.0 |
| 3 | Gemma 4 E2B (bản "chất lượng cao") | RAM ≥8 GB | 2.58 GB | Apache-2.0 |
| — | Gemini Nano | Thử nghiệm sau: tiếng Việt chưa được xác thực, gói Flutter chưa trả JSON | 0 MB | — |

Runtime:
- Giữ Flutter 3.41: `llamadart` 0.19.x (GGUF, có JSON schema, tool calling).
- Đã nâng ≥3.44: `flutter_edge_ai` 2.6.0 (thay `flutter_gemma` đã ngừng phát triển).

Nguyên tắc:
- **Tắt mặc định.** Bật trong Settings → "Trợ lý AI trên máy". Ghi rõ "chạy trên điện thoại, không gửi dữ liệu".
- Chỉ tải khi đang Wi-Fi; hiện dung lượng trước khi tải; xoá được model.
- Chỉ chạy khi người dùng bấm, không chạy nền.
- Output ép theo JSON schema rồi kiểm tra bằng code; lỗi → quay về Tier 0.
- Trước khi chốt model: chấm trên **bộ đánh giá 50 brain dump VI/EN** của chính app. Hiện chưa có benchmark tiếng Việt nào cho model ≤1B.

**Rủi ro:**
- Hết RAM trên máy yếu → chặn theo RAM ngay từ đầu.
- Model nhỏ "bịa" ngày → chỉ parser mới được đặt ngày.
- Dung lượng tải lớn.
- Gói thay đổi nhanh → giấu sau `AiProvider`.

**Xong khi:** brain dump đúng ≥80% task trên bộ đánh giá; không crash trên máy 4 GB RAM; app vẫn dùng bình thường khi chưa tải model.

---

## M9 · Focus timer + thống kê — M

Hạng mục:
1. **Focus timer (Pomodoro)** gắn với task: 25/5 phút, tuỳ chỉnh; thông báo đang chạy (Android); Live Activity (iOS, `live_activities` 2.4.9) để sau.
2. **Màn thống kê:**
   - Heatmap hoạt động tự vẽ từ `ActivityDays` (~100 dòng, không thêm gói).
   - Biểu đồ tuần bằng `fl_chart` 1.3.1.
   - Tỉ lệ hoàn thành theo list, giờ làm việc hiệu quả nhất.
3. Giữ triết lý **không streak gây áp lực**: chỉ đếm "ngày có hoạt động", không phạt khi nghỉ.

---

## M10 · Backlog (làm sau)

- Mẫu việc / checklist: đi chợ, du lịch, dọn nhà đón Tết.
- Tag / nhãn.
- Siri & App Intents (iOS 27 đã mở Siri AI cho mọi app); Android AppFunctions.
- Bố cục tablet / iPhone Duo; tiếp nhận Material 3 Expressive khi `material_ui` ổn định.
- Nhắc theo vị trí, Apple Watch / Wear OS: chi phí cao, lợi ích thấp với đối tượng mass-market.

---

## 4. Nguyên tắc chung

- **Không khoá** lặp lại, nhắc nhở, widget sau paywall.
- **Không hiện quảng cáo xen kẽ** khi tạo/hoàn thành task; có gói gỡ quảng cáo mua một lần.
- Chỉ xin đánh giá sau một khoảnh khắc tích cực (ví dụ hoàn thành hết việc hôm nay), không làm phiền trong phiên đầu.
- AI luôn **tự nguyện bật**, có thể bỏ qua, ghi rõ chạy trên máy.
- Mọi chuỗi mới có đủ 16 ngôn ngữ; mọi animation có phiên bản reduced-motion.
- Mỗi module: nhánh riêng, test, review bằng `/code-review` trước khi merge vào `dev`.

---

## 5. Nguồn chính

- Bảng giá Todoist: https://www.todoist.com/help/articles/todoist-plans-pricing
- Todoist Ramble: https://techcrunch.com/2026/01/21/todoists-app-now-lets-you-add-tasks-to-your-to-do-list-by-speaking-to-its-ai/
- TickTick Premium: https://ticktick.com/upgrade
- Reminders iOS 26: https://9to5mac.com/2025/10/13/heres-everything-new-in-reminders-with-ios-26/
- Tiimo, App of the Year 2025: https://daringfireball.net/2025/12/2025_app_store_award_winners
- Thiết bị & ngôn ngữ Apple Intelligence: https://support.apple.com/en-us/121115
- ML Kit GenAI (Gemini Nano): https://developers.google.com/ml-kit/genai
- On-device AI trên Play (giới hạn AI Packs): https://developer.android.com/google/play/on-device-ai
- Gói Flutter (đã kiểm tra phiên bản trên pub.dev ngày 17/11/2026):
  - `flutter_edge_ai`: https://pub.dev/packages/flutter_edge_ai
  - `llamadart`: https://pub.dev/packages/llamadart
  - `apple_foundation_models`: https://pub.dev/packages/apple_foundation_models
  - `sherpa_onnx`: https://pub.dev/packages/sherpa_onnx
  - `speech_to_text`: https://pub.dev/packages/speech_to_text
  - `home_widget`: https://pub.dev/packages/home_widget
  - `flutter_slidable`: https://pub.dev/packages/flutter_slidable
  - `animations`: https://pub.dev/packages/animations
  - `table_calendar`: https://pub.dev/packages/table_calendar
  - `fl_chart`: https://pub.dev/packages/fl_chart
- Model AI:
  - Qwen3.5-0.8B: https://huggingface.co/Qwen/Qwen3.5-0.8B
  - Gemma 4 E2B: https://huggingface.co/google/gemma-4-E2B-it
  - EmbeddingGemma 2: https://blog.google/innovation-and-ai/technology/developers-tools/embeddinggemma-2
- Gemma chuyển sang giấy phép Apache-2.0: https://the-decoder.com/googles-gemma-4-is-now-available-with-apache-2-0-licensing-for-the-first-time/

**Chưa xác minh được:**
- Chất lượng nhận giọng nói tiếng Việt offline của iOS/Android.
- Chất lượng tiếng Việt của các model ≤1B.
- Quy định ảnh chụp màn hình iPhone Duo từ 4/2027.
- Con số lượt cài chính xác (Google Play chỉ hiện theo mốc).
