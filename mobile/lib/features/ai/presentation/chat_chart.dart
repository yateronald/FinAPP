import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

/// Renders an AI-emitted chart spec (```chart JSON block) as a real chart.
/// Supported types: bar, column, stackedBar, horizontalBar, line, area, pie,
/// donut, gauge, radar. Standard spec:
///   { type, title, xKey, series:[{key,name}], data:[{name, <key>:num}] }
/// Gauge spec:
///   { type:"gauge", title, value, max, unit?, label? }
class ChatChart extends StatelessWidget {
  final Map<String, dynamic> spec;
  const ChatChart({super.key, required this.spec});

  @override
  Widget build(BuildContext context) {
    final type = (spec['type'] ?? 'bar').toString().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    final title = spec['title']?.toString() ?? '';
    final data = (spec['data'] as List?) ?? const [];
    final xKey = spec['xKey']?.toString() ?? 'name';
    final series = (spec['series'] as List?) ?? const [];

    // Gauge doesn't need a `data` array (it can read value/max from the spec).
    final isGauge = type == 'gauge' || type == 'radial' || type == 'radialbar' || type == 'progress';
    if (data.isEmpty && !isGauge) return const SizedBox.shrink();

    Widget chart;
    switch (type) {
      case 'pie':
      case 'donut':
      case 'doughnut':
        chart = _Pie(data: data, xKey: xKey, series: series);
        break;
      case 'gauge':
      case 'radial':
      case 'radialbar':
      case 'progress':
        chart = _Gauge(spec: spec, data: data, xKey: xKey, series: series);
        break;
      case 'radar':
      case 'spider':
        chart = data.length >= 3
            ? _Radar(data: data, xKey: xKey, series: series)
            : _Bar(data: data, xKey: xKey, series: series);
        break;
      case 'horizontalbar':
      case 'hbar':
      case 'barh':
        chart = _HBar(data: data, xKey: xKey, series: series);
        break;
      case 'stackedbar':
      case 'stacked':
        chart = _Bar(data: data, xKey: xKey, series: series, stacked: true);
        break;
      case 'line':
        chart = _LineOrArea(data: data, xKey: xKey, series: series, area: false);
        break;
      case 'area':
        chart = _LineOrArea(data: data, xKey: xKey, series: series, area: true);
        break;
      default:
        chart = _Bar(data: data, xKey: xKey, series: series);
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 2),
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
          chart,
        ],
      ),
    );
  }
}

String _valueKey(List series) =>
    series.isNotEmpty ? ((series.first as Map)['key']?.toString() ?? 'value') : 'value';

List<String> _seriesKeys(List series) => series.isEmpty
    ? ['value']
    : series.map((s) => (s as Map)['key']?.toString() ?? 'value').toList();

String _seriesName(List series, int i, String fallback) {
  if (i < series.length) return (series[i] as Map)['name']?.toString() ?? fallback;
  return fallback;
}

Color _color(int i) => AppColors.palette[i % AppColors.palette.length];

// --------------------------------------------------------------- Pie

class _Pie extends StatelessWidget {
  final List data;
  final String xKey;
  final List series;
  const _Pie({required this.data, required this.xKey, required this.series});

  @override
  Widget build(BuildContext context) {
    final vKey = _valueKey(series);
    final items = [
      for (final d in data) (name: (d as Map)[xKey]?.toString() ?? '', value: asDouble(d[vKey]))
    ];
    final total = items.fold<double>(0, (s, e) => s + e.value);
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 44,
                sections: [
                  for (var i = 0; i < items.length; i++)
                    PieChartSectionData(
                        value: items[i].value,
                        color: _color(i),
                        radius: 22,
                        showTitle: false),
                ],
              )),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Money.compact(total),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('Total', style: TextStyle(color: context.muted, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...[
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: _color(i), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(items[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.muted, fontSize: 12.5)),
                  ),
                  Text(Money.number(items[i].value),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  const SizedBox(width: 8),
                  Text(total > 0 ? '${(items[i].value / total * 100).round()}%' : '—',
                      style: TextStyle(
                          color: context.muted, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------- Bar

class _Bar extends StatelessWidget {
  final List data;
  final String xKey;
  final List series;
  final bool stacked;
  const _Bar({required this.data, required this.xKey, required this.series, this.stacked = false});

  @override
  Widget build(BuildContext context) {
    final keys = _seriesKeys(series);
    final isStacked = stacked && keys.length > 1;
    double maxV = 0;
    for (final d in data) {
      if (isStacked) {
        double sum = 0;
        for (final k in keys) {
          sum += asDouble((d as Map)[k]);
        }
        if (sum > maxV) maxV = sum;
      } else {
        for (final k in keys) {
          final v = asDouble((d as Map)[k]);
          if (v > maxV) maxV = v;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: BarChart(BarChartData(
            maxY: maxV * 1.2,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    final label = (data[i] as Map)[xKey]?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        label.length > 5 ? '${label.substring(0, 5)}…' : label,
                        style: TextStyle(color: context.muted, fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 3,
                  barRods: isStacked
                      ? [_stackedRod(data[i] as Map, keys)]
                      : [
                          for (var s = 0; s < keys.length; s++)
                            BarChartRodData(
                                toY: asDouble((data[i] as Map)[keys[s]]),
                                color: _color(keys.length == 1 ? i : s),
                                width: keys.length == 1 ? 12 : 8,
                                borderRadius: BorderRadius.circular(3)),
                        ],
                ),
            ],
          )),
        ),
        if (keys.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (var s = 0; s < keys.length; s++) _legendDot(context, _color(s), _seriesName(series, s, keys[s])),
          ]),
        ],
      ],
    );
  }
}

// ----------------------------------------------------------- Line/Area

class _LineOrArea extends StatelessWidget {
  final List data;
  final String xKey;
  final List series;
  final bool area;
  const _LineOrArea(
      {required this.data, required this.xKey, required this.series, required this.area});

  @override
  Widget build(BuildContext context) {
    final keys = _seriesKeys(series);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: LineChart(LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: context.borderColor, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    final label = (data[i] as Map)[xKey]?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(label.length > 5 ? '${label.substring(0, 5)}…' : label,
                          style: TextStyle(color: context.muted, fontSize: 9)),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              for (var s = 0; s < keys.length; s++)
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < data.length; i++)
                      FlSpot(i.toDouble(), asDouble((data[i] as Map)[keys[s]])),
                  ],
                  isCurved: true,
                  color: _color(s),
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData:
                      BarAreaData(show: area, color: _color(s).withValues(alpha: 0.15)),
                ),
            ],
          )),
        ),
        if (keys.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (var s = 0; s < keys.length; s++) _legendDot(context, _color(s), _seriesName(series, s, keys[s])),
          ]),
        ],
      ],
    );
  }
}

Widget _legendDot(BuildContext context, Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: context.muted, fontSize: 12)),
      ],
    );

BarChartRodData _stackedRod(Map row, List<String> keys) {
  double running = 0;
  final items = <BarChartRodStackItem>[];
  for (var s = 0; s < keys.length; s++) {
    final v = asDouble(row[keys[s]]);
    items.add(BarChartRodStackItem(running, running + v, _color(s)));
    running += v;
  }
  return BarChartRodData(
    toY: running,
    rodStackItems: items,
    width: 14,
    borderRadius: BorderRadius.circular(3),
  );
}

String _numLabel(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

// --------------------------------------------------------------- Gauge

class _Gauge extends StatelessWidget {
  final Map<String, dynamic> spec;
  final List data;
  final String xKey;
  final List series;
  const _Gauge({required this.spec, required this.data, required this.xKey, required this.series});

  @override
  Widget build(BuildContext context) {
    final first = data.isNotEmpty ? (data.first as Map) : const {};
    final vKey = _valueKey(series);
    final value = asDouble(spec['value'] ?? first['value'] ?? first[vKey]);
    final rawMax = asDouble(spec['max'] ?? first['max'] ?? spec['target'] ?? first['target']);
    final max = rawMax > 0 ? rawMax : 100.0;
    final unit = (spec['unit'] ?? first['unit'] ?? '').toString();
    final label = (spec['label'] ?? first['name'] ?? '').toString();
    final frac = (max > 0 ? value / max : 0.0).clamp(0.0, 1.0).toDouble();
    final center = unit.isNotEmpty ? '${_numLabel(value)}$unit' : Money.compact(value);
    final isPercent = unit == '%';

    // The situation colour: the AI may set `color`; otherwise we derive a sane
    // green/amber/red from the fill so the gauge always reads meaningfully.
    final color = _gaugeColor(spec['color'], frac);

    return SizedBox(
      height: 190,
      child: CustomPaint(
        painter: _GaugePainter(frac: frac, color: color, track: context.surfaceAlt),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(center,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: color)),
              if (!isPercent) ...[
                const SizedBox(height: 2),
                Text('${(frac * 100).round()}%',
                    style: TextStyle(color: context.muted, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              if (label.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 24, right: 24),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.muted, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _gaugeColor(dynamic specColor, double frac) {
    if (specColor is String && specColor.isNotEmpty) {
      return AppColors.hexToColor(specColor, AppColors.primary);
    }
    // No colour given: assume "higher is better" → red → amber → green.
    if (frac >= 0.7) return AppColors.success;
    if (frac >= 0.4) return AppColors.warning;
    return AppColors.danger;
  }
}

class _GaugePainter extends CustomPainter {
  final double frac;
  final Color color;
  final Color track;
  _GaugePainter({required this.frac, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final radius = math.min(size.width, size.height) * 0.44;
    const startAngle = math.pi * 0.75; // 135°
    const sweep = math.pi * 1.5; // 270°
    const stroke = 18.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track.
    canvas.drawArc(
      rect,
      startAngle,
      sweep,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    if (frac <= 0) return;

    // Value arc with a subtle gradient (lighter → full colour) for depth.
    final valPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweep,
        colors: [Color.lerp(color, Colors.white, 0.45)!, color],
        transform: const GradientRotation(0),
      ).createShader(rect);
    final valSweep = sweep * frac;
    canvas.drawArc(rect, startAngle, valSweep, false, valPaint);

    // Rounded highlight dot at the tip of the value arc.
    final tipAngle = startAngle + valSweep;
    final tip = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );
    canvas.drawCircle(tip, stroke / 2 - 1, Paint()..color = Colors.white);
    canvas.drawCircle(tip, stroke / 2 - 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.frac != frac || old.color != color || old.track != track;
}

// --------------------------------------------------------- Horizontal bar

class _HBar extends StatelessWidget {
  final List data;
  final String xKey;
  final List series;
  const _HBar({required this.data, required this.xKey, required this.series});

  @override
  Widget build(BuildContext context) {
    final vKey = _valueKey(series);
    final items = [
      for (final d in data) (name: (d as Map)[xKey]?.toString() ?? '', value: asDouble(d[vKey]))
    ];
    final maxV = items.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(items[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.muted, fontSize: 12.5)),
                    ),
                    Text(Money.number(items[i].value),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(height: 10, color: context.surfaceAlt),
                      FractionallySizedBox(
                        widthFactor: maxV > 0 ? (items[i].value / maxV).clamp(0.0, 1.0) : 0.0,
                        child: Container(height: 10, color: _color(i)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------- Radar

class _Radar extends StatelessWidget {
  final List data;
  final String xKey;
  final List series;
  const _Radar({required this.data, required this.xKey, required this.series});

  @override
  Widget build(BuildContext context) {
    final keys = _seriesKeys(series);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 240,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              dataSets: [
                for (var s = 0; s < keys.length; s++)
                  RadarDataSet(
                    fillColor: _color(s).withValues(alpha: 0.15),
                    borderColor: _color(s),
                    borderWidth: 2,
                    entryRadius: 2,
                    dataEntries: [
                      for (final d in data) RadarEntry(value: asDouble((d as Map)[keys[s]])),
                    ],
                  ),
              ],
              radarBackgroundColor: Colors.transparent,
              getTitle: (index, angle) => RadarChartTitle(
                text: index < data.length ? ((data[index] as Map)[xKey]?.toString() ?? '') : '',
              ),
              titleTextStyle: TextStyle(color: context.muted, fontSize: 10),
              titlePositionPercentageOffset: 0.15,
              tickCount: 3,
              ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
              gridBorderData: BorderSide(color: context.borderColor, width: 1),
              tickBorderData: BorderSide(color: context.borderColor, width: 1),
              radarBorderData: BorderSide(color: context.borderColor, width: 1),
            ),
          ),
        ),
        if (keys.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (var s = 0; s < keys.length; s++)
              _legendDot(context, _color(s), _seriesName(series, s, keys[s])),
          ]),
        ],
      ],
    );
  }
}
