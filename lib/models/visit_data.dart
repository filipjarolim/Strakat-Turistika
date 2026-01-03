

enum UserRole {
  ADMIN,
  UZIVATEL,
  TESTER,
}

enum VisitState {
  DRAFT,
  PENDING_REVIEW,
  APPROVED,
  REJECTED,
}

enum PlaceType {
  PEAK,
  TOWER,
  TREE,
  OTHER,
}

class Place {
  final String id;
  final String name;
  final PlaceType type;
  final List<PlacePhoto> photos;
  final String? description;
  final DateTime createdAt;

  const Place({
    required this.id,
    required this.name,
    required this.type,
    required this.photos,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'photos': photos.map((photo) => photo.toMap()).toList(),
    'description': description,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Place.fromMap(Map<String, dynamic> map) => Place(
    id: map['id']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    type: PlaceType.values.firstWhere(
      (e) => e.name == map['type'],
      orElse: () => PlaceType.OTHER,
    ),
    photos: (map['photos'] as List<dynamic>?)
        ?.map((photo) => PlacePhoto.fromMap(photo))
        .toList() ?? [],
    description: map['description']?.toString(),
    createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );

  Place copyWith({
    String? id,
    String? name,
    PlaceType? type,
    List<PlacePhoto>? photos,
    String? description,
    DateTime? createdAt,
  }) => Place(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    photos: photos ?? this.photos,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
  );
}

class PlacePhoto {
  final String id;
  final String url;
  final String? description;
  final DateTime uploadedAt;
  final bool isLocal;

  const PlacePhoto({
    required this.id,
    required this.url,
    this.description,
    required this.uploadedAt,
    this.isLocal = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'url': url,
    'description': description,
    'uploadedAt': uploadedAt.toIso8601String(),
    'isLocal': isLocal,
  };

  factory PlacePhoto.fromMap(Map<String, dynamic> map) => PlacePhoto(
    id: map['id']?.toString() ?? '',
    url: map['url']?.toString() ?? '',
    description: map['description']?.toString(),
    uploadedAt: DateTime.tryParse(map['uploadedAt']?.toString() ?? '') ?? DateTime.now(),
    isLocal: map['isLocal'] == true,
  );

  PlacePhoto copyWith({
    String? id,
    String? url,
    String? description,
    DateTime? uploadedAt,
    bool? isLocal,
  }) => PlacePhoto(
    id: id ?? this.id,
    url: url ?? this.url,
    description: description ?? this.description,
    uploadedAt: uploadedAt ?? this.uploadedAt,
    isLocal: isLocal ?? this.isLocal,
  );
}

class VisitData {
  final String id;
  final DateTime? visitDate;
  final String? routeTitle;
  final String? routeDescription;
  final String? dogName;
  final double points;
  final String visitedPlaces;
  final String? dogNotAllowed;
  final String? routeLink;
  final Map<String, dynamic>? route;
  final int year;
  final Map<String, dynamic> extraPoints;
  final Map<String, dynamic>? extraData; // Dynamic form data
  final List<Place> places; // New structured places
  final VisitState state;
  final String? rejectionReason;
  final DateTime? createdAt;
  final List<Map<String, dynamic>>? photos; // Photos field (includes screenshots from web)
  // Structure from web: { url, public_id, title, description, uploadedAt }
  final String? seasonId;
  final String? userId;
  final Map<String, dynamic>? user; // User data from JOIN
  final String? displayName; // Computed display name

  VisitData({
    required this.id,
    this.visitDate,
    this.routeTitle,
    this.routeDescription,
    this.dogName,
    required this.points,
    required this.visitedPlaces,
    this.dogNotAllowed,
    this.routeLink,
    this.route,
    required this.year,
    required this.extraPoints,
    this.extraData,
    this.places = const [],
    this.state = VisitState.DRAFT,
    this.rejectionReason,
    this.createdAt,
    this.photos,
    this.seasonId,
    this.userId,
    this.user,
    this.displayName,
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'visitDate': visitDate?.toIso8601String(),
      'routeTitle': routeTitle,
      'routeDescription': routeDescription,
      'dogName': dogName,
      'points': points,
      'visitedPlaces': visitedPlaces,
      'dogNotAllowed': dogNotAllowed,
      'routeLink': routeLink,
      'route': route,
      'seasonYear': year,
      'extraPoints': extraPoints,
      'extraData': extraData,
      'places': places.map((place) => place.toMap()).toList(),
      'state': state.name,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt?.toIso8601String(),
      'photos': photos,
      'seasonId': seasonId,
      'userId': userId,
      'user': user,
      'displayName': displayName,
    };
  }

  factory VisitData.fromMap(Map<String, dynamic> map) {
    try {
      return VisitData(
      id: map['_id'] ?? map['id'] ?? '',
      visitDate: map['visitDate'] != null 
          ? (map['visitDate'] is DateTime 
              ? map['visitDate'] as DateTime 
              : DateTime.parse(map['visitDate'].toString()))
          : null,
      routeTitle: map['routeTitle'],
      routeDescription: map['routeDescription'],
      dogName: map['dogName'],
      points: _parseDouble(map['points']) ?? 0.0,
      visitedPlaces: map['visitedPlaces'] ?? '',
      dogNotAllowed: map['dogNotAllowed'],
      routeLink: map['routeLink'],
      route: map['route'] != null 
          ? (map['route'] is Map 
              ? Map<String, dynamic>.from(map['route']) 
              : null)
          : null,
      year: _parseInt(map['seasonYear']) ?? DateTime.now().year,
      extraPoints: map['extraPoints'] != null 
          ? (map['extraPoints'] is Map 
              ? Map<String, dynamic>.from(map['extraPoints']) 
              : {})
          : {},
      extraData: map['extraData'] != null 
          ? Map<String, dynamic>.from(map['extraData'])
          : null,
      places: (map['places'] as List<dynamic>?)
          ?.map((place) => Place.fromMap(place))
          .toList() ?? [],
      state: VisitState.values.firstWhere(
        (e) => e.name == map['state'],
        orElse: () => VisitState.DRAFT,
      ),
      rejectionReason: map['rejectionReason'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is DateTime 
              ? map['createdAt'] as DateTime 
              : DateTime.parse(map['createdAt'].toString()))
          : null,
      photos: map['photos'] != null 
          ? List<Map<String, dynamic>>.from(map['photos'])
          : null,
      seasonId: map['seasonId'],
      userId: map['userId'],
      user: map['user'] != null 
          ? Map<String, dynamic>.from(map['user'])
          : null,
      displayName: map['displayName']?.toString(),
    );
    } catch (e) {
      print('❌ Error parsing VisitData: $e');
      print('❌ Map data: $map');
      rethrow;
    }
  }

  VisitData copyWith({
    String? id,
    DateTime? visitDate,
    String? routeTitle,
    String? routeDescription,
    String? dogName,
    double? points,
    String? visitedPlaces,
    String? dogNotAllowed,
    String? routeLink,
    Map<String, dynamic>? route,
    int? year,
    Map<String, dynamic>? extraPoints,
    Map<String, dynamic>? extraData,
    List<Place>? places,
    VisitState? state,
    String? rejectionReason,
    DateTime? createdAt,
    List<Map<String, dynamic>>? photos,
    String? seasonId,
    String? userId,
    Map<String, dynamic>? user,
    String? displayName,
  }) {
    return VisitData(
      id: id ?? this.id,
      visitDate: visitDate ?? this.visitDate,
      routeTitle: routeTitle ?? this.routeTitle,
      routeDescription: routeDescription ?? this.routeDescription,
      dogName: dogName ?? this.dogName,
      points: points ?? this.points,
      visitedPlaces: visitedPlaces ?? this.visitedPlaces,
      dogNotAllowed: dogNotAllowed ?? this.dogNotAllowed,
      routeLink: routeLink ?? this.routeLink,
      route: route ?? this.route,
      year: year ?? this.year,
      extraPoints: extraPoints ?? this.extraPoints,
      extraData: extraData ?? this.extraData,
      places: places ?? this.places,
      state: state ?? this.state,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      photos: photos ?? this.photos,
      seasonId: seasonId ?? this.seasonId,
      userId: userId ?? this.userId,
      user: user ?? this.user,
      displayName: displayName ?? this.displayName,
    );
  }


  Map<String, dynamic> toJson() {
    return toMap();
  }

  factory VisitData.fromJson(Map<String, dynamic> json) {
    return VisitData.fromMap(json);
  }

  // Helper method to parse int values from MongoDB (handles both int and Int64)
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    // Handle Int64 and other numeric types
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return double.tryParse(value.toString());
  }
} 