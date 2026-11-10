import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Screen layout for every game: [header] at the top, [footer] at the
/// bottom and the [board] as large as the space between them allows.
///
/// The board's own height follows its width ([aspect] = grid width / grid
/// height, plus [chrome], the board's frame), so the layout measures the
/// header and footer first and gives the board the widest size that still
/// fits the visible height. On short screens or with large text the board
/// keeps [minBoardWidth] and the page scrolls instead of overflowing.
class GameLayout extends StatelessWidget {
  const GameLayout({
    super.key,
    required this.header,
    required this.board,
    required this.footer,
    required this.aspect,
    this.chrome = const Size(30, 38),
    this.padding = EdgeInsets.zero,
    this.minBoardWidth = 250,
    this.maxBoardWidth = 560,
    this.gap = 12,
  });

  /// Exact width/height terms of a [Board] holding a fixed-count grid:
  /// height = (width − chrome.width) / aspect + chrome.height.
  static ({double aspect, Size chrome}) grid({
    required int columns,
    required int rows,
    required double tileAspect,
    double spacingX = 9,
    double spacingY = 10,
    Size frame = const Size(30, 38),
  }) => (
    aspect: columns * tileAspect / rows,
    chrome: Size(
      frame.width + (columns - 1) * spacingX,
      frame.height + (rows - 1) * spacingY,
    ),
  );

  final Widget header, board, footer;
  final double aspect, minBoardWidth, maxBoardWidth, gap;
  final Size chrome;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      padding: padding,
      child: _GameColumn(
        viewport: math.max(0, box.maxHeight - padding.vertical),
        aspect: aspect,
        chrome: chrome,
        minBoardWidth: minBoardWidth,
        maxBoardWidth: maxBoardWidth,
        gap: gap,
        children: [header, board, footer],
      ),
    ),
  );
}

class _GameColumn extends MultiChildRenderObjectWidget {
  const _GameColumn({
    required this.viewport,
    required this.aspect,
    required this.chrome,
    required this.minBoardWidth,
    required this.maxBoardWidth,
    required this.gap,
    required super.children,
  });
  final double viewport, aspect, minBoardWidth, maxBoardWidth, gap;
  final Size chrome;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGameColumn()
    ..viewport = viewport
    ..aspect = aspect
    ..chrome = chrome
    ..minBoardWidth = minBoardWidth
    ..maxBoardWidth = maxBoardWidth
    ..gap = gap;

  @override
  void updateRenderObject(BuildContext context, _RenderGameColumn render) =>
      render
        ..viewport = viewport
        ..aspect = aspect
        ..chrome = chrome
        ..minBoardWidth = minBoardWidth
        ..maxBoardWidth = maxBoardWidth
        ..gap = gap;
}

class _Slot extends ContainerBoxParentData<RenderBox> {}

class _RenderGameColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _Slot>,
        RenderBoxContainerDefaultsMixin<RenderBox, _Slot> {
  double _viewport = 0, _aspect = 1, _min = 250, _max = 560, _gap = 12;
  Size _chrome = Size.zero;
  void _set(VoidCallback assign) {
    assign();
    markNeedsLayout();
  }

  set viewport(double v) => v == _viewport ? null : _set(() => _viewport = v);
  set aspect(double v) => v == _aspect ? null : _set(() => _aspect = v);
  set chrome(Size v) => v == _chrome ? null : _set(() => _chrome = v);
  set minBoardWidth(double v) => v == _min ? null : _set(() => _min = v);
  set maxBoardWidth(double v) => v == _max ? null : _set(() => _max = v);
  set gap(double v) => v == _gap ? null : _set(() => _gap = v);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Slot) child.parentData = _Slot();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final header = firstChild!, board = childAfter(header)!;
    final footer = childAfter(board)!;
    final full = BoxConstraints(minWidth: width, maxWidth: width);
    header.layout(full, parentUsesSize: true);
    footer.layout(full, parentUsesSize: true);
    final free = _viewport - header.size.height - footer.size.height - 2 * _gap;
    // Widest board whose height (grid + frame) fits the free height.
    final fit = (free - _chrome.height) * _aspect + _chrome.width;
    final boardWidth = fit
        .clamp(math.min(_min, width), math.min(_max, width))
        .toDouble();
    board.layout(
      BoxConstraints.tightFor(width: boardWidth),
      parentUsesSize: true,
    );
    final content =
        header.size.height + board.size.height + footer.size.height + 2 * _gap;
    final height = math.max(_viewport, content);
    size = constraints.constrain(Size(width, height));
    (header.parentData! as _Slot).offset = Offset.zero;
    (footer.parentData! as _Slot).offset = Offset(
      0,
      size.height - footer.size.height,
    );
    final middle =
        size.height - header.size.height - footer.size.height - 2 * _gap;
    (board.parentData! as _Slot).offset = Offset(
      (width - boardWidth) / 2,
      header.size.height + _gap + math.max(0, (middle - board.size.height) / 2),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
