import 'dart:math';

/// Un identifiant (site, application…) stocké dans le coffre.
class VaultEntry {
  VaultEntry({
    String? id,
    required this.title,
    this.username = '',
    this.password = '',
    this.url = '',
    this.notes = '',
    DateTime? updatedAt,
  }) : id = id ?? _newId(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final DateTime updatedAt;

  VaultEntry copyWith({
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
  }) {
    return VaultEntry(
      id: id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
    );
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        username.toLowerCase().contains(q) ||
        url.toLowerCase().contains(q);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'username': username,
    'password': password,
    'url': url,
    'notes': notes,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory VaultEntry.fromJson(Map<String, dynamic> json) => VaultEntry(
    id: json['id'] as String,
    title: json['title'] as String,
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    url: json['url'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  static String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
