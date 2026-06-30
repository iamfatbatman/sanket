import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech_to_text;
import '../widgets/alphabet_sign_video_player.dart';
import '../widgets/primary_button.dart';
import '../widgets/transcript_card.dart';

class SpeechToSignScreen extends StatefulWidget {
  const SpeechToSignScreen({super.key});

  @override
  State<SpeechToSignScreen> createState() => _SpeechToSignScreenState();
}

class _SpeechToSignScreenState extends State<SpeechToSignScreen>
    with SingleTickerProviderStateMixin {
  bool isListening = false;
  bool _speechEnabled = false;
  String? _speechLocaleId;
  String _statusText = "Tap start and allow microphone access.";
  String recognizedText = "";
  late AnimationController _micAnimController;
  late final speech_to_text.SpeechToText _speechToText;

  @override
  void initState() {
    super.initState();
    _speechToText = speech_to_text.SpeechToText();
    _micAnimController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _speechToText.cancel();
    _micAnimController.dispose();
    super.dispose();
  }

  Future<bool> _initializeSpeech() async {
    if (_speechEnabled) {
      return true;
    }

    final available = await _speechToText.initialize(
      onStatus: _handleSpeechStatus,
      onError: (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          isListening = false;
          _statusText = error.errorMsg;
        });
        _micAnimController.stop();
      },
    );

    if (!mounted) {
      return false;
    }

    final englishLocaleId = available ? await _findEnglishLocaleId() : null;
    if (!mounted) {
      return false;
    }

    setState(() {
      _speechEnabled = available;
      _speechLocaleId = englishLocaleId;
      _statusText = available
          ? englishLocaleId == null
                ? "Ready to listen. English speech is not installed, using device default."
                : "Ready to listen in English."
          : "Speech recognition is not available on this device.";
    });

    return available;
  }

  Future<String?> _findEnglishLocaleId() async {
    final locales = await _speechToText.locales();

    for (final locale in locales) {
      final normalized = locale.localeId.toLowerCase().replaceAll('-', '_');
      if (normalized == 'en_us') {
        return locale.localeId;
      }
    }

    for (final locale in locales) {
      final normalized = locale.localeId.toLowerCase().replaceAll('-', '_');
      if (normalized.startsWith('en_') || normalized == 'en') {
        return locale.localeId;
      }
    }

    return null;
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }

    final listening = status == speech_to_text.SpeechToText.listeningStatus;

    setState(() {
      isListening = listening;
      _statusText = listening ? "Listening..." : "Ready to listen.";
    });

    if (listening) {
      _micAnimController.repeat();
    } else {
      _micAnimController.stop();
    }
  }

  Future<void> startListening() async {
    final available = await _initializeSpeech();
    if (!available || isListening) {
      return;
    }

    setState(() {
      isListening = true;
      _statusText = _speechLocaleId == null
          ? "Listening with device default language..."
          : "Listening in English...";
    });
    _micAnimController.repeat();

    await _speechToText.listen(
      onResult: (result) {
        if (!mounted) {
          return;
        }

        setState(() {
          recognizedText = result.recognizedWords;
        });
      },
      listenOptions: speech_to_text.SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        listenMode: speech_to_text.ListenMode.dictation,
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 5),
        localeId: _speechLocaleId,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    if (!mounted) {
      return;
    }

    setState(() {
      isListening = false;
      _statusText = "Ready to listen.";
    });
    _micAnimController.stop();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text("Speech to Sign"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: [primary, primary.withValues(alpha: .75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      "Speech to Sign",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Speak naturally and we'll convert your voice into sign language instantly.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              /// Microphone Section
              Text(
                "Microphone",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              /// Status Container with Stop Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 30,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: isListening ? stopListening : startListening,
                      child: AnimatedBuilder(
                        animation: _micAnimController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              if (isListening)
                                Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: primary.withValues(
                                        alpha:
                                            0.3 *
                                            (1 - _micAnimController.value),
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              if (isListening)
                                Container(
                                  width: 105,
                                  height: 105,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: primary.withValues(
                                        alpha:
                                            0.4 *
                                            (1 - _micAnimController.value),
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: .12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.mic,
                                  size: 42,
                                  color: primary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isListening ? "Listening..." : "Ready to listen",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: isListening
                            ? "Stop Listening"
                            : "Start Listening",
                        onPressed: isListening ? stopListening : startListening,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              /// Sign Language Output
              Text(
                "Sign Language Output",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AlphabetSignVideoPlayer(text: recognizedText),
                ),
              ),

              const SizedBox(height: 28),

              /// Live Transcript
              Text(
                "Live Transcript",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              TranscriptCard(
                title: "Speech Recognition",
                content: recognizedText.isEmpty
                    ? "Your speech will appear here..."
                    : recognizedText,
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xffEEF5FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: primary, size: 30),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Your speech will be converted into text and displayed as sign language animation in real time.",
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
