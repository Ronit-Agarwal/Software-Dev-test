import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/widgets/common/onboarding_animated_background.dart';

/// Feature overview screen for onboarding.
///
/// This screen provides detailed information about each SignSync feature
/// to help users understand what the app can do for them.
class OnboardingFeaturesScreen extends ConsumerStatefulWidget {
  const OnboardingFeaturesScreen({super.key});

  @override
  ConsumerState<OnboardingFeaturesScreen> createState() =>
      _OnboardingFeaturesScreenState();
}

class _OnboardingFeaturesScreenState extends ConsumerState<OnboardingFeaturesScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _slideController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Animated background
            const OnboardingAnimatedBackground(),
            
            // Main content
            Column(
              children: [
                // Header
                _buildHeader(theme),
                
                // Page indicator
                _buildPageIndicator(),
                
                // Feature pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: const [
                      _AslTranslationFeaturePage(),
                      _ObjectDetectionFeaturePage(),
                      _SoundDetectionFeaturePage(),
                      _AiAssistantFeaturePage(),
                    ],
                  ),
                ),
                
                // Navigation buttons
                _buildNavigationButtons(theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_currentPage > 0) {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else {
                context.pop();
              }
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: theme.colorScheme.onSurface,
            ),
          ),
          
          Expanded(
            child: Text(
              'Explore Features',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(width: 48), // Spacer for alignment
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          // Skip button
          TextButton(
            onPressed: () {
              context.push('/onboarding/permissions');
            },
            child: Text(
              'Skip',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          
          const Spacer(),
          
          // Next/Continue button
          ElevatedButton(
            onPressed: () {
              if (_currentPage < 3) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else {
                context.push('/onboarding/permissions');
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              _currentPage < 3 ? 'Next' : 'Continue',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ASL Translation feature page.
class _AslTranslationFeaturePage extends StatelessWidget {
  const _AslTranslationFeaturePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feature icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.translate,
              size: 64,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Feature title
          Text(
            'ASL Translation',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Feature description
          Text(
            'Real-time American Sign Language recognition using advanced AI models.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Feature details
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Static sign recognition (A-Z, numbers)',
          ),
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Dynamic sign sequences and phrases',
          ),
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'High accuracy with confidence scoring',
          ),
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Real-time processing at 15-20 FPS',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Object Detection feature page.
class _ObjectDetectionFeaturePage extends StatelessWidget {
  const _ObjectDetectionFeaturePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feature icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.secondary,
                  theme.colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.visibility,
              size: 64,
              color: theme.colorScheme.onSecondary,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Feature title
          Text(
            'Object Detection',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Feature description
          Text(
            'Identify objects in your surroundings using your camera for enhanced accessibility.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Feature details
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Recognize 80+ common objects',
          ),
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Spatial audio positioning',
          ),
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Priority-based alert system',
          ),
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Distance estimation',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sound Detection feature page.
class _SoundDetectionFeaturePage extends StatelessWidget {
  const _SoundDetectionFeaturePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feature icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.tertiary,
                  theme.colorScheme.tertiaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.volume_up,
              size: 64,
              color: theme.colorScheme.onTertiary,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Feature title
          Text(
            'Sound Detection',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Feature description
          Text(
            'Monitor your environment for important sounds and receive audio, visual, and haptic alerts.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Feature details
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Detect doorbells, alarms, and more',
          ),
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Customizable sensitivity levels',
          ),
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Multiple alert types (audio, visual, haptic)',
          ),
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Privacy-focused local processing',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.tertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// AI Assistant feature page.
class _AiAssistantFeaturePage extends StatelessWidget {
  const _AiAssistantFeaturePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feature icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.smart_toy,
              size: 64,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Feature title
          Text(
            'AI Assistant',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Feature description
          Text(
            'Get help with ASL learning, app features, and accessibility questions from our AI assistant.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Feature details
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'ASL learning assistance',
          ),
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Voice input and output',
          ),
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Contextual help and guidance',
          ),
          _buildDetailItem(
            theme,
            Icons.check_circle,
            'Privacy-focused conversations',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}