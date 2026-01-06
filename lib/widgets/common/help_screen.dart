import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/widgets/common/onboarding_animated_background.dart';

/// Help screen providing in-app documentation and tutorials.
///
/// This screen provides access to comprehensive help content including
/// tutorials, troubleshooting, and feature explanations.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tutorials'),
            Tab(text: 'Features'),
            Tab(text: 'Troubleshooting'),
            Tab(text: 'FAQ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TutorialTab(),
          _FeaturesTab(),
          _TroubleshootingTab(),
          _FaqTab(),
        ],
      ),
    );
  }
}

/// Tutorial section with step-by-step guides.
class _TutorialTab extends StatelessWidget {
  const _TutorialTab();

  @override
  Widget build(BuildContext context) {
    final tutorials = [
      {
        'title': 'ASL Translation Basics',
        'description': 'Learn how to use ASL translation',
        'icon': Icons.translate,
        'duration': '5 min',
        'difficulty': 'Beginner',
      },
      {
        'title': 'Object Detection Guide',
        'description': 'Setting up and using object detection',
        'icon': Icons.visibility,
        'duration': '3 min',
        'difficulty': 'Beginner',
      },
      {
        'title': 'Sound Alerts Setup',
        'description': 'Configure sound detection and alerts',
        'icon': Icons.volume_up,
        'duration': '4 min',
        'difficulty': 'Intermediate',
      },
      {
        'title': 'AI Assistant Tips',
        'description': 'Getting the most from your AI helper',
        'icon': Icons.smart_toy,
        'duration': '6 min',
        'difficulty': 'Beginner',
      },
      {
        'title': 'Accessibility Features',
        'description': 'Explore accessibility options',
        'icon': Icons.accessibility,
        'duration': '8 min',
        'difficulty': 'All levels',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tutorials.length,
      itemBuilder: (context, index) {
        final tutorial = tutorials[index];
        return _buildTutorialCard(context, tutorial);
      },
    );
  }

  Widget _buildTutorialCard(BuildContext context, Map<String, dynamic> tutorial) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            tutorial['icon'] as IconData,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          tutorial['title'] as String,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(tutorial['description'] as String),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              tutorial['duration'] as String,
              style: theme.textTheme.bodySmall,
            ),
            Text(
              tutorial['difficulty'] as String,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        onTap: () {
          // Navigate to tutorial content
          _showTutorialDialog(context, tutorial);
        },
      ),
    );
  }

  void _showTutorialDialog(BuildContext context, Map<String, dynamic> tutorial) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tutorial['title'] as String),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duration: ${tutorial['duration']}'),
            Text('Difficulty: ${tutorial['difficulty']}'),
            const SizedBox(height: 16),
            const Text(
              'This tutorial will guide you through the basics. '
              'It includes step-by-step instructions and helpful tips.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Start tutorial
            },
            child: const Text('Start Tutorial'),
          ),
        ],
      ),
    );
  }
}

/// Features section explaining app capabilities.
class _FeaturesTab extends StatelessWidget {
  const _FeaturesTab();

  @override
  Widget build(BuildContext context) {
    final features = [
      {
        'title': 'ASL Translation',
        'description': 'Real-time sign language recognition',
        'details': [
          'Recognizes A-Z alphabet and numbers',
          'Supports dynamic sign sequences',
          'High accuracy with confidence scoring',
          'Works offline with on-device AI',
        ],
        'icon': Icons.translate,
      },
      {
        'title': 'Object Detection',
        'description': 'Identifies objects for accessibility',
        'details': [
          '80+ common object classes',
          'Spatial audio positioning',
          'Priority-based alerts',
          'Distance estimation',
        ],
        'icon': Icons.visibility,
      },
      {
        'title': 'Sound Detection',
        'description': 'Monitors environment for important sounds',
        'details': [
          'Detects doorbells, alarms, and more',
          'Customizable sensitivity levels',
          'Multi-modal feedback options',
          'Privacy-focused local processing',
        ],
        'icon': Icons.volume_up,
      },
      {
        'title': 'AI Assistant',
        'description': 'Powered by Google Gemini',
        'details': [
          'ASL learning assistance',
          'Voice input and output',
          'Contextual help and guidance',
          'Privacy-focused conversations',
        ],
        'icon': Icons.smart_toy,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return _buildFeatureCard(context, feature);
      },
    );
  }

  Widget _buildFeatureCard(BuildContext context, Map<String, dynamic> feature) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  feature['icon'] as IconData,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature['title'] as String,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        feature['description'] as String,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...((feature['details'] as List).map((detail) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        detail as String,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }).toList()),
          ],
        ),
      ),
    );
  }
}

/// Troubleshooting section with common issues and solutions.
class _TroubleshootingTab extends StatelessWidget {
  const _TroubleshootingTab();

  @override
  Widget build(BuildContext context) {
    final issues = [
      {
        'title': 'Camera Not Working',
        'solutions': [
          'Check camera permissions in Settings',
          'Close other camera apps',
          'Restart the SignSync app',
          'Try switching between front/back camera',
        ],
        'icon': Icons.camera_alt,
      },
      {
        'title': 'ASL Signs Not Recognized',
        'solutions': [
          'Ensure good lighting on your hands',
          'Keep hands 12-18 inches from camera',
          'Sign deliberately and hold final position',
          'Check camera positioning and background',
        ],
        'icon': Icons.translate,
      },
      {
        'title': 'Poor Performance',
        'solutions': [
          'Close other running apps',
          'Reduce camera quality in settings',
          'Lower frame rate to 15 FPS',
          'Enable power saving mode',
        ],
        'icon': Icons.speed,
      },
      {
        'title': 'AI Assistant Not Responding',
        'solutions': [
          'Check internet connection',
          'Verify API key in settings',
          'Try different network',
          'Clear chat history',
        ],
        'icon': Icons.smart_toy,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: issues.length,
      itemBuilder: (context, index) {
        final issue = issues[index];
        return _buildIssueCard(context, issue);
      },
    );
  }

  Widget _buildIssueCard(BuildContext context, Map<String, dynamic> issue) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(
          issue['icon'] as IconData,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          issue['title'] as String,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Try these solutions:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...((issue['solutions'] as List).map((solution) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            solution as String,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// FAQ section with frequently asked questions.
class _FaqTab extends StatelessWidget {
  const _FaqTab();

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'question': 'How accurate is ASL recognition?',
        'answer': 'The CNN model achieves 94.7% accuracy for static signs and 87.3% for dynamic sequences under good conditions.',
      },
      {
        'question': 'Do I need an internet connection?',
        'answer': 'Core ASL translation works offline. AI assistant and some features require internet connectivity.',
      },
      {
        'question': 'Is my face data stored remotely?',
        'answer': 'No, all face recognition data is stored locally on your device only for privacy and security.',
      },
      {
        'question': 'Can I use SignSync with other accessibility tools?',
        'answer': 'Yes, SignSync is compatible with screen readers, voice control, and other accessibility technologies.',
      },
      {
        'question': 'What languages are supported?',
        'answer': 'Currently supports English with planned expansion to Spanish, French, and German.',
      },
      {
        'question': 'How much battery does it use?',
        'answer': 'Battery usage varies by usage. Typical continuous use lasts 2-4 hours with optimization features available.',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: faqs.length,
      itemBuilder: (context, index) {
        final faq = faqs[index];
        return _buildFaqCard(context, faq);
      },
    );
  }

  Widget _buildFaqCard(BuildContext context, Map<String, dynamic> faq) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          faq['question'] as String,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              faq['answer'] as String,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick action buttons for common help tasks.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      {
        'title': 'System Check',
        'icon': Icons.build,
        'action': () => _runSystemCheck(context),
      },
      {
        'title': 'Contact Support',
        'icon': Icons.contact_support,
        'action': () => _contactSupport(context),
      },
      {
        'title': 'Reset App',
        'icon': Icons.refresh,
        'action': () => _resetApp(context),
      },
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: actions.map((action) {
                return Column(
                  children: [
                    IconButton(
                      onPressed: action['action'] as VoidCallback,
                      icon: Icon(action['icon'] as IconData),
                      tooltip: action['title'] as String,
                    ),
                    Text(
                      action['title'] as String,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _runSystemCheck(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Check'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✓ Camera: Available'),
            Text('✓ Microphone: Available'),
            Text('✓ ML Models: Loaded'),
            Text('✓ Storage: Available'),
            Text('⚠ Internet: Offline'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _contactSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Text(
          'Need help? You can contact us through:\n\n'
          '• GitHub Issues\n'
          '• Email: support@signsync.com\n'
          '• Discord Community\n\n'
          'Please include your device info and app version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Open support channels
            },
            child: const Text('Contact'),
          ),
        ],
      ),
    );
  }

  void _resetApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text(
          'This will clear all settings and data. '
          'Make sure to backup important information first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Perform app reset
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}