class Setlist {
  final int? id;
  final String name;
  final DateTime createdAt;

  Setlist({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Setlist.fromMap(Map<String, dynamic> map) {
    return Setlist(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}

class SetlistSong {
  final int? id;
  final int setlistId;
  final String songId;
  final int orderIndex;
  final String? customKey;
  final String? notes;

  SetlistSong({
    this.id,
    required this.setlistId,
    required this.songId,
    required this.orderIndex,
    this.customKey,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'setlistId': setlistId,
      'songId': songId,
      'orderIndex': orderIndex,
      'customKey': customKey,
      'notes': notes,
    };
  }

  factory SetlistSong.fromMap(Map<String, dynamic> map) {
    return SetlistSong(
      id: map['id'],
      setlistId: map['setlistId'],
      songId: map['songId'],
      orderIndex: map['orderIndex'],
      customKey: map['customKey'],
      notes: map['notes'],
    );
  }
}