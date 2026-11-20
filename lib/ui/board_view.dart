import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'board_controller.dart';
import 'board_painter.dart';

/// Tilted 2.5D board: paints via BoardPainter, forwards taps and long-presses.
class BoardView extends StatefulWidget {
  final BoardController controller;

  /// Colourblind-safe arrow outlines (Settings).
  final bool highContrast;
  const BoardView(
      {super.key, required this.controller, this.highContrast = false});

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final BoardArtCache _cache = BoardArtCache();
  int _baseUs = 0;

  BoardController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    c.wake = _wake;
    c.addListener(_onController);
  }

  @override
  void didUpdateWidget(BoardView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onController);
      old.controller.wake = null;
      c.wake = _wake;
      c.addListener(_onController);
    }
  }

  void _onController() => setState(() {});

  void _wake() {
    if (!_ticker.isActive) {
      _baseUs = c.fx.nowUs;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final fx = c.fx;
    fx.nowUs = _baseUs + elapsed.inMicroseconds;
    fx.prune();
    c.frame.value++;
    if (fx.finaleScheduled &&
        !fx.finaleNotified &&
        fx.nowUs >= fx.finaleEndUs) {
      fx.finaleNotified = true;
      c.finaleFinished();
    }
    if (!fx.busy) {
      _ticker.stop();
      _baseUs = fx.nowUs;
    }
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    if (c.wake == _wake) c.wake = null;
    _ticker.dispose();
    super.dispose();
  }

  int _frogAt(Offset local, double width) {
    if (c.fx.finaleScheduled) return -1;
    return BoardLayout(c.board.size, width)
        .hitFrog(local, c.board, c.session.mask);
  }

  @override
  Widget build(BuildContext context) {
    final n = c.board.size;
    return AspectRatio(
      aspectRatio: BoardLayout.aspectRatio(n),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final f = _frogAt(d.localPosition, w);
            if (f >= 0) c.tapFrog(f);
          },
          onLongPressStart: (d) => c.setPreview(_frogAt(d.localPosition, w)),
          onLongPressMoveUpdate: (d) =>
              c.setPreview(_frogAt(d.localPosition, w)),
          onLongPressEnd: (_) => c.setPreview(-1),
          onLongPressCancel: () => c.setPreview(-1),
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(w, box.maxHeight),
              painter: BoardPainter(
                session: c.session,
                fx: c.fx,
                cache: _cache,
                repaint: c.frame,
                highContrast: widget.highContrast,
              ),
            ),
          ),
        );
      }),
    );
  }
}
