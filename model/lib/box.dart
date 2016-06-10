import 'dart:math' as math;

abstract class Box {
  String get topLeft;
  String get topRight;
  String get bottomLeft;
  String get bottomRight;
  String get vertical;
  String get horizontal;
  String get labelLeft;
  String get labelRight;

  static const flex = '\t';
  static const space = ' ';

  String buildBox({
    int margin: 3,
    int padding: 1,
    List<String> topLeftLabels: const <String>[],
    List<String> topCenterLabels: const <String>[],
    List<String> topRightLabels: const <String>[],
    List<String> lines: const <String>[],
    List<String> bottomLeftLabels: const <String>[],
    List<String> bottomCenterLabels: const <String>[],
    List<String> bottomRightLabels: const <String>[]
  }) {
    final String top = _drawLabels(topLeftLabels, topCenterLabels, topRightLabels, margin, padding);
    final String bottom = _drawLabels(bottomLeftLabels, bottomCenterLabels, bottomRightLabels, margin, padding);

    int width = math.max(top.length, bottom.length);
    width = lines.fold(width, (int currentWidth, String s) => math.max(currentWidth, s.length));

    final String paddingLine = (padding > 1) ? _expandLine('', width, vertical, space, vertical, padding) : null;
    final int paddingCount = padding ~/ 2;

    final StringBuffer output = new StringBuffer();
    output.writeln(_expandLine(top, width, topLeft, horizontal, topRight, padding));
    for (int index = 0; index < paddingCount; index += 1)
      output.writeln(paddingLine);
    for (String line in lines)
      output.writeln(_expandLine(line, width, vertical, space, vertical, padding));
    for (int index = 0; index < paddingCount; index += 1)
      output.writeln(paddingLine);
    output.write(_expandLine(bottom, width, bottomLeft, horizontal, bottomRight, padding));
    return output.toString();
  }

  String _drawLabels(List<String> leftLabels, List<String> centerLabels, List<String> rightLabels, int margin, int padding) {
    return (horizontal * margin) +
           _wrapLabels(leftLabels, margin) +
           (centerLabels.length > 0
             ? _flexBetweenLabels(leftLabels, centerLabels, margin) +
               _wrapLabels(centerLabels, margin) +
               _flexBetweenLabels(centerLabels, rightLabels, margin)
             : _flexBetweenLabels(leftLabels, rightLabels, margin)
           ) +
           _wrapLabels(rightLabels, margin) +
           (horizontal * margin);
  }

  String _wrapLabels(List<String> labels, int margin) {
    return labels.map/*<String>*/((String label) => '$labelLeft$label$labelRight').join(horizontal * margin);
  }

  String _flexBetweenLabels(List<String> left, List<String> right, int margin) {
    if ((left.length > 0) && (right.length > 0))
      return horizontal * margin + flex;
    return flex;
  }

  String _expandLine(String input, int width, String left, String fill, String right, int padding) {
    assert(input.length <= width);
    final int flexCount = flex.allMatches(input).length;
    String output;
    if (flexCount > 0) {
      final int fillsNeeded = width - (input.length - flexCount);
      final String fills = fill * ((fillsNeeded / flexCount) / fill.length).truncate();
      final String extraFills = fill * ((fillsNeeded - (fills.length * flexCount)) / fill.length).truncate();
      int index = 0;
      output = input.replaceAllMapped(flex, (Match match) {
        index += 1;
        if (index == flexCount)
          return fills + extraFills;
        return fills;
      });
    } else {
      output = input;
    }
    output = output.padRight(width, fill);
    assert(output.length == width);
    assert(!output.contains(flex));
    final String edge = fill * padding;
    return '$left$edge$output$edge$right';
  }
}

class SingleLineBox extends Box {
  String get topLeft => '┌';
  String get topRight => '┐';
  String get bottomLeft => '└';
  String get bottomRight => '┘';
  String get vertical => '│';
  String get horizontal => '─';
  String get labelLeft => '┤ ';
  String get labelRight => ' ├';
}

class DoubleLineBox extends Box {
  String get topLeft => '╔';
  String get topRight => '╗';
  String get bottomLeft => '╚';
  String get bottomRight => '╝';
  String get vertical => '║';
  String get horizontal => '═';
  String get labelLeft => '╡ ';
  String get labelRight => ' ╞';
}

void main() {
  print(new DoubleLineBox().buildBox(
    margin: 10,
    padding: 1,
    lines: <String>[
      'Left0',
      'Left1\t',
      'Left2\t\t',
      'Left3\t\t\t',
      '\tCenter\t',
      'Right0',
      '\tRight1',
      '\t\tRight2',
      '\t\t\tRight3',
      '\ta\tb\tc\td',
      'x' * 117,
    ],
    bottomCenterLabels: <String>['R', 'AtTTTTTTTTTTTTTTTTTTTTLSO CENTER'],
    topRightLabels: <String>['HAHAHA']
  ));
}
