/// Attribute key-value pairs used in OTLP.
class Attribute {
  final String key;
  final AttributeValue value;

  Attribute(this.key, this.value);

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value.toJson(),
      };
}

/// Attribute value that can be of different types.
class AttributeValue {
  final String? stringValue;
  final bool? boolValue;
  final int? intValue;
  final double? doubleValue;
  final List<AttributeValue>? arrayValue;
  final Map<String, AttributeValue>? kvlistValue;

  AttributeValue.string(String value)
      : stringValue = value,
        boolValue = null,
        intValue = null,
        doubleValue = null,
        arrayValue = null,
        kvlistValue = null;

  AttributeValue.bool(bool value)
      : stringValue = null,
        boolValue = value,
        intValue = null,
        doubleValue = null,
        arrayValue = null,
        kvlistValue = null;

  AttributeValue.int(int value)
      : stringValue = null,
        boolValue = null,
        intValue = value,
        doubleValue = null,
        arrayValue = null,
        kvlistValue = null;

  AttributeValue.double(double value)
      : stringValue = null,
        boolValue = null,
        intValue = null,
        doubleValue = value,
        arrayValue = null,
        kvlistValue = null;

  AttributeValue.array(List<AttributeValue> value)
      : stringValue = null,
        boolValue = null,
        intValue = null,
        doubleValue = null,
        arrayValue = value,
        kvlistValue = null;

  AttributeValue.kvlist(Map<String, AttributeValue> value)
      : stringValue = null,
        boolValue = null,
        intValue = null,
        doubleValue = null,
        arrayValue = null,
        kvlistValue = value;

  Map<String, dynamic> toJson() {
    if (stringValue != null) return {'stringValue': stringValue};
    if (boolValue != null) return {'boolValue': boolValue};
    if (intValue != null) return {'intValue': intValue.toString()};
    if (doubleValue != null) return {'doubleValue': doubleValue};
    if (arrayValue != null) {
      return {
        'arrayValue': {
          'values': arrayValue!.map((v) => v.toJson()).toList(),
        }
      };
    }
    if (kvlistValue != null) {
      return {
        'kvlistValue': {
          'values': kvlistValue!.entries
              .map((e) => {'key': e.key, 'value': e.value.toJson()})
              .toList(),
        }
      };
    }
    return {};
  }
}
