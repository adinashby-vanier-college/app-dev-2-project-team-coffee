import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/moment_model.dart';
import '../services/moments_service.dart';
import 'moment_form_page.dart';
import 'moment_detail_page.dart';
import '../widgets/nav_bar.dart';
import '../widgets/user_menu_widget.dart';
import '../widgets/notification_bell.dart';

class MomentsPage extends StatefulWidget {
  const MomentsPage({super.key});

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> with SingleTickerProviderStateMixin {
  final MomentsService _momentsService = MomentsService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onNavBarTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/friends');
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/friend');
        break;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final momentDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (momentDate == today) {
      dateStr = 'Today';
    } else if (momentDate == tomorrow) {
      dateStr = 'Tomorrow';
    } else if (dateTime.difference(now).inDays < 7) {
      dateStr = DateFormat('EEEE').format(dateTime);
    } else {
      dateStr = DateFormat('MMM d').format(dateTime);
    }

    return '$dateStr at ${DateFormat('h:mm a').format(dateTime)}';
  }

  Widget _buildMomentCard(MomentModel moment) {
    final isUpcoming = moment.isUpcoming;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MomentDetailPage(moment: moment),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUpcoming 
                          ? Colors.green.shade50 
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isUpcoming ? 'Upcoming' : 'Past',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isUpcoming ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDateTime(moment.dateTime),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                moment.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.place, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      moment.locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildResponseBadge(
                    Icons.check_circle,
                    '${moment.goingCount} going',
                    Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _buildResponseBadge(
                    Icons.help_outline,
                    '${moment.maybeCount} maybe',
                    Colors.orange,
                  ),
                  const Spacer(),
                  if (moment.shareCode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Shareable',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponseBadge(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMomentsList(Stream<List<MomentModel>> stream, String emptyTitle, String emptySubtitle) {
    return StreamBuilder<List<MomentModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final moments = snapshot.data ?? [];

        if (moments.isEmpty) {
          return _buildEmptyState(emptyTitle, emptySubtitle, Icons.event_note);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: moments.length,
          itemBuilder: (context, index) => _buildMomentCard(moments[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pushReplacementNamed(context, '/home');
      },
      child: Scaffold(
        appBar: AppBar(
          actions: const [
            NotificationBell(),
            SizedBox(width: 8),
            Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: UserMenuWidget(),
            ),
          ],
          title: const Text('Moments'),
          centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Moments'),
            Tab(text: 'Invited'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMomentsList(
            _momentsService.getMyMomentsStream(),
            'No moments yet',
            'Create a moment from any location\nto start planning events with friends',
          ),
          _buildMomentsList(
            _momentsService.getInvitedMomentsStream(),
            'No invites yet',
            'When friends invite you to moments,\nthey\'ll appear here',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MomentFormPage(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Moment'),
      ),
      bottomNavigationBar: NavBar(
        currentIndex: 2,
        onTap: (index) => _onNavBarTap(context, index),
      ),
    ),
    );
  }
}
