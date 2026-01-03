# SignSync User Guide

## 🎯 Welcome to SignSync!

SignSync is a comprehensive accessibility app designed to help Deaf and hard-of-hearing users navigate the world with confidence. This guide will help you get started and make the most of all features.

## 📱 Getting Started

### First Launch
1. **Grant Permissions**: SignSync needs camera and microphone access
2. **Complete Tutorial**: Follow the guided tour to learn features
3. **Choose Settings**: Configure accessibility preferences
4. **Start Exploring**: Begin with Dashboard mode

### Essential Settings
```dart
// Recommended settings for new users
final recommendedSettings = {
  'theme': 'system', // Follow device theme
  'textScale': 1.0,  // Normal text size
  'highContrast': false, // Enable if needed
  'cameraResolution': 'medium', // Balanced quality/performance
  'inferenceFrequency': 'auto', // Adaptive based on device
  'audioAlerts': true, // Spatial audio enabled
  'voiceCommands': true, // Voice input enabled
  'language': 'en-US', // English (US)
};
```

## 🎯 Core Features Guide

### 1. ASL Translation Mode

#### What It Does
Translates American Sign Language in real-time using your camera.

#### How to Use
1. **Open ASL Translation Mode**
   - Tap "ASL Translation" on dashboard
   - Or use voice command: "Open ASL translation"

2. **Position Yourself**
   - Center yourself in camera view
   - Ensure good lighting
   - Keep hands visible in frame
   - Maintain 2-3 feet distance

3. **Sign Naturally**
   - Use clear, distinct hand shapes
   - Maintain eye contact with camera
   - Allow 2-3 seconds per sign
   - Results appear automatically

#### Tips for Better Recognition
- **Lighting**: Well-lit environment improves accuracy
- **Background**: Plain background works best
- **Clothing**: Avoid patterns that might confuse the AI
- **Speed**: Sign at normal conversational pace
- **Consistency**: Use consistent hand shapes

#### Understanding Results
```
Confidence Level Guide:
🟢 Green (85%+): High confidence, very likely correct
🟡 Yellow (70-84%): Medium confidence, check context
🔴 Red (<70%): Low confidence, try again
```

### 2. Object Detection Mode

#### What It Does
Identifies objects around you and provides spatial audio alerts.

#### How to Use
1. **Enable Object Detection**
   - Tap "Object Detection" on dashboard
   - Camera will start automatically

2. **Spatial Audio Setup**
   - Wear headphones for best experience
   - Volume should be at comfortable level
   - Spatial audio provides left/right/center positioning

3. **Understanding Alerts**
   - **High Priority**: Cars, traffic lights, people
   - **Medium Priority**: Chairs, doors, stairs
   - **Low Priority**: Books, bottles, electronics

#### Alert Examples
```
Person detected: "Ahead, person"
Car on left: "On your left, car"
Door on right: "On your right, door"
Traffic light: "Ahead, traffic light"
```

### 3. Sound Alerts Mode

#### What It Does
Detects important sounds and provides haptic feedback.

#### How to Use
1. **Enable Sound Alerts**
   - Tap "Sound Alerts" on dashboard
   - Grant microphone permission

2. **Haptic Feedback Patterns**
   ```
   Doorbell: Light vibration (2x)
   Alarm: Heavy vibration (continuous)
   Siren: Medium vibration (3x)
   Door knock: Light vibration (1x)
   ```

3. **Visual Indicators**
   - Sound wave animation shows audio input
   - Color changes based on sound type
   - Text descriptions for detected sounds

### 4. AI Assistant Mode

#### What It Does
Provides intelligent assistance through conversation.

#### How to Use
1. **Start Conversation**
   - Tap "AI Assistant" on dashboard
   - Type or speak your question

2. **Voice Commands**
   - Tap microphone icon
   - Speak clearly
   - Wait for acknowledgment

3. **Example Conversations**
   ```
   User: "What does this sign mean?"
   AI: "Could you show me the sign you're asking about? I can help explain ASL signs."

   User: "How do I learn ASL?"
   AI: "Great question! Here are some effective ways to learn ASL:
   1. Take formal classes
   2. Practice with Deaf community members
   3. Use online resources
   4. Practice daily with apps like SignSync"

   User: "What's around me?"
   AI: "I can help you understand what's detected around you. Switch to Object Detection mode to hear spatial audio alerts about nearby objects."
   ```

### 5. Person Recognition Mode

#### What It Does
Recognizes familiar faces with privacy protection.

#### How to Use
1. **Enable Person Recognition**
   - Tap "Person Recognition" on dashboard
   - Grant camera permission

2. **Add Familiar Faces**
   - Tap "Add Person"
   - Position face in frame
   - Name the person
   - Recognition happens automatically

3. **Privacy Controls**
   - All face data stored locally
   - No cloud uploads
   - Easy deletion of stored faces
   - Encrypted storage

## ⚙️ Settings Guide

### Accessibility Settings
```
Theme: Light / Dark / System
Text Scale: 0.8x - 2.0x
High Contrast: Enable for better visibility
Screen Reader: Optimize for TalkBack/VoiceOver
Haptic Feedback: Enable for tactile feedback
Voice Commands: Enable voice control
```

### Performance Settings
```
Camera Resolution:
- Low: Better battery, lower quality
- Medium: Balanced (recommended)
- High: Best quality, higher battery

Inference Frequency:
- Auto: Adapts to device capability
- 30 FPS: Maximum responsiveness
- 15 FPS: Battery saving mode
- 10 FPS: Ultra battery saving

Memory Optimization:
- Normal: Full features
- Low Memory: Optimized for older devices
```

### Alert Settings
```
Audio Alerts:
- Enable/Disable all audio alerts
- Volume control (0-100%)
- Speech rate adjustment
- Pitch control

Spatial Audio:
- Enable directional audio
- Left/right positioning
- Distance estimation

Haptic Patterns:
- Different patterns for alert types
- Intensity control
- Duration settings
```

### Privacy Settings
```
Data Storage:
- Local only (recommended)
- Encrypted storage
- Auto-delete old data

Face Recognition:
- Enable/disable recognition
- Manage stored faces
- Clear all recognition data

Chat History:
- Save conversations
- Auto-cleanup old chats
- Export chat history
```

## 🔧 Troubleshooting

### Quick Fixes
```dart
// Reset to default settings
SettingsService.resetToDefaults();

// Clear app cache
await CacheManager.clearAllCache();

// Restart camera service
await CameraService.restart();

// Check system health
final health = await SystemHealthChecker.checkAll();
```

### Performance Tips
1. **Close Other Apps**: Free up memory for better performance
2. **Good Lighting**: Improves ML accuracy significantly
3. **Stable Camera**: Hold device steady for better detection
4. **Regular Updates**: Keep app updated for improvements
5. **Device Restart**: Restart device if experiencing issues

### Common Solutions
```
Camera Issues:
- Check permissions in device settings
- Restart app if camera won't start
- Ensure good lighting conditions

Poor Recognition:
- Adjust lighting and background
- Ensure hands are clearly visible
- Sign at normal pace
- Check confidence thresholds

Audio Problems:
- Check device volume settings
- Ensure permissions granted
- Try different audio output device
- Disable "Do Not Disturb" mode
```

## 🎓 Learning ASL with SignSync

### Getting Started
1. **Start with Alphabet**: Learn A-Z fingerspelling
2. **Basic Words**: Practice common words and phrases
3. **Numbers**: Learn to count and tell time
4. **Sentences**: Combine signs for communication

### Practice Recommendations
- **Daily Practice**: 15-30 minutes daily
- **Natural Signing**: Practice conversational signing
- **Record Yourself**: Use camera to check your signs
- **Community**: Connect with ASL learners online

### Resources
- **Tutorial Videos**: Available in-app
- **Practice Modes**: Guided learning sessions
- **Progress Tracking**: Monitor your improvement
- **Community Features**: Connect with other learners

## 🚀 Advanced Features

### Voice Commands
```
"Open ASL translation"
"Show me object detection"
"Enable sound alerts"
"Start AI assistant"
"What's my battery level?"
"Take a screenshot"
"Open settings"
"Help me with ASL"
```

### Shortcuts
- **Triple-tap home**: Quick mode switch
- **Volume button + power**: Screenshot
- **Shake device**: Emergency help
- **Voice trigger word**: "Hey SignSync"

### Integration Features
- **Contact Sharing**: Share recognized signs with contacts
- **Calendar Integration**: Set reminders for practice
- **Accessibility Services**: Integration with system AT
- **External Displays**: Support for connected displays

## 📊 Understanding Your Data

### Performance Dashboard
The dashboard shows real-time statistics:
- **FPS**: Current camera frame rate
- **Latency**: ML processing time
- **Accuracy**: Recognition confidence
- **Battery**: Estimated remaining usage
- **Memory**: Current app memory usage

### Progress Tracking
- **Daily Usage**: Time spent in each mode
- **Accuracy Trends**: Improvement over time
- **Feature Usage**: Most/least used features
- **Performance Metrics**: Device-specific optimization

### Health Monitoring
- **System Health**: Overall app status
- **Model Status**: Individual ML model health
- **Permission Status**: Required permissions
- **Connectivity**: Network status for AI features

## 🆘 Emergency Features

### Quick Help
- **Emergency Button**: Always visible on dashboard
- **Location Sharing**: Share location with trusted contacts
- **Medical Info**: Store important medical information
- **Contact Emergency**: One-tap calling of emergency contacts

### Accessibility Emergency
- **High Contrast Mode**: Instant high contrast
- **Large Text**: Emergency text size increase
- **Voice Commands**: Hands-free operation
- **Haptic Emergency**: Distinctive vibration pattern

## 📞 Support & Community

### Getting Help
1. **In-App Help**: Settings > Help & Support
2. **Tutorial Screens**: Available for all features
3. **FAQ Section**: Common questions answered
4. **Contact Support**: Direct email support

### Community
- **ASL Learners**: Connect with other learners
- **Deaf Community**: Join the community
- **Resources**: Share learning materials
- **Events**: Find local ASL events

### Feedback
- **Rate App**: Share your experience
- **Feature Requests**: Suggest improvements
- **Bug Reports**: Report issues
- **Success Stories**: Share your achievements

---

*This user guide is continuously updated. Check the in-app help section for the latest information and tutorials.*