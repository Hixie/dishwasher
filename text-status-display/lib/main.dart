import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:home_automation_tools/all.dart';

import 'credentials.dart';

class Color {
  const Color._(this.value);
  final int value;

  static const Color black = Color._(30);
  static const Color red = Color._(31);
  static const Color green = Color._(32);
  static const Color yellow = Color._(33);
  static const Color blue = Color._(34);
  static const Color magenta = Color._(35);
  static const Color cyan = Color._(36);
  static const Color white = Color._(37);
  static const Color gray = Color._(90);
  static const Color brightRed = Color._(91);
  static const Color brightGreen = Color._(92);
  static const Color brightYellow = Color._(93);
  static const Color brightBlue = Color._(94);
  static const Color brightMagenta = Color._(95);
  static const Color brightCyan = Color._(96);
  static const Color brightWhite = Color._(97);
}

class Offset {
  const Offset(this.x, this.y);
  final int x;
  final int y;

  Offset operator +(Offset other) {
    return Offset(x + other.x, y + other.y);
  }

  Rect operator &(Size size) {
    return Rect(this, size);
  }
}

class Size {
  const Size(this.width, this.height);
  final int width;
  final int height;
}

class Rect {
  const Rect(this.topLeft, this.size);
  final Offset topLeft;
  final Size size;
  
  int get width => size.width;
  int get height => size.height;

  Rect shift(Offset offset) {
    return topLeft + offset & size;
  }
}

class EdgeInsets {
  const EdgeInsets.fromLTRB(this.left, this.top, this.right, this.bottom);
  final int left;
  final int top;
  final int right;
  final int bottom;

  Rect shrink(Rect rect) {
    return rect.topLeft + Offset(left, top) & Size(rect.width - left - right, rect.height - top - bottom);
  }
}

enum TextAlign { left, right, center }

enum LineStyle { thin, bold, dotted, dottedBold, dashed, dashedBold, double, thickLeading, thickTrailing }

class Screen {
  Screen() {
    ProcessSignal.sigwinch.watch().listen(_updateSize);
    _updateSize();
    _write('$CSI?1049h'); // enable alternative screen buffer
    _write('$CSI?7l$CSI?25l'); // disable autowrap, hide cursor
  }

  View _rootView;

  void updateWidgets(Widget rootWidget) {
    View newRoot = updateChild(null, _rootView, rootWidget);
    if (newRoot != _rootView) {
      _rootView?.dispose();
      _rootView = newRoot;
      if (_rootView != null) {
        scheduleLayout(_rootView);
      } else {
        scheduleFrame();
      }
    }
  }

  View updateChild(View parent, View currentChild, Widget newWidget) {
    if (newWidget == null) {
      currentChild?.dispose();
      if (parent != null)
        scheduleLayout(parent);
      return null;
    }
    if (currentChild == null || currentChild.widget.runtimeType != newWidget.runtimeType) {
      currentChild?.dispose();
      if (parent != null)
        scheduleLayout(parent);
      return newWidget.createView(this)
        ..updateParent(parent)
        ..updateChildren();
    }
    assert(currentChild.parent == parent);
    currentChild.updateWidget(newWidget);
    return currentChild;
  }

  Size get size => Size(_width, _height);
  int _width, _height;

  void _updateSize([ProcessSignal signal]) {
    _width = stdout.terminalColumns;
    _height = stdout.terminalLines;
    if (_rootView != null) {
      scheduleLayout(_rootView);
    } else {
      scheduleFrame();
    }
  }

  bool _updateScheduled = false;
  
  void scheduleFrame() {
    if (!_updateScheduled) {
      _updateScheduled = true;
      scheduleMicrotask(_updateScreen);
    }
  }

  List<View> _dirtyLayouts = <View>[];

  void scheduleLayout(View view) {
    assert(view != null);
    _dirtyLayouts.add(view);
    scheduleFrame();
  }

  Set<View> _dirtyPaints = <View>{};

  void schedulePaint(View view) {
    assert(view != null);
    _dirtyPaints.add(view);
    scheduleFrame();
  }

  void _updateScreen() {
    _rootView?.layout(Offset(0, 0) & size);
    while (_dirtyLayouts.isNotEmpty) {
      _dirtyLayouts.sort(View.depthComparator);
      View next = _dirtyLayouts.removeAt(0);
      next.layout(next.rect);
    }
    for (View view in _dirtyPaints) {
      view.paint();
    }
    _dirtyPaints.clear();
    _updateScheduled = false;
  }

  static const String CSI = '\x1B[';

  void _write(String output) {
    stdout.write(output);
  }

  void _moveTo(Offset offset) {
    _write('$CSI${offset.y + 1};${offset.x + 1}H');
  }

  void _setBackgroundColor(Color color) {
    _write('$CSI${color.value + 10}m');
  }

  void _setForegroundColor(Color color) {
    _write('$CSI${color.value}m');
  }

  void drawText(Offset offset, String message, Color foreground, Color background) {
    _moveTo(offset);
    _setBackgroundColor(background);
    _setForegroundColor(foreground);
    _write(message);
  }

  void fill(Rect rect, String cell, Color foreground, Color background) {
    for (int line = 0; line < rect.height; line += 1) {
      drawText(rect.topLeft + Offset(0, line), cell * rect.width, foreground, background);
    }
  }

  void dispose() {
    _write('$CSI?7h$CSI?25h'); // enable autowrap, show cursor
    _write('$CSI?1049l'); // disable alternative screen buffer
    _rootView?.dispose();
    _rootView = null;
  }
}

abstract class View {
  View(this._widget, this._screen) {
    markNeedsLayout();
  }

  Widget get widget => _widget;
  Widget _widget;
  Screen _screen;

  void updateWidget(Widget widget) {
    assert(_screen != null);
    if (widget == _widget)
      return;
    assert(_widget != null);
    assert(widget.runtimeType == _widget.runtimeType);
    if (!_needsLayout) {
      if (widget.changesLayoutOf(_widget)) {
        markNeedsLayout();
      } else if (widget.changesPaintOf(_widget)) {
        markNeedsPaint();
      }
    }
    _widget = widget;
    updateChildren();
  }

  View get parent => _parent;
  View _parent;

  int get depth => _depth;
  int _depth;

  void updateParent(View newParent) {
    assert(_parent == null);
    _parent = newParent;
    if (parent != null) {
      _depth = parent.depth + 1;
    } else {
      _depth = 0;
    }
  }

  void updateChildren() {
    widget.updateChildren(this, _screen);
  }

  static int depthComparator(View a, View b) {
    assert(a != null);
    assert(b != null);
    if (a._screen == null && b._screen == null)
      return 0;
    if (a._screen == null)
      return 1;
    if (b._screen == null)
      return -1;
    assert(a.depth != null);
    assert(b.depth != null);
    return a.depth - b.depth;
  }

  Iterable<View> get children sync* { }

  bool _needsLayout = true;

  void markNeedsLayout() {
    if (!_needsLayout) {
      _screen.scheduleLayout(this);
    }
  }

  void markNeedsPaint() {
    _screen.schedulePaint(this);
  }
  
  Rect get rect => _rect;
  Rect _rect;

  void layout(Rect rect) {
    if (_screen != null && (_rect != rect || _needsLayout)) {
      _rect = rect;
      updateLayout();
      _needsLayout = false;
      markNeedsPaint();
    }
  }

  void updateLayout() { }

  void paint() {
    if (_screen != null)
      updatePaint(_screen);
  }

  void updatePaint(Screen screen) { }

  void dispose() {
    _screen = null;
    for (View child in children)
      child.dispose();
  }
}

abstract class Widget {
  const Widget();

  View createView(Screen screen);
  // returns MyView(this, screen)

  void updateChildren(covariant View view, Screen screen) { }
  // calls view.child = screen.updateChild(view, view.child, childWidget);

  bool changesLayoutOf(covariant Widget widget) => false;

  bool changesPaintOf(covariant Widget widget) => false;
}

class ParallelFrameView extends View {
  ParallelFrameView(Widget widget, Screen screen) : super(widget, screen);

  ParallelFrame get widget => super.widget;

  View top;
  View bottom;
  View body;

  Iterable<View> get children sync* {
    if (top != null) yield top;
    if (bottom != null) yield bottom;
    if (body != null) yield body;
  }

  void updateLayout() {
    top?.layout(rect.topLeft & Size(rect.width, 1));
    bottom?.layout(rect.topLeft + Offset(0, rect.height - 1) & Size(rect.width, 1));
    body?.layout(rect.topLeft + Offset(0, top != null ? 1 : 0) & Size(rect.width, rect.height - (top != null ? 1 : 0) - (bottom != null ? 1 : 0)));
  }
}

class ParallelFrame extends Widget {
  const ParallelFrame({
    this.top,
    this.bottom,
    this.body,
  });

  final Widget top;
  final Widget bottom;
  final Widget body;

  View createView(Screen screen) => ParallelFrameView(this, screen);

  void updateChildren(ParallelFrameView view, Screen screen) {
    view.top = screen.updateChild(view, view.top, top);
    view.bottom = screen.updateChild(view, view.bottom, bottom);
    view.body = screen.updateChild(view, view.body, body);
  }
}

class BracketFrameView extends View {
  BracketFrameView(Widget widget, Screen screen) : super(widget, screen);

  BracketFrame get widget => super.widget;

  View top;
  View side;
  View bottom;
  View body;

  Iterable<View> get children sync* {
    if (top != null) yield top;
    if (side != null) yield bottom;
    if (bottom != null) yield bottom;
    if (body != null) yield body;
  }

  void updateLayout() {
    top?.layout(rect.topLeft & Size(rect.width, 1));
    bottom?.layout(rect.topLeft + Offset(0, rect.height - 1) & Size(rect.width, 1));
    int bodyHeight = rect.height - (top != null ? 1 : 0) - (bottom != null ? 1 : 0);
    body?.layout(rect.topLeft + Offset(side != null ? widget.margin : 0, top != null ? 1 : 0) & Size(rect.width - (side != null ? widget.margin : 0), bodyHeight));
    side?.layout(rect.topLeft + Offset(0, top != null ? 1 : 0) & Size(widget.margin, bodyHeight));
  }
}

class BracketFrame extends Widget {
  const BracketFrame({
    this.top,
    this.side,
    this.bottom,
    this.body,
    this.margin = 8,
  });

  final Widget top;
  final Widget side;
  final Widget bottom;
  final Widget body;

  final int margin;

  View createView(Screen screen) => ParallelFrameView(this, screen);

  void updateChildren(BracketFrameView view, Screen screen) {
    view.top = screen.updateChild(view, view.top, top);
    view.side = screen.updateChild(view, view.side, side);
    view.bottom = screen.updateChild(view, view.bottom, bottom);
    view.body = screen.updateChild(view, view.body, body);
  }

  bool changesLayoutOf(BracketFrame widget) {
    return widget.margin != margin;
  }
}

class Height<T> {
  Height._(this.child, this.fill, this.lines);
  Height.line(this.child) : fill = false, lines = 1;
  Height.lines(this.lines, this.child) : fill = false;
  Height.fill(this.child) : fill = true, lines = null;
  final T child;
  final bool fill;
  final int lines;
  Height<Q> convert<Q>(Q newChild) => Height<Q>._(newChild, fill, lines);
}

class ColumnView extends View {
  ColumnView(Widget widget, Screen screen) : super(widget, screen);

  Column get widget => super.widget;

  List<Height<View>> _children = const <Height<View>>[];

  Iterable<View> get children => _children.map<View>((Height<View> child) => child.child);

  void updateLayout() {
    int lines = 0;
    int fills = 0;
    for (Height child in _children) {
      switch (child.fill) {
        case false:
          lines += child.lines;
          break;
        case true:
          fills += 1;
          break;
      }
    }
    int fillHeight = fills > 0 ? (rect.height - lines) ~/ fills : null;
    int y = 0;
    for (Height child in _children) {
      if (child == _children.last) {
        child.child.layout(rect.topLeft + Offset(0, y) & Size(rect.width, rect.height - y));
      } else {
        switch (child.fill) {
          case false:
            child.child.layout(rect.topLeft + Offset(0, y) & Size(rect.width, child.lines));
            y += child.lines;
            break;
          case true:
            child.child.layout(rect.topLeft + Offset(0, y) & Size(rect.width, fillHeight));
            y += fillHeight;
            break;
        }
      }
    }
  }
}

class Column extends Widget {
  const Column({
    this.children = const <Height<Widget>>[],
  });

  final List<Height<Widget>> children;

  View createView(Screen screen) => ColumnView(this, screen);

  void updateChildren(ColumnView view, Screen screen) {
    int count = math.max(children.length, view._children.length);
    List<Height<View>> newChildren = List<Height<View>>(children.length);
    for (int index = 0; index < count; index += 1) {
      View childView = index < view._children.length ? view._children[index].child : null;
      Widget childWidget = index < children.length ? children[index].child : null;
      View newChild = screen.updateChild(view, childView, childWidget);
      if (newChild != null)
        newChildren[index] = children[index].convert(newChild);
    }
    view._children = newChildren;
  }

  bool changesLayoutOf(Column widget) {
    if (widget.children.length != children.length)
      return true;
    for (int index = 0; index < children.length; index += 1) {
      if (widget.children[index].lines != children[index].lines ||
          widget.children[index].fill != children[index].fill)
        return true;
    }
    return false;
  }
}

class Width<T> {
  Width._(this.child, this.fill, this.columns);
  Width.fixed(this.columns, this.child) : fill = false;
  Width.fill(this.child) : fill = true, columns = null;
  final T child;
  final bool fill;
  final int columns;
  Width<Q> convert<Q>(Q newChild) => Width<Q>._(newChild, fill, columns);
}

class RowView extends View {
  RowView(Widget widget, Screen screen) : super(widget, screen);

  Row get widget => super.widget;

  List<Width<View>> _children = const <Width<View>>[];

  Iterable<View> get children => _children.map<View>((Width<View> child) => child.child);

  void updateLayout() {
    int columns = 0;
    int fills = 0;
    for (Width<View> child in _children) {
      switch (child.fill) {
        case false:
          columns += child.columns;
          break;
        case true:
          fills += 1;
          break;
      }
    }
    int fillWidth = fills > 0 ? (rect.width - columns) ~/ fills : null;
    int x = 0;
    for (Width<View> child in _children) {
      if (child == _children.last) {
        child.child.layout(rect.topLeft + Offset(x, 0) & Size(rect.width - x, rect.height));
      } else {
        switch (child.fill) {
          case false:
            child.child.layout(rect.topLeft + Offset(x, 0) & Size(child.columns, rect.height));
            x += child.columns;
            break;
          case true:
            child.child.layout(rect.topLeft + Offset(x, 0) & Size(fillWidth, rect.height));
            x += fillWidth;
            break;
        }
      }
    }
  }
}

class Row extends Widget {
  const Row({
    this.children = const <Width<Widget>>[],
  });

  final List<Width<Widget>> children;

  View createView(Screen screen) => RowView(this, screen);

  void updateChildren(RowView view, Screen screen) {
    int count = math.max(children.length, view._children.length);
    List<Width<View>> newChildren = List<Width<View>>(children.length);
    for (int index = 0; index < count; index += 1) {
      View childView = index < view._children.length ? view._children[index].child : null;
      Widget childWidget = index < children.length ? children[index].child : null;
      View newChild = screen.updateChild(view, childView, childWidget);
      if (newChild != null)
        newChildren[index] = children[index].convert(newChild);
    }
    view._children = newChildren;
  }

  bool changesLayoutOf(Row widget) {
    if (widget.children.length != children.length)
      return true;
    for (int index = 0; index < children.length; index += 1) {
      if (widget.children[index].columns != children[index].columns ||
          widget.children[index].fill != children[index].fill)
        return true;
    }
    return false;
  }
}

class HeaderView extends View {
  HeaderView(Widget widget, Screen screen) : super(widget, screen);

  Header get widget => super.widget;

  String _text;
  int leftWidth, rightWidth;

  void updateLayout() {
    if (widget.text.length > rect.width - 6) {
      _text = ' ' + widget.text.substring(0, rect.width - 6) + ' ';
    } else {
      _text = ' ${widget.text} ';
    }
    rightWidth = 2;
    leftWidth = rect.width - rightWidth - _text.length;
  }

  void updatePaint(Screen screen) {
    screen.fill(rect.topLeft & Size(leftWidth, 1), ' ', widget.foreground, widget.background);
    screen.fill(rect.topLeft + Offset(rect.width - rightWidth, 0) & Size(rightWidth, 1), ' ', widget.foreground, widget.background);
    screen.drawText(rect.topLeft + Offset(leftWidth, 0), _text, widget.background, widget.foreground);
  }
}

class Header extends Widget {
  const Header({
    this.text = '',
    this.foreground = Color.white,
    this.background = Color.black,
  });

  final String text;
  final Color foreground;
  final Color background;

  View createView(Screen screen) => HeaderView(this, screen);

  bool changesLayoutOf(Header widget) {
    return widget.text != text;
  }

  bool changesPaintOf(Header widget) {
    return widget.foreground != foreground
        || widget.background != background;
  }
}

class LabelView extends View {
  LabelView(Widget widget, Screen screen) : super(widget, screen);

  Label get widget => super.widget;

  String _text;

  void updateLayout() {
    if (widget.text.length + widget.padding.left + widget.padding.right > rect.width) {
      switch (widget.textAlign) {
        case TextAlign.center:
        case TextAlign.left:
          _text = '${" " * widget.padding.left}${widget.text.substring(0, rect.width - widget.padding.left - widget.padding.right)}${" " * widget.padding.right}';
          break;
        case TextAlign.right:
          _text = '${" " * widget.padding.left}${widget.text.substring(widget.text.length - rect.width - widget.padding.left - widget.padding.right, widget.text.length)}${" " * widget.padding.right}';
          break;
      }
    } else {
      switch (widget.textAlign) {
        case TextAlign.left:
          _text = '${" " * widget.padding.left}${widget.text.padRight(rect.width - widget.padding.left - widget.padding.right, ' ')}${" " * widget.padding.right}';
          break;
        case TextAlign.right:
          _text = '${" " * widget.padding.left}${widget.text.padLeft(rect.width - widget.padding.left - widget.padding.right, ' ')}${" " * widget.padding.right}';
          break;
        case TextAlign.center:
          int total = rect.width - widget.padding.left - widget.padding.right - widget.text.length;
          int left = total ~/ 2;
          int right = total - left;
          _text = '${" " * (widget.padding.left + left)}${widget.text}${" " * (widget.padding.right + right)}';
          break;
      }
    }
  }

  void updatePaint(Screen screen) {
    if (widget.padding.top > 0)
      screen.fill(rect.topLeft & Size(rect.width, widget.padding.top), ' ', widget.foreground, widget.background);
    screen.drawText(rect.topLeft + Offset(0, widget.padding.top), _text, widget.background, widget.foreground);
    if (rect.height > widget.padding.top + 1 + widget.padding.bottom)
      screen.fill(rect.topLeft + Offset(0, widget.padding.top + 1) & Size(rect.width, rect.height - 1 - widget.padding.top - widget.padding.bottom), ' ', widget.foreground, widget.background);
    if (widget.padding.bottom > 0)
      screen.fill(rect.topLeft + Offset(0, widget.padding.top + rect.height) & Size(rect.width, widget.padding.bottom), ' ', widget.foreground, widget.background);
  }
}

class Label extends Widget {
  const Label({
    this.text = '',
    this.padding = const EdgeInsets.fromLTRB(0, 0, 0, 0),
    this.textAlign = TextAlign.left,
    this.foreground = Color.white,
    this.background = Color.black,
  });

  factory Label.strip({
    List<String> texts = const <String>[],
    EdgeInsets padding = const EdgeInsets.fromLTRB(0, 0, 0, 0),
    TextAlign textAlign = TextAlign.left,
    Color background = Color.white,
    Color foreground = Color.black,
    LineStyle style = LineStyle.thin,
  }) {
    String line;
    switch (style) {
      case LineStyle.thin: line = '\u2502'; break;
      case LineStyle.bold: line = '\u2503'; break;
      case LineStyle.dotted: line = '\u250A'; break;
      case LineStyle.dottedBold: line = '\u250B'; break;
      case LineStyle.dashed: line = '\u2506'; break;
      case LineStyle.dashedBold: line = '\u2507'; break;
      case LineStyle.double: line = '\u2551'; break;
      case LineStyle.thickLeading: line = '\u258C'; break;
      case LineStyle.thickTrailing: line = '\u2590'; break;
    }
    return Label(
      text: texts.join('${" " * padding.right}$line${" " * padding.left}'),
      padding: padding,
      textAlign: textAlign,
      background: background,
      foreground: foreground,
    );
  }

  final String text;
  final EdgeInsets padding;
  final TextAlign textAlign;
  final Color background;
  final Color foreground;

  View createView(Screen screen) => LabelView(this, screen);

  bool changesLayoutOf(Label widget) {
    return widget.text != text
        || widget.padding != padding
        || widget.textAlign != textAlign;
  }

  bool changesPaintOf(Label widget) {
    return widget.foreground != foreground
        || widget.background != background;
  }
}

class BigLabelView extends View {
  BigLabelView(Widget widget, Screen screen) : super(widget, screen);

  BigLabel get widget => super.widget;

  static const Map<int, int> _font = <int, int>{
    0x00020: 0x0000, // SPACE
    0x00022: 0x0055, // "
    0x00027: 0x0022, // '
    0x00028: 0x0626, // (
    0x00029: 0x0323, // )
    0x0002B: 0x0272, // +
    0x0002C: 0x0320, // ,
    0x0002D: 0x0070, // -
    0x0002E: 0x0330, // . (if it's too big, try 0x0100)
    0x0002F: 0x0124, // /
    0x00030: 0x0252, // 0
    0x00031: 0x0723, // 1
    0x00032: 0x0623, // 2
    0x00033: 0x0767, // 3
    0x00034: 0x0475, // 4
    0x00035: 0x0326, // 5
    0x00036: 0x0771, // 6
    0x00037: 0x0447, // 7
    0x00038: 0x0776, // 8
    0x00039: 0x0477, // 9
    0x0003A: 0x0101, // :
    0x0003C: 0x0424, // <
    0x0003D: 0x0707, // =
    0x0003E: 0x0121, // >
    0x0003F: 0x0246, // ?
    0x00041: 0x0577, // A
    0x00042: 0x0373, // B
    0x00043: 0x0717, // C
    0x00044: 0x0353, // D
    0x00045: 0x0737, // E
    0x00046: 0x0137, // F
    0x00047: 0x0753, // G
    0x00048: 0x0575, // H
    0x00049: 0x0727, // I
    0x0004A: 0x0754, // J
    0x0004B: 0x0535, // K
    0x0004C: 0x0711, // L
    0x0004D: 0x0577, // M
    0x0004E: 0x0557, // N
    0x0004F: 0x0757, // O
    0x00050: 0x0177, // P
    0x00051: 0x0477, // Q
    0x00052: 0x0537, // R
    0x00053: 0x0326, // S
    0x00054: 0x0227, // T
    0x00055: 0x0755, // U
    0x00056: 0x0255, // V
    0x00057: 0x0775, // W
    0x00058: 0x0525, // X
    0x00059: 0x0225, // Y
    0x0005A: 0x0623, // Z
    0x0005B: 0x0717, // [
    0x0005C: 0x0421, // \
    0x0005D: 0x0747, // ]
    0x0005E: 0x0052, // ^
    0x0005F: 0x0700, // _
    0x00061: 0x0577, // a
    0x00062: 0x0373, // b
    0x00063: 0x0717, // c
    0x00064: 0x0353, // d
    0x00065: 0x0737, // e
    0x00066: 0x0137, // f
    0x00067: 0x0753, // g
    0x00068: 0x0575, // h
    0x00069: 0x0727, // i
    0x0006A: 0x0754, // j
    0x0006B: 0x0535, // k
    0x0006C: 0x0711, // l
    0x0006D: 0x0577, // m
    0x0006E: 0x0557, // n
    0x0006F: 0x0757, // o
    0x00070: 0x0177, // p
    0x00071: 0x0477, // q
    0x00072: 0x0537, // r
    0x00073: 0x0326, // s
    0x00074: 0x0227, // t
    0x00075: 0x0755, // u
    0x00076: 0x0255, // v
    0x00077: 0x0775, // w
    0x00078: 0x0525, // x
    0x00079: 0x0225, // y
    0x0007A: 0x0623, // z
    0x0007B: 0x0636, // {
    0x0007C: 0x0222, // |
    0x0007D: 0x0363, // }
    0x000B7: 0x0020, // MIDDLE DOT
    0x02588: 0x0777, // FULL BLOCK
    0x0263A: 0x0705, // WHITE SMILING FACE
    0x02665: 0x0277, // BLACK HEART SUIT
    0x0FFFD: 0x0246, // REPLACEMENT CHARACTER
    0x1F404: 0x0661, // COW
    0x1F431: 0x0725, // CAT FACE
  };

  static const String _pixelOn = '\u2588\u2588';
  static const String _pixelOff = '  ';

  static const List<String> _scanLines = <String>[
    '$_pixelOff$_pixelOff$_pixelOff ',
    '$_pixelOn$_pixelOff$_pixelOff ',
    '$_pixelOff$_pixelOn$_pixelOff ',
    '$_pixelOn$_pixelOn$_pixelOff ',
    '$_pixelOff$_pixelOff$_pixelOn ',
    '$_pixelOn$_pixelOff$_pixelOn ',
    '$_pixelOff$_pixelOn$_pixelOn ',
    '$_pixelOn$_pixelOn$_pixelOn ',
  ];

  String _toMatrix(int scanLine) => _scanLines[scanLine];

  String _trimToSize(String line) {
    if (line.length > rect.width)
      return line.substring(0, rect.width);
    return line.padRight(rect.width, ' ');
  }

  List<String> _lines;

  void updateLayout() {
    List<StringBuffer> lines = <StringBuffer>[StringBuffer(), StringBuffer(), StringBuffer()];
    for (int c in widget.text.runes) {
      int bitmap = _font[c] ?? _font[0xFFFD];
      lines[0].write(_toMatrix(bitmap & 0x00F));
      lines[1].write(_toMatrix(bitmap >> 4 & 0x00F));
      lines[2].write(_toMatrix(bitmap >> 8 & 0x00F));
    }
    _lines = lines.map<String>((StringBuffer buffer) => _trimToSize(buffer.toString())).toList();
  }

  void updatePaint(Screen screen) {
    for (int index = 0; index < rect.height; index += 1) {
      if (index < _lines.length) {
        screen.drawText(rect.topLeft + Offset(0, index), _lines[index], widget.foreground, widget.background);
      } else {
        screen.fill(rect.topLeft + Offset(0, index) & Size(rect.width, 1), ' ', widget.foreground, widget.background);
      }
    }
  }
}

class BigLabel extends Widget {
  const BigLabel({
    this.text = '',
    this.foreground = Color.white,
    this.background = Color.black,
  });

  final String text;
  final Color background;
  final Color foreground;

  View createView(Screen screen) => BigLabelView(this, screen);

  bool changesLayoutOf(BigLabel widget) {
    return widget.text != text;
  }

  bool changesPaintOf(BigLabel widget) {
    return widget.foreground != foreground
        || widget.background != background;
  }
}

class HorizontalLineView extends View {
  HorizontalLineView(Widget widget, Screen screen) : super(widget, screen);

  HorizontalLine get widget => super.widget;

  Rect _above;
  Rect _line;
  Rect _below;

  void updateLayout() {
    if (rect.height > 1) {
      _above = rect.topLeft & Size(rect.width, ((rect.height - 1) / 2).ceil());
    } else {
      _above = null;
    }
    _line = rect.topLeft + Offset(0, rect.height ~/ 2) & Size(rect.width, 1);
    if (rect.height > 2) {
      _below = _line.topLeft + Offset(0, 1) & Size(rect.width, (rect.height - 1) ~/ 2);
    } else {
      _below = null;
    }
  }

  String get _character {
    switch (widget.style) {
      case LineStyle.thin: return '\u2500';
      case LineStyle.bold: return '\u2501';
      case LineStyle.dotted: return '\u2508';
      case LineStyle.dottedBold: return '\u2509';
      case LineStyle.dashed: return '\u2504';
      case LineStyle.dashedBold: return '\u2505';
      case LineStyle.double: return '\u2550';
      case LineStyle.thickLeading: return '\u2580';
      case LineStyle.thickTrailing: return '\u2584';
    }
    return 'F';
  }

  void paintUpdate(Screen screen) {
    if (_above != null)
      screen.fill(_above, ' ', widget.foreground, widget.background);
    screen.fill(_line, _character, widget.foreground, widget.background);
    if (_below != null)
      screen.fill(_below, ' ', widget.foreground, widget.background);
  }
}

class HorizontalLine extends Widget {
  const HorizontalLine({
    this.foreground = Color.white,
    this.background = Color.black,
    this.style = LineStyle.thin,
  });

  final Color background;
  final Color foreground;
  final LineStyle style;

  View createView(Screen screen) => HorizontalLineView(this, screen);

  bool changesPaintOf(HorizontalLine widget) {
    return widget.foreground != foreground
        || widget.background != background
        || widget.style != style;
  }
}

class VerticalLineView extends View {
  VerticalLineView(Widget widget, Screen screen) : super(widget, screen);

  VerticalLine get widget => super.widget;

  Rect _left;
  Rect _line;
  Rect _right;

  void updateLayout() {
    if (rect.width > 1) {
      _left = rect.topLeft & Size(((rect.width - 1) / 2).ceil(), rect.height);
    } else {
      _left = null;
    }
    _line = rect.topLeft + Offset(rect.width ~/ 2, 0) & Size(1, rect.height);
    if (rect.width > 2) {
      _right = _line.topLeft + Offset(1, 0) & Size((rect.width - 1) ~/ 2, rect.height);
    } else {
      _right = null;
    }
  }

  String get _character {
    switch (widget.style) {
      case LineStyle.thin: return '\u2502';
      case LineStyle.bold: return '\u2503';
      case LineStyle.dotted: return '\u250A';
      case LineStyle.dottedBold: return '\u250B';
      case LineStyle.dashed: return '\u2506';
      case LineStyle.dashedBold: return '\u2507';
      case LineStyle.double: return '\u2551';
      case LineStyle.thickLeading: return '\u258C';
      case LineStyle.thickTrailing: return '\u2590';
    }
    return 'F';
  }

  void paintUpdate(Screen screen) {
    if (_left != null)
      screen.fill(_left, ' ', widget.foreground, widget.background);
    screen.fill(_line, _character, widget.foreground, widget.background);
    if (_right != null)
      screen.fill(_right, ' ', widget.foreground, widget.background);
  }
}

class VerticalLine extends Widget {
  const VerticalLine({
    this.foreground = Color.white,
    this.background = Color.black,
    this.style = LineStyle.thin,
  });

  final Color background;
  final Color foreground;
  final LineStyle style;

  View createView(Screen screen) => VerticalLineView(this, screen);

  bool changesPaintOf(VerticalLine widget) {
    return widget.foreground != foreground
        || widget.background != background
        || widget.style != style;
  }
}

class ProgressBarView extends View {
  ProgressBarView(Widget widget, Screen screen) : super(widget, screen);

  ProgressBar get widget => super.widget;

  Rect _left;
  Rect _right;

  void updateLayout() {
    int leftProgress = (rect.width * widget.value).floor();
    _left = rect.topLeft & Size(leftProgress, rect.height);
    _right = rect.topLeft + Offset(leftProgress, 0) & Size(rect.width - leftProgress, rect.height);
  }

  void updatePaint(Screen screen) {
    screen.fill(_left, '\u2588', widget.foreground, widget.background);
    screen.fill(_right, '\u2591', widget.foreground, widget.background);
  }
}

class ProgressBar extends Widget {
  const ProgressBar({
    this.value = 0.0,
    this.foreground = Color.white,
    this.background = Color.black,
  });

  final double value;
  final Color background;
  final Color foreground;

  View createView(Screen screen) => ProgressBarView(this, screen);

  bool changesLayoutOf(ProgressBar widget) {
    return widget.value != value;
  }

  bool changesPaintOf(ProgressBar widget) {
    return widget.foreground != foreground
        || widget.background != background;
  }
}

class PaddingView extends View {
  PaddingView(Widget widget, Screen screen) : super(widget, screen);

  Padding get widget => super.widget;

  View child;

  Iterable<View> get children sync* {
    if (child != null)
      yield child;
  }

  void updateLayout() {
    child?.layout(widget.padding.shrink(rect));
  }

  void updatePaint(Screen screen) {
    if (child == null) {
      screen.fill(rect, ' ', widget.fill, widget.fill);
      return;
    }
    if (widget.padding.top > 0)
      screen.fill(rect.topLeft & Size(rect.width, widget.padding.top), ' ', widget.fill, widget.fill);
    if (widget.padding.left > 0)
      screen.fill(rect.topLeft + Offset(0, widget.padding.top) & Size(widget.padding.left, rect.height - widget.padding.top - widget.padding.bottom), ' ', widget.fill, widget.fill);
    if (widget.padding.right > 0)
      screen.fill(rect.topLeft + Offset(rect.width - widget.padding.right, widget.padding.top) & Size(widget.padding.right, rect.height - widget.padding.top - widget.padding.bottom), ' ', widget.fill, widget.fill);
    if (widget.padding.bottom > 0)
      screen.fill(rect.topLeft + Offset(0, rect.height - widget.padding.bottom) & Size(rect.width, widget.padding.bottom), ' ', widget.fill, widget.fill);
  }
}

class Padding extends Widget {
  const Padding({
    this.padding = const EdgeInsets.fromLTRB(2, 1, 2, 1),
    this.fill = Color.black,
    this.child,
  });

  final EdgeInsets padding;
  final Color fill;
  final Widget child;

  View createView(Screen screen) => PaddingView(this, screen);

  void updateChildren(PaddingView view, Screen screen) {
    view.child = screen.updateChild(view, view.child, child);
  }

  bool changesLayoutOf(Padding widget) {
    return widget.padding != padding;
  }

  bool changesPaintOf(Padding widget) {
    return widget.fill != fill;
  }
}

class FillView extends View {
  FillView(Widget widget, Screen screen) : super(widget, screen);

  Fill get widget => super.widget;

  void updatePaint(Screen screen) {
    screen.fill(rect, ' ', widget.color, widget.color);
  }
}

class Fill extends Widget {
  const Fill({
    this.color = Color.black,
  });

  final Color color;

  View createView(Screen screen) => FillView(this, screen);

  bool changesPaintOf(Fill widget) {
    return widget.color != color;
  }
}

class GaugeView extends View {
  GaugeView(Widget widget, Screen screen) : super(widget, screen);

  Gauge get widget => super.widget;

  Rect _titleRect;
  Rect _lowRect;
  Rect _highRect;
  Rect _gaugeRect;
  Rect _leftFillRect;
  Rect _rightFillRect;

  static const int titleWidth = 6;
  static const int labelWidth = 7;

  void updateLayout() {
    _titleRect = rect.topLeft & Size(titleWidth, 1);
    _lowRect = rect.topLeft + Offset(_titleRect.width, 0) & Size(labelWidth, 1);
    _highRect = rect.topLeft + Offset(rect.width - labelWidth, 0) & Size(7, 1);
    _gaugeRect = rect.topLeft + Offset(_titleRect.width + _lowRect.width, 0) & Size(rect.width - _titleRect.width - _lowRect.width - _highRect.width, rect.height);
    if (rect.height > 1) {
      _leftFillRect = rect.topLeft + Offset(0, 1) & Size(_titleRect.width + _lowRect.width, rect.height - 1);
      _rightFillRect = _gaugeRect.topLeft + Offset(_gaugeRect.width, 1) & Size(_highRect.width, rect.height - 1);
    } else {
      _leftFillRect = null;
      _rightFillRect = null;
    }
  }

  String _shapeString(String prefix, String line, String suffix, int width, TextAlign textAlign) {
    int margin = prefix.length + suffix.length;
    if (line.length > width - margin)
      return prefix + line.substring(0, width - margin) + suffix;
    switch (textAlign) {
      case TextAlign.left:
        return prefix + line.padRight(width - margin, ' ') + suffix;
      case TextAlign.right:
        return prefix + line.padLeft(width - margin, ' ') + suffix;
      case TextAlign.center:
        int total = width - margin;
        return prefix + line.padLeft(total ~/ 2, ' ').padRight(total, ' ') + suffix;
    }
    return '';
  }

  String get _lowString => widget.low == null ? '' : widget.low.toStringAsFixed(1);
  String get _highString => widget.high == null ? '' : widget.high.toStringAsFixed(1);

  void updatePaint(Screen screen) {
    screen.drawText(_titleRect.topLeft, _shapeString('', widget.title, ' ', _titleRect.width, TextAlign.left), widget.foreground, widget.background);
    screen.drawText(_lowRect.topLeft, _shapeString('', _lowString, ' ', _lowRect.width, TextAlign.right), widget.foreground, widget.background);
    screen.drawText(_highRect.topLeft, _shapeString(' ', _highString, '', _highRect.width, TextAlign.right), widget.foreground, widget.background);
    if (_leftFillRect != null)
      screen.fill(_leftFillRect, ' ', widget.foreground, widget.background);
    if (_rightFillRect != null)
      screen.fill(_rightFillRect, ' ', widget.foreground, widget.background);
    double range = widget.maximum - widget.minimum;
    if (widget.low != null && widget.high != null) {
      double lowInRange = widget.low - widget.minimum;
      double highInRange = widget.maximum - widget.high;
      int lowWidth = (_gaugeRect.width * lowInRange / range).floor();
      int highWidth = (_gaugeRect.width * highInRange / range).floor();
      if (lowWidth + highWidth >= _gaugeRect.width)
        highWidth = _gaugeRect.width - lowWidth - 1;
      int innerWidth = _gaugeRect.width - lowWidth - highWidth;
      screen.fill(_gaugeRect.topLeft & Size(lowWidth, rect.height), '\u2591', widget.outerColor, widget.background);
      screen.fill(_gaugeRect.topLeft + Offset(lowWidth, 0) & Size(innerWidth, rect.height), '\u2588', widget.innerColor, widget.background);
      screen.fill(_gaugeRect.topLeft + Offset(lowWidth + innerWidth, 0) & Size(highWidth, rect.height), '\u2591', widget.outerColor, widget.background);
    } else {
      screen.fill(_gaugeRect, '\u2591', widget.outerColor, widget.background);
    }
  }
}

class Gauge extends Widget {
  const Gauge({
    this.title = '',
    this.minimum = 0.0,
    this.maximum = 100.0,
    this.low = 0.0,
    this.high = 0.0,
    this.foreground = Color.white,
    this.background = Color.black,
    this.outerColor = Color.blue,
    this.innerColor = Color.cyan,
  });

  final String title;
  final double minimum;
  final double maximum;
  final double low;
  final double high;
  final Color foreground;
  final Color background;
  final Color outerColor;
  final Color innerColor;

  View createView(Screen screen) => GaugeView(this, screen);

  bool changesPaintOf(Gauge widget) {
    return widget.title != title
        || widget.minimum != minimum
        || widget.maximum != maximum
        || widget.low != low
        || widget.high != high
        || widget.foreground != foreground
        || widget.background != background
        || widget.outerColor != outerColor
        || widget.innerColor != innerColor;
  }
}


enum DishwasherMode { dirty, abort, active, clean, unknown }

Status status = Status.none;
DishwasherMode mode = DishwasherMode.unknown;
int buttons = 0x00;
bool leaking = true;
int clock = 0;

enum SelectedHeading { leaking, some, empty, error, pause, delay, progress, start, clean, abort, dirty, fault }

void updateUi(Screen screen) {
  SelectedHeading label;
  if (leaking) {
    label = SelectedHeading.leaking;
  } else if (buttons == 0x01) {
    label = SelectedHeading.some;
  } else if (buttons == 0x02) {
    label = SelectedHeading.empty;
  } else if (buttons == 0x03) {
    label = SelectedHeading.error;
  } else if (status.paused) {
    label = SelectedHeading.pause;
  } else if (status.delayed) {
    label = SelectedHeading.delay;
  } else if (status.operatingMode == DishwasherOperatingMode.active) {
    label = SelectedHeading.progress;
  } else if (mode == DishwasherMode.active) {
    label = SelectedHeading.start;
  } else if (mode == DishwasherMode.clean) {
    label = SelectedHeading.clean;
  } else if (mode == DishwasherMode.abort) {
    label = SelectedHeading.abort;
  } else if (mode == DishwasherMode.dirty) {
    label = SelectedHeading.dirty;
  } else {
    label = SelectedHeading.fault;
  }
  screen.updateWidgets(
    ParallelFrame(
      top: Header(
        text: 'DISHWASHER',
        foreground: Color.black,
        background: Color.yellow,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(2, 1, 2, 1),
        fill: Color.black,
        child: Column(
          children: <Height<Widget>>[
            if (label == SelectedHeading.leaking)
              Height.lines(3, Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                fill: Color.black,
                child: BigLabel(
                  text: clock % 2 == 0 ? 'LEAK ' : ' LEAK',
                  foreground: Color.white,
                  background: Color.black,
                ),
              )),
            if (label == SelectedHeading.some)
              Height.lines(3, Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                fill: Color.black,
                child: BigLabel(
                  text: 'SOME',
                  foreground: Color.cyan,
                  background: Color.black,
                ),
              )),
            if (label == SelectedHeading.empty)
              Height.lines(3, Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                fill: Color.black,
                child: BigLabel(
                  text: 'EMPTY',
                  foreground: Color.cyan,
                  background: Color.black,
                ),
              )),
            if (label == SelectedHeading.error)
              Height.lines(3, Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                fill: Color.black,
                child: BigLabel(
                  text: 'ERROR',
                  foreground: Color.cyan,
                  background: Color.black,
                ),
              )),
            if (label == SelectedHeading.start)
              Height.lines(3, Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                fill: Color.black,
                child: BigLabel(
                  text: 'START',
                  foreground: Color.red,
                  background: Color.black,
                ),
              )),
            if (label == SelectedHeading.clean)
              Height.lines(3, Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                fill: Color.black,
                child: BigLabel(
                  text: 'CLEAN',
                  foreground: Color.green,
                  background: Color.black,
                ),
              )),
            if (label == SelectedHeading.abort)
              Height.lines(3, Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                fill: Color.black,
                child: BigLabel(
                  text: 'ABORT',
                  foreground: Color.red,
                  background: Color.black,
                ),
              )),
            if (label == SelectedHeading.dirty)
              Height.lines(3, Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                fill: Color.black,
                child: BigLabel(
                  text: 'DIRTY',
                  foreground: Color.red,
                  background: Color.black,
                ),
              )),
            if (label == SelectedHeading.fault)
              Height.lines(3, Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                fill: Color.black,
                child: BigLabel(
                  text: 'FAULT',
                  foreground: Color.magenta,
                  background: Color.black,
                ),
              )),
            if (label == SelectedHeading.pause)
              Height.lines(3, Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                fill: Color.black,
                child: BigLabel(
                  text: 'PAUSE',
                  foreground: clock % 2 == 0 ? Color.blue : Color.cyan,
                  background: Color.black,
                ),
              )),
            if (label == SelectedHeading.delay)
              Height.lines(3, Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                fill: Color.black,
                child: BigLabel(
                  text: 'DELAY',
                  foreground: Color.red,
                  background: Color.black,
                ),
              )),
            if (label == SelectedHeading.progress)
              Height.lines(2, ProgressBar(
                value: status.progress,
                foreground: Color.red,
                background: Color.black,
              )),
            if (label == SelectedHeading.progress)
              Height.line(Row(
                children: <Width<Widget>>[
                  Width.fill(Label(
                    text: status.activeCycleDescription,
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                    textAlign: TextAlign.left,
                    foreground: Color.black,
                    background: Color.yellow,
                  )),
                  if (status.duration != null)
                    Width.fixed(7, Label(
                      text: '${status.durationDescription}', // '${(status.progress * 100).toStringAsFixed(1)}%',
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                      textAlign: TextAlign.right,
                      foreground: Color.black,
                      background: Color.yellow,
                    )),
                ],
              )),
            Height.line(Fill(color: Color.black)),
            Height.line(Gauge(
              title: 'TEMP:',
              minimum: 0.0,
              low: status.minimumTeperature,
              high: status.maximumTemperature,
              maximum: 100.0,
              foreground: Color.yellow,
              background: Color.black,
              innerColor: Color.cyan,
              outerColor: Color.blue,
            )),
            Height.line(Gauge(
              title: 'TURB:',
              minimum: 0.0,
              low: status.minimumTurbidity,
              high: status.maximumTurbidity,
              maximum: 4000.0,
              foreground: Color.yellow,
              background: Color.black,
              innerColor: Color.cyan,
              outerColor: Color.blue,
            )),
            Height.line(Label(
              text: <String>[
                status.idleCycleDescription,
                status.washTemperatureDescription,
                if (!status.rinseAidEnabled)
                  'RINSE AID OFF',
                if (status.steam)
                  'STEAM',
                if (status.heatedDry)
                  'HEAT DRY',
                if (status.muted)
                  'MUTE',
                if (status.uiLocked)
                  'LOCK',
                if (status.sabbathMode)
                  'SABBATH',
                if (status.demoMode)
                  'DEMO',
              ].where((String value) => value.isNotEmpty).join('  '),
              textAlign: TextAlign.left,
              foreground: Color.black,
              background: Color.yellow,
            )),
            Height.fill(Fill(color: Color.black)),
          ],
        ),
      ),
      bottom: Label.strip(
        texts: <String>[
          if (status.powerOnCount != null)
            '${status.powerOnCount} ON',
          if (status.doorCount != null)
            '${status.doorCount} DOOR',
          if (status.cyclesStarted != null && status.cyclesCompleted != null)
            '${status.cyclesCompleted}/${status.cyclesStarted} CYCLES',
        ],
        padding: const EdgeInsets.fromLTRB(1, 0, 1, 0),
        textAlign: TextAlign.center,
        foreground: Color.yellow,
        background: Color.black,
        style: LineStyle.thin,
      ),
    ),
  );
}


final Completer<void> terminate = Completer<void>();

void signalEnd([Object value]) {
  if (!terminate.isCompleted) {
    terminate.complete();
  }
}

Set<String> alerting = <String>{};
Timer alertReset;

void reportLeak(RemyMultiplexer remy, bool leaking, String sensor) {
  if (leaking) {
    remy.pushButtonById('leakSensor${sensor}DetectingLeak');
    if (!alerting.contains(sensor)) {
      alertReset?.cancel();
      alertReset = Timer(const Duration(seconds: 15), () {
        alertReset = null;
        for (String sensor in alerting) {
          remy.pushButtonById('leakSensor${sensor}Idle');
        }
        alerting.clear();
      });
    }
    alerting.add(sensor);
  } else {
    remy.pushButtonById('leakSensor${sensor}Idle');
    alerting.remove(sensor);
  }
}

void main(List<String> arguments) async {
  bool ui = true;
  if (arguments.isNotEmpty && arguments.contains('--debug'))
    ui = false;
  Screen screen;
  runZoned(() async {
    Credentials credentials = Credentials('credentials.cfg');
    SecurityContext securityContext = SecurityContext()..setTrustedCertificatesBytes(File(credentials.certificatePath).readAsBytesSync());
    DatabaseStreamingClient database = DatabaseStreamingClient(
      credentials.databaseHost,
      credentials.databasePort,
      securityContext,
      0x02,
      28,
    );
    RemyMultiplexer remy = RemyMultiplexer(
      credentials.remyUsername,
      credentials.remyPassword,
      securityContext: securityContext,
      onLog: (String message) {
        if (!ui)
          print('remy: $message');
      },
    );
    remy.getStreamForNotificationWithArgument('automatic-dishwasher-display').listen((String newMode) {
      switch (newMode) {
        case 'clean':
          mode = DishwasherMode.clean;
          break;
        case 'abort':
          mode = DishwasherMode.abort;
          break;
        case 'dirty':
          mode = DishwasherMode.dirty;
          break;
        default:
          mode = DishwasherMode.active;
          break;
      }
      if (ui)
        updateUi(screen);
    });
    ProcessMonitor buttonProcess = ProcessMonitor(
      executable: credentials.buttonProcess,
      onLog: (String message) {
        if (!ui)
          print('buttons: $message');
      },
      onError: (Object error) async {
        terminate.completeError(error);
      },
    );
    buttonProcess.output.listen((int newButtons) {
      if (newButtons != null) {
        buttons = newButtons;
        switch (buttons) {
          case 0x01: // HALF-EMPTY
            remy.pushButtonById('halfEmptiedDishwasher');
            break;
          case 0x02: // FULL-EMPTY
            remy.pushButtonById('emptiedDishwasher');
            break;
        }
        if (ui)
          updateUi(screen);
      }
    });
    ProcessMonitor leakSensorProcess = ProcessMonitor(
      executable: credentials.leakSensorProcess,
      onLog: (String message) {
        if (!ui)
          print('leak sensor: $message');
      },
      onError: (Object error) async {
        terminate.completeError(error);
      },
    );
    leakSensorProcess.output.listen((int value) {
      if (value != null) {
        leaking = value > 0;
        reportLeak(remy, value & 0x01 > 0, 'KitchenSink');
        reportLeak(remy, value & 0x02 > 0, 'Dishwasher');
        if (ui)
          updateUi(screen);
      }
    });
    if (ui)
      screen = Screen();
    ProcessSignal.sigint.watch().listen(signalEnd);
    if (ui) {
      print('\x1B#8'); // fill screen with Es
      updateUi(screen);
    }
    database.stream.listen((TableRecord record) {
      status = Status.fromDatabaseRecord(record);
      if (ui)
        updateUi(screen);
      else
        status.dump();
    });
    Timer blink = Timer.periodic(const Duration(milliseconds: 1250), (Timer timer) {
      clock += 1;
      if (ui)
        updateUi(screen);
    });
    await terminate.future;
    blink?.cancel();
    screen?.dispose();
    buttonProcess?.dispose();
    leakSensorProcess?.dispose();
    exit(0);
  }, onError: (error, stack) {
    screen?.dispose();
    print('\x1BcFatal error: $error\n$stack');
    exit(1);
  });
}
