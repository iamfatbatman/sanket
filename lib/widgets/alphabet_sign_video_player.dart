import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class AlphabetSignVideoPlayer extends StatefulWidget {
  const AlphabetSignVideoPlayer({
    super.key,
    required this.text,
    this.assetBasePath = 'assets/signs/alphabet',
  });

  final String text;
  final String assetBasePath;

  @override
  State<AlphabetSignVideoPlayer> createState() =>
      _AlphabetSignVideoPlayerState();
}

class _AlphabetSignVideoPlayerState extends State<AlphabetSignVideoPlayer> {
  final Map<String, bool> _assetAvailability = {};
  final Set<String> _missingLetters = {};

  VideoPlayerController? _controller;
  List<String> _letters = [];
  List<String> _playableLetters = [];
  int _currentIndex = 0;
  bool _isPreparing = false;
  bool _isAdvancing = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _prepareLetters(widget.text);
  }

  @override
  void didUpdateWidget(covariant AlphabetSignVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.assetBasePath != widget.assetBasePath) {
      _prepareLetters(widget.text);
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _prepareLetters(String text) async {
    final token = ++_loadToken;
    final letters = RegExp(
      r'[a-z]',
    ).allMatches(text.toLowerCase()).map((match) => match.group(0)!).toList();

    _disposeController();

    if (!mounted) {
      return;
    }

    setState(() {
      _letters = letters;
      _playableLetters = [];
      _missingLetters.clear();
      _currentIndex = 0;
      _isPreparing = letters.isNotEmpty;
    });

    if (letters.isEmpty) {
      if (mounted) {
        setState(() => _isPreparing = false);
      }
      return;
    }

    final playableLetters = <String>[];
    final missingLetters = <String>{};

    for (final letter in letters) {
      final available = await _hasAssetFor(letter);
      if (token != _loadToken || !mounted) {
        return;
      }

      if (available) {
        playableLetters.add(letter);
      } else {
        missingLetters.add(letter);
      }
    }

    if (!mounted || token != _loadToken) {
      return;
    }

    setState(() {
      _playableLetters = playableLetters;
      _missingLetters
        ..clear()
        ..addAll(missingLetters);
      _isPreparing = false;
    });

    if (playableLetters.isNotEmpty) {
      await _loadVideoAt(0, token);
    }
  }

  Future<bool> _hasAssetFor(String letter) async {
    final cached = _assetAvailability[letter];
    if (cached != null) {
      return cached;
    }

    final path = _assetPathFor(letter);

    try {
      await rootBundle.load(path);
      _assetAvailability[letter] = true;
      return true;
    } catch (_) {
      _assetAvailability[letter] = false;
      return false;
    }
  }

  Future<void> _loadVideoAt(int index, [int? token]) async {
    if (_playableLetters.isEmpty ||
        index < 0 ||
        index >= _playableLetters.length) {
      return;
    }

    final activeToken = token ?? _loadToken;
    final letter = _playableLetters[index];
    final controller = VideoPlayerController.asset(_assetPathFor(letter));

    _disposeController();

    if (mounted) {
      setState(() {
        _currentIndex = index;
        _isPreparing = true;
      });
    }

    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      if (!mounted || activeToken != _loadToken) {
        return;
      }

      setState(() {
        _missingLetters.add(letter);
        _playableLetters.removeAt(index);
        _currentIndex = 0;
        _isPreparing = false;
      });

      if (_playableLetters.isNotEmpty) {
        await _loadVideoAt(index.clamp(0, _playableLetters.length - 1));
      }
      return;
    }

    if (!mounted || activeToken != _loadToken) {
      await controller.dispose();
      return;
    }

    await controller.setLooping(false);
    controller.addListener(_handleVideoProgress);

    setState(() {
      _controller = controller;
      _isPreparing = false;
    });

    await controller.play();
  }

  void _handleVideoProgress() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isAdvancing ||
        controller.value.isPlaying) {
      return;
    }

    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration == Duration.zero || position < duration) {
      return;
    }

    _playNext();
  }

  Future<void> _playNext() async {
    if (_currentIndex >= _playableLetters.length - 1) {
      return;
    }

    _isAdvancing = true;
    await _loadVideoAt(_currentIndex + 1);
    _isAdvancing = false;
  }

  Future<void> _playPrevious() async {
    if (_currentIndex == 0) {
      await _replayCurrent();
      return;
    }

    await _loadVideoAt(_currentIndex - 1);
  }

  Future<void> _replayCurrent() async {
    final controller = _controller;
    if (controller == null) {
      if (_playableLetters.isNotEmpty) {
        await _loadVideoAt(0);
      }
      return;
    }

    await controller.seekTo(Duration.zero);
    await controller.play();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _disposeController() {
    final controller = _controller;
    controller?.removeListener(_handleVideoProgress);
    controller?.dispose();
    _controller = null;
  }

  String _assetPathFor(String letter) =>
      '${widget.assetBasePath}/letter_$letter.mp4';

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final primary = Theme.of(context).colorScheme.primary;
    final currentLetter = _playableLetters.isEmpty
        ? null
        : _playableLetters[_currentIndex].toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          if (_letters.isEmpty)
            _EmptyVideoState(
              icon: Icons.record_voice_over_rounded,
              title: 'Waiting for speech',
              message: 'Recognized letters will play here as alphabet videos.',
            )
          else if (_isPreparing && controller == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 44),
              child: CircularProgressIndicator(color: primary),
            )
          else if (_playableLetters.isEmpty)
            _EmptyVideoState(
              icon: Icons.video_library_outlined,
              title: 'Add alphabet videos',
              message:
                  'Place videos at assets/signs/alphabet/letter_a.mp4, letter_b.mp4 and so on.',
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: controller?.value.aspectRatio ?? 16 / 9,
                child: controller != null && controller.value.isInitialized
                    ? VideoPlayer(controller)
                    : ColoredBox(
                        color: const Color(0xffF1F5F9),
                        child: Center(
                          child: CircularProgressIndicator(color: primary),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _IconCircleButton(
                  icon: Icons.skip_previous_rounded,
                  onPressed: _playPrevious,
                ),
                const SizedBox(width: 12),
                _IconCircleButton(
                  icon: controller?.value.isPlaying == true
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  isPrimary: true,
                  onPressed: _togglePlayback,
                ),
                const SizedBox(width: 12),
                _IconCircleButton(
                  icon: Icons.skip_next_rounded,
                  onPressed: _playNext,
                ),
                const SizedBox(width: 12),
                _IconCircleButton(
                  icon: Icons.replay_rounded,
                  onPressed: _replayCurrent,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              currentLetter == null
                  ? 'No playable letters yet'
                  : 'Playing letter $currentLetter',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${_currentIndex + 1} of ${_playableLetters.length} videos',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
          if (_playableLetters.isNotEmpty) ...[
            const SizedBox(height: 16),
            _LetterStrip(
              letters: _playableLetters,
              currentIndex: _currentIndex,
            ),
          ],
          if (_missingLetters.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Missing videos: ${_missingLetters.map((letter) => letter.toUpperCase()).join(', ')}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyVideoState extends StatelessWidget {
  const _EmptyVideoState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return IconButton.filled(
      style: IconButton.styleFrom(
        backgroundColor: isPrimary ? primary : primary.withValues(alpha: .1),
        foregroundColor: isPrimary ? Colors.white : primary,
        fixedSize: Size(isPrimary ? 54 : 46, isPrimary ? 54 : 46),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: icon == Icons.play_arrow_rounded
          ? 'Play'
          : icon == Icons.pause_rounded
          ? 'Pause'
          : icon == Icons.replay_rounded
          ? 'Replay'
          : icon == Icons.skip_next_rounded
          ? 'Next letter'
          : 'Previous letter',
    );
  }
}

class _LetterStrip extends StatelessWidget {
  const _LetterStrip({required this.letters, required this.currentIndex});

  final List<String> letters;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var index = 0; index < letters.length; index++)
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index == currentIndex ? primary : const Color(0xffF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Text(
              letters[index].toUpperCase(),
              style: TextStyle(
                color: index == currentIndex ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
