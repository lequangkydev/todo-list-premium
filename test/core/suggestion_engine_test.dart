import 'package:flutter_base/src/core/ai/ai_provider.dart';
import 'package:flutter_base/src/core/ai/suggestion_engine.dart';
import 'package:flutter_base/src/core/ai/text.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

// Friday 13 Nov 2026, 10:00
final now = DateTime(2026, 11, 13, 10);

const work = 'work';
const shop = 'groceries';
const home = 'home';
const health = 'health';
const study = 'study';

var _id = 0;

Task t(
  String title, {
  String? list,
  int priority = 0,
  int? time,
  int? estimate,
  bool done = true,
}) => Task(
  id: 't${_id++}',
  listId: list,
  title: title,
  priority: priority,
  isDone: done,
  dueTime: time,
  estimateMinutes: estimate,
  sortOrder: 1,
  createdAt: now,
  updatedAt: now,
);

/// A believable few weeks of one person's tasks, Vietnamese and English
List<Task> history() => [
  // Work
  for (final s in [
    'Gửi báo cáo tuần',
    'Họp với khách hàng',
    'Trả lời email sếp',
    'Chuẩn bị slide thuyết trình',
    'Review hợp đồng',
    'Họp nhóm dự án',
    'Viết tài liệu kỹ thuật',
    'Gửi hoá đơn cho khách hàng',
    'Send weekly report',
    'Call the client',
    'Prepare meeting agenda',
    'Update project timeline',
    'Review pull request',
    'Plan the sprint',
    'Reply to client email',
    'Họp giao ban đầu tuần',
  ])
    t(s, list: work),
  t('Nộp báo cáo thuế', list: work, priority: 3),
  t('Nộp báo cáo quý', list: work, priority: 3),
  t('Submit tax report', list: work, priority: 3),
  // Groceries
  for (final s in [
    'Mua sữa',
    'Mua trứng',
    'Mua rau',
    'Mua thịt bò',
    'Mua bánh mì',
    'Mua gạo',
    'Mua nước mắm',
    'Mua trái cây',
    'Mua cà phê',
    'Mua sữa chua',
    'Buy milk',
    'Buy eggs',
    'Buy bread',
    'Buy bananas',
    'Buy coffee beans',
    'Đi siêu thị',
  ])
    t(s, list: shop),
  // Home
  for (final s in [
    'Dọn nhà',
    'Giặt quần áo',
    'Lau bếp',
    'Tưới cây',
    'Đổ rác',
    'Sửa vòi nước',
    'Thay bóng đèn',
    'Trả tiền điện',
    'Đóng tiền nước',
    'Clean the kitchen',
    'Do laundry',
    'Water the plants',
    'Take out the trash',
    'Pay electricity bill',
    'Vacuum the living room',
  ])
    t(s, list: home),
  // Health — runs at 6:00, gym in the evening
  for (var i = 0; i < 4; i++) t('Chạy bộ', list: health, time: 360 + i * 5),
  for (var i = 0; i < 3; i++)
    t('Tập gym', list: health, time: 1110, estimate: 60),
  for (final s in [
    'Uống thuốc',
    'Khám răng',
    'Đi bơi',
    'Yoga buổi sáng',
    'Go for a run',
    'Gym workout',
    'Take vitamins',
    'Dentist appointment',
    'Đặt lịch khám bệnh',
    'Đo huyết áp',
  ])
    t(s, list: health),
  // Study
  for (final s in [
    'Học tiếng Anh',
    'Làm bài tập',
    'Đọc sách',
    'Ôn thi',
    'Học từ vựng',
    'Xem bài giảng',
    'Học Flutter',
    'Read a book',
    'Practice English',
    'Study for the exam',
    'Finish homework',
    'Watch the lecture',
  ])
    t(s, list: study, estimate: 45),
  // Inbox: everything else
  for (final s in [
    'Gọi cho mẹ',
    'Sinh nhật Lan',
    'Call mom',
    'Đặt vé máy bay',
    'Renew passport',
    'Hỏi thăm bà ngoại',
    'Book a haircut',
    'Gửi quà cho bạn',
    'Đặt bàn nhà hàng',
    'Call grandma',
  ])
    t(s),
];

/// Phrasings the user hasn't typed before, with the list a person would
/// pick. null = nothing should be suggested.
const queries = <(String, String?)>[
  // Work (20)
  ('Gửi báo cáo tháng', work),
  ('Họp khách hàng mới', work),
  ('Trả lời email khách hàng', work),
  ('Chuẩn bị slide họp', work),
  ('Review hợp đồng thuê', work),
  ('Họp dự án X', work),
  ('Viết tài liệu API', work),
  ('Gửi hoá đơn tháng 11', work),
  ('Send monthly report', work),
  ('Call the new client', work),
  ('Prepare agenda for review', work),
  ('Update the timeline', work),
  ('Review the pull request from Nam', work),
  ('Plan next sprint', work),
  ('Email the client the quote', work),
  ('Họp giao ban', work),
  ('Nộp báo cáo năm', work),
  ('Gửi email cho sếp', work),
  ('Client meeting notes', work),
  ('Report for the client', work),
  // Groceries (20)
  ('Mua sữa tươi', shop),
  ('Mua trứng gà', shop),
  ('Mua rau muống', shop),
  ('Mua thịt heo', shop),
  ('Mua bánh mì sandwich', shop),
  ('Mua gạo ST25', shop),
  ('Mua nước mắm Phú Quốc', shop),
  ('Mua trái cây cho bé', shop),
  ('Mua cà phê hạt', shop),
  ('Buy oat milk', shop),
  ('Buy a dozen eggs', shop),
  ('Buy sourdough bread', shop),
  ('Buy bananas and apples', shop),
  ('Buy ground coffee', shop),
  ('Đi siêu thị cuối tuần', shop),
  ('Mua sữa chua uống', shop),
  ('Mua đồ ăn sáng', shop),
  ('Buy milk for coffee', shop),
  ('Mua rau và thịt', shop),
  ('Mua cà chua', shop),
  // Home (20)
  ('Dọn nhà cuối tuần', home),
  ('Giặt quần áo trắng', home),
  ('Lau bếp sau khi nấu', home),
  ('Tưới cây ngoài ban công', home),
  ('Đổ rác tái chế', home),
  ('Sửa vòi nước nhà tắm', home),
  ('Thay bóng đèn phòng khách', home),
  ('Trả tiền điện tháng 11', home),
  ('Đóng tiền nước tháng này', home),
  ('Clean the bathroom', home),
  ('Do the laundry', home),
  ('Water the garden plants', home),
  ('Take the trash out', home),
  ('Pay the water bill', home),
  ('Vacuum the bedroom', home),
  ('Dọn tủ lạnh', home),
  ('Giặt chăn', home),
  ('Lau cửa kính', home),
  ('Clean the fridge', home),
  ('Trả tiền internet', home),
  // Health (20)
  ('Chạy bộ 5km', health),
  ('Tập gym chân', health),
  ('Uống thuốc bổ', health),
  ('Khám răng định kỳ', health),
  ('Đi bơi buổi chiều', health),
  ('Yoga buổi tối', health),
  ('Go for a long run', health),
  ('Gym workout upper body', health),
  ('Take vitamin D', health),
  ('Dentist checkup', health),
  ('Đặt lịch khám mắt', health),
  ('Đo huyết áp buổi sáng', health),
  ('Chạy bộ công viên', health),
  ('Tập yoga', health),
  ('Run in the park', health),
  ('Uống thuốc dạ dày', health),
  ('Khám bệnh định kỳ', health),
  ('Workout at the gym', health),
  ('Đi bơi với bạn', health),
  ('Take my vitamins', health),
  // Study (12)
  ('Học tiếng Nhật', study),
  ('Làm bài tập toán', study),
  ('Đọc sách kỹ năng', study),
  ('Ôn thi cuối kỳ', study),
  ('Học từ vựng IELTS', study),
  ('Xem bài giảng Flutter', study),
  ('Read a novel', study),
  ('Practice English speaking', study),
  ('Study for the math exam', study),
  ('Finish the homework', study),
  ('Watch the lecture recording', study),
  ('Học Dart', study),
  // Nothing to suggest (8)
  ('Gọi cho bố', null),
  ('Call dad', null),
  ('Sinh nhật Minh', null),
  ('Đặt vé tàu', null),
  ('Renew driving licence', null),
  ('Hỏi thăm ông nội', null),
  ('Book a table for two', null),
  ('Gửi quà sinh nhật', null),
];

void main() {
  group('text', () {
    test('folds Vietnamese', () {
      expect(foldText('Đi chợ Mua Sữa'), 'di cho mua sua');
      // Combining marks (NFD)
      expect(foldText('Mé'), 'me');
    });

    test('features drop stop words and add pairs', () {
      expect(features('Gửi báo cáo cho sếp'), [
        'gui',
        'bao',
        'cao',
        'sep',
        'gui bao',
        'bao cao',
        'cao sep',
      ]);
    });
  });

  group('list suggestions on 100 new phrasings', () {
    late SuggestionEngine engine;
    setUpAll(() => engine = SuggestionEngine(history()));

    test('suggest the right list ≥70% of the time, rarely a wrong one', () {
      var right = 0;
      var wrong = 0;
      var falseAlarms = 0;
      final misses = <String>[];
      final labelled = queries.where((q) => q.$2 != null).length;
      final unlabelled = queries.length - labelled;
      for (final (query, expected) in queries) {
        final got = engine.suggestList(query);
        if (expected == null) {
          if (got != null) {
            falseAlarms++;
            misses.add('$query → $got (expected nothing)');
          }
        } else if (got == expected) {
          right++;
        } else {
          if (got != null) {
            wrong++;
          }
          misses.add('$query → $got (expected $expected)');
        }
      }
      expect(queries, hasLength(100));
      final accuracy = right / labelled;
      // ignore: avoid_print
      print(
        'list accuracy ${(accuracy * 100).toStringAsFixed(1)}% '
        '($right/$labelled), wrong $wrong, false alarms '
        '$falseAlarms/$unlabelled\n  ${misses.join('\n  ')}',
      );
      expect(accuracy, greaterThanOrEqualTo(.7));
      // A wrong list is worse than none
      expect(wrong / labelled, lessThanOrEqualTo(.08));
      expect(falseAlarms / unlabelled, lessThanOrEqualTo(.25));
    });

    test('no list is suggested when one is already chosen', () {
      expect(engine.hints('Mua sữa tươi', listId: home).listId, isNull);
    });
  });

  group('other hints', () {
    late SuggestionEngine engine;
    setUpAll(() => engine = SuggestionEngine(history()));

    test('priority only when clearly usual', () {
      expect(engine.suggestPriority('Nộp báo cáo thuế năm'), 3);
      expect(engine.suggestPriority('Mua sữa tươi'), isNull);
    });

    test('usual time from agreeing past tasks', () {
      // 6:00, 6:05, 6:10, 6:15 → about 6:10
      expect(engine.usualTime('Chạy bộ'), 370);
      expect(engine.usualTime('Tập gym'), 1110);
      expect(engine.usualTime('Mua sữa'), isNull);
      expect(engine.hints('Chạy bộ', hasTime: true).time, isNull);
    });

    test('no usual time when past times disagree', () {
      final scattered = SuggestionEngine([
        t('Đọc báo', time: 420),
        t('Đọc báo', time: 780),
        t('Đọc báo', time: 1320),
      ]);
      expect(scattered.usualTime('Đọc báo'), isNull);
    });

    test('duration from similar tasks', () {
      expect(engine.estimateFor('Tập gym tay'), 60);
      expect(engine.estimateFor('Học tiếng Anh giao tiếp'), 45);
      expect(engine.estimateFor('Mua sữa'), isNull);
    });

    test('duplicates of open tasks, accent- and case-blind', () {
      final open = t('Gọi điện cho ngân hàng', done: false);
      final e = SuggestionEngine([...history(), open]);
      expect(e.findDuplicate('goi dien cho Ngan Hang'), open);
      expect(e.findDuplicate('Gọi điện cho ngân hàng ACB'), open);
      expect(e.findDuplicate('Gọi cho mẹ'), isNull);
      // Done tasks aren't duplicates
      expect(e.findDuplicate('Mua sữa'), isNull);
    });

    test('quiet with no history', () {
      final empty = SuggestionEngine(const []);
      expect(empty.hints('Mua sữa').isEmpty, isTrue);
    });
  });

  group('splitting a brain dump', () {
    final provider = RuleBasedProvider(clock: () => now);

    test('one task per line, bullets removed', () async {
      expect(
        await provider.splitTasks('- Mua sữa\n• Gọi mẹ mai 9h\n\n1. Đổ rác'),
        ['Mua sữa', 'Gọi mẹ mai 9h', 'Đổ rác'],
      );
    });

    test('semicolons split', () async {
      expect(await provider.splitTasks('Buy milk; call mom; pay rent'), [
        'Buy milk',
        'call mom',
        'pay rent',
      ]);
    });

    test('commas split only when every piece has its own time', () async {
      expect(await provider.splitTasks('Họp 9h, gọi khách 14h'), [
        'Họp 9h',
        'gọi khách 14h',
      ]);
      expect(await provider.splitTasks('Mai họp 9h và thứ 6 nộp báo cáo'), [
        'Mai họp 9h',
        'thứ 6 nộp báo cáo',
      ]);
      expect(await provider.splitTasks('Mua sữa, trứng và bánh mì'), [
        'Mua sữa, trứng và bánh mì',
      ]);
      expect(await provider.splitTasks('Call Anna tomorrow, then rest'), [
        'Call Anna tomorrow, then rest',
      ]);
    });

    test('breaking down needs a model', () async {
      expect(await provider.breakDown('Plan a trip'), isEmpty);
    });
  });
}
