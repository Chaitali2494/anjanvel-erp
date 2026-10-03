import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../shared/widgets/app_widgets.dart';

// ── Demo Data ─────────────────────────────────────────────────────────────────

const _demoGuides = [
  {'id': 'g1', 'name': 'Kiran Patil',    'languages': 'Marathi, Hindi, English', 'contact': '+91 9876500001', 'available': true,  'expertise': 'Heritage & Culture'},
  {'id': 'g2', 'name': 'Ramesh Sawant',  'languages': 'Marathi, Hindi',          'contact': '+91 9876500002', 'available': false, 'expertise': 'Farm & Nature'},
  {'id': 'g3', 'name': 'Supriya Jadhav', 'languages': 'Marathi, English',        'contact': '+91 9876500003', 'available': true,  'expertise': 'Village Culture'},
];

const _demoWalks = [
  {'id': 'w1', 'title': 'Morning Heritage Walk', 'date': '2026-10-03', 'time': '07:00 AM', 'registered': 8,  'capacity': 15, 'guide': null,     'status': 'SCHEDULED'},
  {'id': 'w2', 'title': 'Farm Tour',             'date': '2026-10-03', 'time': '10:00 AM', 'registered': 12, 'capacity': 20, 'guide': 'g1',     'status': 'CONFIRMED'},
  {'id': 'w3', 'title': 'Evening Village Tour',  'date': '2026-10-03', 'time': '05:00 PM', 'registered': 5,  'capacity': 10, 'guide': null,     'status': 'SCHEDULED'},
  {'id': 'w4', 'title': 'Cooking Class',         'date': '2026-10-04', 'time': '11:00 AM', 'registered': 6,  'capacity': 8,  'guide': 'g3',     'status': 'CONFIRMED'},
];

// ── Screen ────────────────────────────────────────────────────────────────────

class GuideAssignmentScreen extends ConsumerStatefulWidget {
  const GuideAssignmentScreen({super.key});
  @override
  ConsumerState<GuideAssignmentScreen> createState() => _GuideAssignmentScreenState();
}

class _GuideAssignmentScreenState extends ConsumerState<GuideAssignmentScreen> {
  List<Map<String, dynamic>> _walks  = List.from(_demoWalks);
  final List<Map<String, dynamic>> _guides = List.from(_demoGuides);

  @override
  Widget build(BuildContext context) {
    final unassigned = _walks.where((w) => w['guide'] == null).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AnjAppBar(title: 'Guide Assignment'),
      body: Column(
        children: [
          // Stats bar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4527A0), Color(0xFF5E35B1)]),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Row(children: [
              _S('Guides',      '${_guides.length}',               Colors.white70, Colors.white),
              _D(), _S('Available', '${_guides.where((g) => g['available'] == true).length}', Colors.white70, const Color(0xFFA5D6A7)),
              _D(), _S('Sessions', '${_walks.length}',             Colors.white70, Colors.white),
              _D(), _S('Unassigned','$unassigned',                 Colors.white70, const Color(0xFFFFCC80)),
            ]),
          ),

          // Guide availability
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Guide Availability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _guides.length,
                    itemBuilder: (_, i) {
                      final g = _guides[i];
                      final available = g['available'] as bool? ?? false;
                      return Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: available ? AppTheme.success.withOpacity(0.08) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          border: Border.all(color: available ? AppTheme.success.withOpacity(0.4) : Colors.grey.shade300),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            CircleAvatar(radius: 14, backgroundColor: const Color(0xFF4527A0).withOpacity(0.1),
                                child: Text((g['name'] as String).substring(0, 1), style: const TextStyle(color: Color(0xFF4527A0), fontSize: 12, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 6),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(g['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Row(children: [
                                Icon(Icons.circle, size: 8, color: available ? AppTheme.success : Colors.grey),
                                const SizedBox(width: 4),
                                Text(available ? 'Available' : 'Busy', style: TextStyle(fontSize: 10, color: available ? AppTheme.success : Colors.grey)),
                              ]),
                            ]),
                          ]),
                          const SizedBox(height: 4),
                          Text(g['languages'] as String, style: const TextStyle(color: AppTheme.textHint, fontSize: 9)),
                        ]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Scheduled Sessions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // Walk sessions
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _walks.length,
              itemBuilder: (_, i) {
                final walk = _walks[i];
                final guideId  = walk['guide'] as String?;
                final guide    = guideId != null ? _guides.firstWhere((g) => g['id'] == guideId, orElse: () => {}) : null;
                final guideName= guide?.isNotEmpty == true ? guide!['name'] as String? : null;
                final hasGuide = guideName != null;
                final status   = walk['status'] as String? ?? 'SCHEDULED';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: hasGuide ? AppTheme.success.withOpacity(0.3) : const Color(0xFFFFB300).withOpacity(0.3)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.hiking_rounded, color: Color(0xFF4527A0), size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(walk['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasGuide ? AppTheme.success.withOpacity(0.1) : const Color(0xFFFFB300).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: hasGuide ? AppTheme.success.withOpacity(0.3) : const Color(0xFFFFB300).withOpacity(0.3)),
                          ),
                          child: Text(hasGuide ? 'Assigned' : 'Unassigned',
                              style: TextStyle(color: hasGuide ? AppTheme.success : const Color(0xFFFFB300), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.calendar_today_outlined, size: 12, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text('${walk['date']} at ${walk['time']}', style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                        const Spacer(),
                        Icon(Icons.people_outline_rounded, size: 12, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text('${walk['registered']}/${walk['capacity']}', style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                      ]),
                      if (hasGuide) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.person_pin_rounded, size: 14, color: Color(0xFF4527A0)),
                          const SizedBox(width: 4),
                          Text('Guide: $guideName', style: const TextStyle(color: Color(0xFF4527A0), fontSize: 12, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _showAssignSheet(context, i),
                            child: const Text('Change', style: TextStyle(color: AppTheme.info, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ] else ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showAssignSheet(context, i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4527A0).withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF4527A0).withOpacity(0.2)),
                            ),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.person_add_rounded, color: Color(0xFF4527A0), size: 16),
                              SizedBox(width: 6),
                              Text('Assign Guide', style: TextStyle(color: Color(0xFF4527A0), fontSize: 12, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignSheet(BuildContext context, int walkIndex) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assign Guide to "${_walks[walkIndex]['title']}"',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ..._guides.map((g) {
              final available = g['available'] as bool? ?? false;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF4527A0).withOpacity(0.1),
                  child: Text((g['name'] as String).substring(0, 1), style: const TextStyle(color: Color(0xFF4527A0), fontWeight: FontWeight.bold)),
                ),
                title: Text(g['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${g['languages']} · ${g['expertise']}', style: const TextStyle(fontSize: 11)),
                trailing: available
                    ? ElevatedButton(
                        onPressed: () {
                          setState(() => _walks[walkIndex] = {..._walks[walkIndex], 'guide': g['id'], 'status': 'CONFIRMED'});
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4527A0), minimumSize: const Size(70, 32)),
                        child: const Text('Assign', style: TextStyle(fontSize: 11)),
                      )
                    : const Text('Busy', style: TextStyle(color: Colors.grey, fontSize: 12)),
              );
            }),
            if (_walks[walkIndex]['guide'] != null)
              TextButton.icon(
                onPressed: () {
                  setState(() => _walks[walkIndex] = {..._walks[walkIndex], 'guide': null, 'status': 'SCHEDULED'});
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.person_remove_rounded, color: AppTheme.error),
                label: const Text('Remove Assignment', style: TextStyle(color: AppTheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}

class _S extends StatelessWidget {
  final String l, v; final Color lc, vc;
  const _S(this.l, this.v, this.lc, this.vc);
  @override Widget build(_) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: vc, fontWeight: FontWeight.bold, fontSize: 20)),
    Text(l, style: TextStyle(color: lc, fontSize: 10)),
  ]));
}
class _D extends StatelessWidget {
  @override Widget build(_) => Container(width: 1, height: 30, color: Colors.white24);
}
