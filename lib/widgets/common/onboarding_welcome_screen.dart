import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/widgets/common/onboarding_animated_background.dart';

/// Welcome screen for first-time users.
///
/// This screen introduces SignSync and its core features to new users
/// with an engaging onboarding experience.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _startAnimations();
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _fadeController.forward();
    });
    
    Future.delayed(const Duration(milliseconds: 600), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App logo and title
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildHeader(theme),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Features preview
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildFeatures(theme),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Get started button
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildGetStartedButton(theme),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        // App icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.sign_language,
            size: 64,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // App name
        Text(
          'SignSync',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        // Tagline
        Text(
          'Breaking barriers with AI-powered ASL translation',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatures(ThemeData theme) {
    final features = [
      {
        'icon': Icons.translate,
        'title': 'ASL Translation',
        'description': 'Real-time sign language recognition',
      },
      {
        'icon': Icons.visibility,
        'title': 'Object Detection',
        'description': 'Identify objects in your surroundings',
      },
      {
        'icon': Icons.volume_up,
        'title': 'Sound Alerts',
        'description': 'Audio notifications for important sounds',
      },
      {
        'icon': Icons.smart_toy,
        'title': 'AI Assistant',
        'description': 'Get help with ASL and accessibility',
      },
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _buildFeatureItem(theme, feature),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureItem(ThemeData theme, Map<String, dynamic> feature) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            feature['icon'] as IconData,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feature['title'] as String,
                style: theme.textTheme.titleMedium?.copyWith(
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
    );
  }

  Widget _buildGetStartedButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: () {
        context.push('/onboarding/features');
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      child: Text(
        'Get Started',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Animated background for onboarding screens.
class OnboardingAnimatedBackground extends StatefulWidget {
  const OnboardingAnimatedBackground({super.key});

  @override
  State<OnboardingAnimatedBackground> createState() =>
      _OnboardingAnimatedBackgroundState();
}

class _OnboardingAnimatedBackgroundState extends State<OnboardingAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _BackgroundPainter(
            animation: _animation.value,
            primaryColor: theme.colorScheme.primary.withOpacity(0.1),
            secondaryColor: theme.colorScheme.secondary.withOpacity(0.1),
          ),
          child: Container(),
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double animation;
  final Color primaryColor;
  final Color secondaryColor;

  _BackgroundPainter({
    required this.animation,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Draw animated circles
    for (int i = 0; i < 5; i++) {
      final offset = Offset(
        size.width * (0.2 + 0.6 * (i / 4.0 + animation) % 1.0),
        size.height * (0.2 + 0.6 * ((i / 4.0 + animation * 0.5) % 1.0)),
      );
      
      paint.color = i % 2 == 0 ? primaryColor : secondaryColor;
      paint.style = PaintingStyle.fill;
      
      canvas.drawCircle(
        offset,
        60.0 + 40.0 * (1.0 + animation),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}