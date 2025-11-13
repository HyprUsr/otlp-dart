import '../common/attribute.dart';

/// Resource represents the entity producing telemetry.
/// For example, a process running in a container or a specific application.
class Resource {
  final List<Attribute> attributes;
  final int droppedAttributesCount;

  Resource({
    List<Attribute>? attributes,
    this.droppedAttributesCount = 0,
  }) : attributes = attributes ?? [];

  /// Creates a default resource with service information.
  factory Resource.create({
    required String serviceName,
    String? serviceVersion,
    String? serviceInstanceId,
    Map<String, String>? additionalAttributes,
  }) {
    final attrs = <Attribute>[
      Attribute('service.name', AttributeValue.string(serviceName)),
    ];

    if (serviceVersion != null) {
      attrs.add(
          Attribute('service.version', AttributeValue.string(serviceVersion)));
    }

    if (serviceInstanceId != null) {
      attrs.add(Attribute(
          'service.instance.id', AttributeValue.string(serviceInstanceId)));
    }

    if (additionalAttributes != null) {
      for (final entry in additionalAttributes.entries) {
        attrs.add(Attribute(entry.key, AttributeValue.string(entry.value)));
      }
    }

    return Resource(attributes: attrs);
  }

  Map<String, dynamic> toJson() => {
        'attributes': attributes.map((a) => a.toJson()).toList(),
        if (droppedAttributesCount > 0)
          'droppedAttributesCount': droppedAttributesCount,
      };
}

/// InstrumentationScope represents the instrumentation library.
class InstrumentationScope {
  final String name;
  final String? version;
  final List<Attribute> attributes;
  final int droppedAttributesCount;

  InstrumentationScope({
    required this.name,
    this.version,
    List<Attribute>? attributes,
    this.droppedAttributesCount = 0,
  }) : attributes = attributes ?? [];

  Map<String, dynamic> toJson() => {
        'name': name,
        if (version != null) 'version': version,
        if (attributes.isNotEmpty)
          'attributes': attributes.map((a) => a.toJson()).toList(),
        if (droppedAttributesCount > 0)
          'droppedAttributesCount': droppedAttributesCount,
      };
}
