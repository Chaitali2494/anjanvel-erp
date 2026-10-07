import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

const _demoFeedback = [
  {'id': '1', 'guest_name': 'Ravi Kumar',   'rating': 5, 'category': 'Overall',   'comment': 'Absolutely wonderful experience! The rooms were clean and the food was amazing.', 'date': '2026-10-01'},
  {'id': '2', 'guest_name': 'Priya S.',     'rating': 4, 'category': 'Food',      'comment': 'Loved the authentic Maharashtrian food. The bonfire evening was a highlight.', 'date': '2026-09-30'},
  {'id': '3', 'guest_name': 'Amit Joshi',   'rating': 5, 'category': 'Staff',     'comment': 'Staff was very helpful and friendly. Would definitely come back.', 'date': '2026-09-29'},
  {'id': '4', 'guest_name': 'Neha Patil',   'rating': 3, 'category': 'Rooms',     'comment': 'Room was okay but AC took a while to cool. Overall a nice place.', 'date': '2026-09-28'},
  {'id': '5', 'guest_name': 'Sanjay Rao',   'rating': 5, 'category': 'Activities','comment': 'Heritage walk was fantastic. Guide was very knowledgeable.', 'date': '2026-09-27'},
];

final feedbackProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    return await client.from('guest_feedback').select().order('created_at', ascending: false);
  } catch (_) {
    return List.from(_demoFeedback);
  }
});

class FeedbackDashboardScreen extends ConsumerStatefulWidget {
  const FeedbackDashboardScreen({super.key});
  @override
  ConsumerState<FeedbackDashboardScreen> createState() => _FeedbackDashboardScreenState();
}

class _FeedbackDashboardScreenState extends ConsumerState<FeedbackDashboardScreen> {
  String _filter = 'ALL';

  static const _categories = ['ALL', 'Overall', 'Food', 'Rooms', 'Staff', 'Activities'];

  @override
  Widget build(BuildContext context) {
    final feedbackAsync = ref.watch(feedbackProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(
        title: 'Guest Feedback',
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(feedbackProvider))],
      ),
      body: feedbackAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (feedback) {
          final avg     = feedback.isEmpty ? 0.0 : feedback.fold<int>(0, (s, f) => s + ((f['rating'] as int?) ?? 0)) / feedback.length;
          final fiveStr = feedback.where((f) => (f['rating'] as int?) == 5).length;
          final filtered= _filter == 'ALL' ? feedback : feedback.where((f) => f['category'] == _filter).toList();

          return Column(children: [
            // Rating summary
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF9A825), Color(0xFFFFB300)]),
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(avg.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 48)),
                  Row(children: List.generate(5, (i) => Icon(
                    i < avg.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.white, size: 18,
                  ))),
                  const SizedBox(height: 4),
                  Text('${feedback.length} reviews', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _RatingBar(5, fiveStr, feedback.length),
                  _RatingBar(4, feedback.where((f) => (f['rating'] as int?) == 4).length, feedback.length),
                  _RatingBar(3, feedback.where((f) => (f['rating'] as int?) == 3).length, feedback.length),
                  _RatingBar(2, feedback.where((f) => (f['rating'] as int?) == 2).length, feedback.length),
                  _RatingBar(1, feedback.where((f) => (f['rating'] as int?) == 1).length, feedback.length),
                ]),
              ]),
            ),

            // Category filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: _categories.map((c) {
                final selected = _filter == c;
                return GestureDetector(
                  onTap: () => setState(() => _filter = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFF9A825) : const Color(0xFFF9A825).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? const Color(0xFFF9A825) : const Color(0xFFF9A825).withOpacity(0.3)),
                    ),
                    child: Text(c, style: TextStyle(color: selected ? Colors.white : const Color(0xFFF9A825), fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList()),
            ),

            // Feedback list
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(title: 'No Feedback', subtitle: 'Guest feedback will appear here', icon: Icons.rate_review_outlined)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final f = filtered[i];
                        final rating   = (f['rating'] as int?) ?? 0;
                        final name     = f['guest_name'] as String? ?? 'Guest';
                        final comment  = f['comment'] as String? ?? '';
                        final category = f['category'] as String? ?? '';
                        final date     = f['date'] as String? ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              CircleAvatar(
                                radius: 18, backgroundColor: const Color(0xFFF9A825).withOpacity(0.15),
                                child: Text(name.substring(0, 1), style: const TextStyle(color: Color(0xFFF9A825), fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(date, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
                              ])),
                              Row(children: List.generate(5, (s) => Icon(
                                s < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: const Color(0xFFF9A825), size: 14,
                              ))),
                            ]),
                            if (category.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFF9A825).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(category, style: const TextStyle(color: Color(0xFFF9A825), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                            if (comment.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(comment, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4)),
                            ],
                          ]),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  final int stars, count, total;
  const _RatingBar(this.stars, this.count, this.total);
  @override Widget build(_) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(children: [
        Text('$stars', style: const TextStyle(color: Colors.white70, fontSize: 10)),
        const Icon(Icons.star_rounded, color: Colors.white70, size: 10),
        const SizedBox(width: 6),
        Container(
          width: 80, height: 5,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)),
          child: FractionallySizedBox(
            widthFactor: pct, alignment: Alignment.centerLeft,
            child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3))),
          ),
        ),
        const SizedBox(width: 6),
        Text('$count', style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }
}
