import 'dart:convert';

/// Informações transmitidas do aviso até a tela do aplicativo.
class NotificationPayload {
  const NotificationPayload({
    required this.kind,
    required this.title,
    required this.description,
  });

  static const detailRoute = '/detalhe';

  final String kind;
  final String title;
  final String description;

  String encode() => jsonEncode({
        'route': detailRoute,
        'kind': kind,
        'title': title,
        'description': description,
      });

  static NotificationPayload? decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final data = jsonDecode(encoded);
      if (data is! Map<String, dynamic> ||
          data['route'] != detailRoute ||
          data['kind'] is! String ||
          data['title'] is! String ||
          data['description'] is! String) {
        return null;
      }
      return NotificationPayload(
        kind: data['kind'] as String,
        title: data['title'] as String,
        description: data['description'] as String,
      );
    } on FormatException {
      return null;
    }
  }
}
