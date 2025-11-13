import '../../sdk/common/attribute.dart';
import '../../sdk/resource/resource.dart';

/// MetricData represents a single metric data point.
abstract class MetricData {
  String get name;
  String? get unit;
  String? get description;
  Map<String, dynamic> toJson();
}

/// SumData represents a sum metric.
class SumData implements MetricData {
  @override
  final String name;
  @override
  final String? unit;
  @override
  final String? description;
  final List<DataPoint> dataPoints;
  final bool isMonotonic;

  SumData({
    required this.name,
    this.unit,
    this.description,
    required this.dataPoints,
    this.isMonotonic = true,
  });

  @override
  Map<String, dynamic> toJson() => {
        'name': name,
        if (unit != null) 'unit': unit,
        if (description != null) 'description': description,
        'sum': {
          'dataPoints': dataPoints.map((d) => d.toJson()).toList(),
          'aggregationTemporality': 2, // DELTA
          'isMonotonic': isMonotonic,
        },
      };
}

/// GaugeData represents a gauge metric.
class GaugeData implements MetricData {
  @override
  final String name;
  @override
  final String? unit;
  @override
  final String? description;
  final List<DataPoint> dataPoints;

  GaugeData({
    required this.name,
    this.unit,
    this.description,
    required this.dataPoints,
  });

  @override
  Map<String, dynamic> toJson() => {
        'name': name,
        if (unit != null) 'unit': unit,
        if (description != null) 'description': description,
        'gauge': {
          'dataPoints': dataPoints.map((d) => d.toJson()).toList(),
        },
      };
}

/// HistogramData represents a histogram metric.
class HistogramData implements MetricData {
  @override
  final String name;
  @override
  final String? unit;
  @override
  final String? description;
  final List<HistogramDataPoint> dataPoints;

  HistogramData({
    required this.name,
    this.unit,
    this.description,
    required this.dataPoints,
  });

  @override
  Map<String, dynamic> toJson() => {
        'name': name,
        if (unit != null) 'unit': unit,
        if (description != null) 'description': description,
        'histogram': {
          'dataPoints': dataPoints.map((d) => d.toJson()).toList(),
          'aggregationTemporality': 2, // DELTA
        },
      };
}

/// DataPoint represents a single data point in a metric.
class DataPoint {
  final List<Attribute> attributes;
  final int startTimeUnixNano;
  final int timeUnixNano;
  final num value;

  DataPoint({
    required this.attributes,
    required this.startTimeUnixNano,
    required this.timeUnixNano,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
        'attributes': attributes.map((a) => a.toJson()).toList(),
        'startTimeUnixNano': startTimeUnixNano.toString(),
        'timeUnixNano': timeUnixNano.toString(),
        if (value is int)
          'asInt': value.toString()
        else
          'asDouble': value,
      };
}

/// HistogramDataPoint represents a histogram data point.
class HistogramDataPoint {
  final List<Attribute> attributes;
  final int startTimeUnixNano;
  final int timeUnixNano;
  final int count;
  final double sum;
  final List<int> bucketCounts;
  final List<double> explicitBounds;
  final double? min;
  final double? max;

  HistogramDataPoint({
    required this.attributes,
    required this.startTimeUnixNano,
    required this.timeUnixNano,
    required this.count,
    required this.sum,
    required this.bucketCounts,
    required this.explicitBounds,
    this.min,
    this.max,
  });

  Map<String, dynamic> toJson() => {
        'attributes': attributes.map((a) => a.toJson()).toList(),
        'startTimeUnixNano': startTimeUnixNano.toString(),
        'timeUnixNano': timeUnixNano.toString(),
        'count': count.toString(),
        'sum': sum,
        'bucketCounts': bucketCounts.map((c) => c.toString()).toList(),
        'explicitBounds': explicitBounds,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
      };
}
