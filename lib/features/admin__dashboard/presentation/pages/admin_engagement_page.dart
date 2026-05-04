import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/features/listening_history/data/models/listening_history_models.dart';
import 'package:musee/features/listening_history/data/repositories/listening_history_repository.dart';
import 'package:musee/features/listening_history/presentation/bloc/listening_history_bloc.dart';

class AdminEngagementPage extends StatefulWidget {
  const AdminEngagementPage({super.key});

  @override
  State<AdminEngagementPage> createState() => _AdminEngagementPageState();
}

class _AdminEngagementPageState extends State<AdminEngagementPage> {
  late final ListeningHistoryBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = ListeningHistoryBloc(
      repository: GetIt.I<ListeningHistoryRepository>(),
    );
    _bloc.add(const FetchEngagementMetricsEvent());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _refreshTrending() {
    _bloc.add(const RefreshTrendingEvent());
  }

  void _refreshMetrics() {
    _bloc.add(const FetchEngagementMetricsEvent());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Engagement & Analytics'),
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Refresh metrics',
              onPressed: _refreshMetrics,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: BlocConsumer<ListeningHistoryBloc, ListeningHistoryState>(
          listener: (context, state) {
            if (state is TrendingRefreshed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Trending refreshed: ${state.result.results.length} tasks completed',
                  ),
                  backgroundColor: Colors.green.shade700,
                ),
              );
              // Re-fetch metrics after a refresh
              _refreshMetrics();
            }
            if (state is TrendingRefreshError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${state.message}'),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is FetchingEngagementMetrics) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is EngagementMetricsError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load metrics',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(state.message, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _refreshMetrics,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is EngagementMetricsLoaded) {
              return _MetricsDashboard(
                metrics: state.metrics,
                onRefreshTrending: _refreshTrending,
                isRefreshing: false,
              );
            }

            if (state is RefreshingTrending) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Refreshing trending data...'),
                  ],
                ),
              );
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}

class _MetricsDashboard extends StatelessWidget {
  final EngagementMetrics metrics;
  final VoidCallback onRefreshTrending;
  final bool isRefreshing;

  const _MetricsDashboard({
    required this.metrics,
    required this.onRefreshTrending,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Last updated: ${_formatTimestamp(metrics.timestamp)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Metrics Grid
          Text(
            'Last 24 Hours',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 700 ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossCount,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MetricCard(
                    icon: Icons.play_circle_filled_rounded,
                    label: 'Total Plays',
                    value: _fmtNumber(metrics.totalPlays24h),
                    color: theme.colorScheme.primary,
                    gradient: [
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                      theme.colorScheme.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  _MetricCard(
                    icon: Icons.headphones_rounded,
                    label: 'Unique Listeners',
                    value: _fmtNumber(metrics.uniqueListeners24h),
                    color: theme.colorScheme.secondary,
                    gradient: [
                      theme.colorScheme.secondary.withValues(alpha: 0.15),
                      theme.colorScheme.secondary.withValues(alpha: 0.05),
                    ],
                  ),
                  _MetricCard(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Avg Completion',
                    value: '${metrics.avgCompletionPct.toStringAsFixed(1)}%',
                    color: Colors.green,
                    gradient: [
                      Colors.green.withValues(alpha: 0.15),
                      Colors.green.withValues(alpha: 0.05),
                    ],
                  ),
                  _MetricCard(
                    icon: Icons.skip_next_rounded,
                    label: 'Skip Rate',
                    value: '${metrics.skipRatePct.toStringAsFixed(1)}%',
                    color: Colors.orange,
                    gradient: [
                      Colors.orange.withValues(alpha: 0.15),
                      Colors.orange.withValues(alpha: 0.05),
                    ],
                  ),
                  _MetricCard(
                    icon: Icons.favorite_rounded,
                    label: 'Total Likes',
                    value: _fmtNumber(metrics.totalLikes),
                    color: Colors.redAccent,
                    gradient: [
                      Colors.redAccent.withValues(alpha: 0.15),
                      Colors.redAccent.withValues(alpha: 0.05),
                    ],
                  ),
                  _MetricCard(
                    icon: Icons.thumb_down_rounded,
                    label: 'Total Dislikes',
                    value: _fmtNumber(metrics.totalDislikes),
                    color: Colors.blueGrey,
                    gradient: [
                      Colors.blueGrey.withValues(alpha: 0.15),
                      Colors.blueGrey.withValues(alpha: 0.05),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Refresh Trending Card
          Text(
            'Trending & Popularity',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  theme.colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.trending_up_rounded,
                          color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Refresh Trending Data',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Recalculates popularity scores, refreshes trending tracks & artists materialized views.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isRefreshing ? null : onRefreshTrending,
                    icon: isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      isRefreshing ? 'Refreshing...' : 'Refresh Now',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Recommended to run every 2 hours for fresh data.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Like ratio indicator
          Text(
            'Like Ratio',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _LikeRatioBar(
            likes: metrics.totalLikes,
            dislikes: metrics.totalDislikes,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  String _fmtNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final List<Color> gradient;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LikeRatioBar extends StatelessWidget {
  final int likes;
  final int dislikes;

  const _LikeRatioBar({required this.likes, required this.dislikes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = likes + dislikes;
    final likeRatio = total > 0 ? likes / total : 0.5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_rounded,
                      color: Colors.redAccent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '$likes likes',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                '${(likeRatio * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                ),
              ),
              Row(
                children: [
                  Text(
                    '$dislikes dislikes',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.thumb_down_rounded,
                      color: Colors.blueGrey, size: 18),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (likeRatio * 100).round(),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.redAccent.shade200,
                            Colors.redAccent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - likeRatio) * 100).round().clamp(1, 100),
                    child: Container(color: Colors.blueGrey.shade300),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
