import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uninews/format.dart';
import 'package:uninews/models.dart';

void main() {
  test('NewsPost reads a news_cards row from the database', () {
    final post = NewsPost.fromMap({
      'news_id': 2,
      'body': 'On the occasion of #WorldMentalHealthDay',
      'published_at': '2026-10-13T12:00:00+00:00',
      'source_url': 'https://x.com/ShaqraUni#preview-2',
      'source_name': 'جامعة شقراء',
      'source_type': 'social',
      'handle': '@ShaqraUni',
      'avatar_url': null,
      'organization': 'Ministry of Education',
      'audience': <String>[],
      'category': ['Activities'],
      'media': [
        {
          'url': 'https://example.com/a.png',
          'alt': 'Photos',
          'width': 480,
          'height': 317,
        },
      ],
      'comment_count': 1,
    });

    expect(post.id, 2);
    expect(post.category, ['Activities']);
    expect(post.audience, isEmpty);
    expect(post.media.single.aspectRatio, closeTo(1.514, 0.001));
    expect(post.commentCount, 1);
    expect(post.sourceLink, 'https://x.com/ShaqraUni');
    expect(post.publishedAt.toUtc(), DateTime.utc(2026, 10, 13, 12));
  });

  test('Comment takes the author name from the joined profile', () {
    final comment = Comment.fromMap({
      'comment_id': 5,
      'body': 'wow',
      'created_at': '2026-10-14T09:30:00+00:00',
      'user_id': 'abc',
      'profiles': {'display_name': 'Mohammad'},
    });

    expect(comment.authorName, 'Mohammad');
    expect(comment.body, 'wow');
  });

  test('Feed filters survive being saved and loaded', () {
    const filters = FeedFilters(
      audiences: {'Students'},
      categories: {'Exams', 'Academic'},
    );
    final loaded = FeedFilters.fromJson(filters.toJson());

    expect(loaded.audiences, {'Students'});
    expect(loaded.categories, {'Exams', 'Academic'});
    expect(loaded.sheetCount, 2);
    expect(const FeedFilters().sheetCount, 0);
  });

  test('Filters saved by the university version still load', () {
    final loaded = FeedFilters.fromJson({
      'university': 'King Saud University',
      'audiences': ['Students'],
      'categories': ['Exams'],
    });

    expect(loaded.audiences, {'Students'});
    expect(loaded.categories, {'Exams'});
  });

  test('Arabic text is laid out right to left', () {
    expect(directionOf('جامعة شقراء'), TextDirection.rtl);
    expect(directionOf('2026 جامعة شقراء'), TextDirection.rtl);
    expect(
      directionOf('#ShaqraUniversity held a health event'),
      TextDirection.ltr,
    );
  });

  test('Dates show the year only for older posts', () {
    final now = DateTime(2026, 10, 18);
    expect(shortDate(DateTime(2026, 10, 15), now: now), 'Oct 15');
    expect(shortDate(DateTime(2025, 3, 2), now: now), 'Mar 2, 2025');
  });
}
