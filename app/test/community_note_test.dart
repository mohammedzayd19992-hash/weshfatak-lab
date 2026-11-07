import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uninews/models.dart';
import 'package:uninews/widgets/community_note.dart';

Map<String, dynamic> card({Map<String, dynamic>? note}) => {
  'news_id': 141,
  'body': 'فهم السلوك.. بداية الحل.',
  'published_at': '2026-10-22T10:09:44+00:00',
  'source_url': 'https://x.com/moe_gov_sa/status/2113211194261840181',
  'source_name': 'وزارة التعليم',
  'organization': 'Ministry of Education',
  'reply_count': 7,
  'community_note': note,
};

const note = {
  'summary': 'طرح أغلب المعلقين أسئلة عن دعم الأسر والمفاضلة الوظيفية.',
  'key_points': [
    'دعم مجاني لأسر الطلاب',
    'المفاضلة بالنقاط دون حد أدنى للمعدل',
  ],
  'replies_read': 7,
  'model': 'claude-opus-5-5',
};

void main() {
  test('A post reads its reply count and community note', () {
    final post = NewsPost.fromMap(card(note: note));
    expect(post.replyCount, 7);
    expect(post.communityNote!.keyPoints, hasLength(2));
    expect(post.communityNote!.repliesRead, 7);
    expect(NewsPost.fromMap(card()).communityNote, isNull);
  });

  test('A reply from X keeps its text, time and likes', () {
    final reply = PublicReply.fromMap({
      'reply_id': 3,
      'body': 'فيه دوام ولا بكره',
      'like_count': 2,
      'posted_at': '2026-10-25T10:34:40+00:00',
      'emotion': 'asking',
    });
    expect(reply.body, 'فيه دوام ولا بكره');
    expect(reply.likes, 2);
    expect(reply.emotion, 'asking');
    expect(reply.postedAt.toUtc(), DateTime.utc(2026, 10, 25, 10, 34, 40));
  });

  testWidgets(
    'The faces sit inside the note: two in the list, every one to tap in full',
    (tester) async {
      final parsed = CommunityNote.fromMap(note);
      const faces = {'asking': 4, 'happy': 2, 'angry': 1};
      String? picked;
      Future<void> show({required bool detail}) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: SingleChildScrollView(
                child: CommunityNoteBox(
                  note: parsed,
                  emotions: faces,
                  detail: detail,
                  onSelect: (face) => picked = face,
                ),
              ),
            ),
          ),
        ),
      );

      await show(detail: false);
      expect(find.text('What people said'), findsOneWidget);
      expect(find.text('from 7 replies'), findsOneWidget);
      expect(find.text('🤔 57% Asking  ·  😄 29% Happy'), findsOneWidget);
      expect(find.text('Angry'), findsNothing);
      expect(find.text('دعم مجاني لأسر الطلاب'), findsNothing);
      expect(tester.takeException(), isNull);

      await show(detail: true);
      expect(find.text('دعم مجاني لأسر الطلاب'), findsOneWidget);
      await tester.tap(find.text('Angry'));
      expect(picked, 'angry');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Faces show before Claude has written the summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunityNoteBox(emotions: {'happy': 2, 'asking': 1}),
        ),
      ),
    );
    expect(find.text('from 3 replies'), findsOneWidget);
    expect(find.textContaining('67% Happy'), findsOneWidget);
  });
}
