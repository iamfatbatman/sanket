import 'package:flutter/material.dart';

import '../widgets/feature_card.dart';
import 'sign_to_speech_screen.dart';
import 'speech_to_sign_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        final cards = [
          FeatureCard(
            icon: Icons.mic_rounded,
            title: 'Speech to Sign',
            subtitle:
                'Convert spoken words into real-time sign language animation.',
            buttonLabel: 'Start Speaking',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SpeechToSignScreen()),
              );
            },
          ),
          FeatureCard(
            icon: Icons.sign_language_rounded,
            title: 'Sign to Speech',
            subtitle:
                'Recognize sign language and convert it into text and voice.',
            buttonLabel: 'Start Camera',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignToSpeechScreen()),
              );
            },
          ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              Text(
                "Speak.Sign.Connect",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "Convert speech into sign language and signs into speech instantly.",
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 18),
              if (isWide)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) => cards[index],
                )
              else
                Column(
                  children: cards
                      .map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: card,
                        ),
                      )
                      .toList(),
                ),

              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}
