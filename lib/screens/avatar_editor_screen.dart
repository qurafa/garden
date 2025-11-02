import 'package:flutter/material.dart';
import '../models/avatar_model.dart';
import '../painters/avatar_painter.dart';

class AvatarEditorScreen extends StatefulWidget {
  final Avatar initialAvatar;

  const AvatarEditorScreen({
    Key? key,
    required this.initialAvatar,
  }) : super(key: key);

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  late Avatar _currentAvatar;

  @override
  void initState() {
    super.initState();
    _currentAvatar = widget.initialAvatar;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CUSTOMIZE AVATAR',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        backgroundColor: const Color(0xFF2d5016),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _currentAvatar);
            },
            child: const Text(
              'SAVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2d5016), Color(0xFF1a1a1a)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  children: [
                    const Text(
                      'PREVIEW',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomPaint(
                      size: const Size(120, 120),
                      painter: AvatarPainter(
                        avatar: _currentAvatar,
                        size: 120,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Face Color
              _buildSection(
                title: 'FACE COLOR',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: Avatar.presetColors.map((color) {
                    final isSelected = _currentAvatar.faceColor == color;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentAvatar = _currentAvatar.copyWith(faceColor: color);
                        });
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.green,
                            width: isSelected ? 4 : 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Eyes
              _buildSection(
                title: 'EYES',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    final isSelected = _currentAvatar.eyeStyle == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentAvatar = _currentAvatar.copyWith(eyeStyle: index);
                        });
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.green,
                            width: isSelected ? 3 : 2,
                          ),
                        ),
                        child: CustomPaint(
                          painter: AvatarPainter(
                            avatar: Avatar(
                              faceColor: _currentAvatar.faceColor,
                              eyeStyle: index,
                              mouthStyle: 2, // Neutral for preview
                            ),
                            size: 50,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Mouth
              _buildSection(
                title: 'MOUTH',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    final isSelected = _currentAvatar.mouthStyle == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentAvatar = _currentAvatar.copyWith(mouthStyle: index);
                        });
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.green,
                            width: isSelected ? 3 : 2,
                          ),
                        ),
                        child: CustomPaint(
                          painter: AvatarPainter(
                            avatar: Avatar(
                              faceColor: _currentAvatar.faceColor,
                              eyeStyle: 0, // Normal for preview
                              mouthStyle: index,
                            ),
                            size: 50,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Labels
              _buildLabels(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildLabels() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        border: Border.all(color: const Color.fromARGB(126, 76, 175, 79), width: 2),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EYES:',
            style: TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '• Dots  • Wide  • Happy  • Wink  • Star',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          SizedBox(height: 12),
          Text(
            'MOUTH:',
            style: TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '• Smile  • Big Smile  • Neutral  • Open  • Sad',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}