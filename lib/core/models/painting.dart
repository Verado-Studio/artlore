/// A single hidden-detail hotspot drawn over a painting image.
class PaintingDetail {
  const PaintingDetail({
    required this.x,
    required this.y,
    required this.title,
    required this.description,
    this.locked = false,
  });

  /// Fractional position (0-1) over the painting image.
  final double x;
  final double y;
  final String title;
  final String description;
  final bool locked;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'title': title,
        'description': description,
        'locked': locked,
      };

  factory PaintingDetail.fromJson(Map<String, dynamic> json) => PaintingDetail(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        title: json['title'] as String,
        description: json['description'] as String,
        locked: json['locked'] as bool? ?? false,
      );
}

/// Static mock representation of an identified (or unidentified) painting.
class Painting {
  const Painting({
    required this.title,
    required this.artist,
    required this.year,
    required this.movement,
    required this.museum,
    required this.confidence,
    required this.imageSeed,
    required this.hook,
    required this.stories,
    required this.details,
    this.shortStories = const {},
    this.scannedImagePath,
  });

  final String title;
  final String artist;
  final String year;
  final String movement;
  final String museum;
  final int confidence;
  final int imageSeed;
  final String hook;

  /// Full story text keyed by depth: "Kid", "Simple", "Art-lover".
  final Map<String, String> stories;
  final List<PaintingDetail> details;

  /// Shorter versions of the "Kid"/"Simple" stories — what free-tier users
  /// see instead of [stories], per depth; falls back to the full text if a
  /// depth has no short version (e.g. older cached scans, or "Art-lover"
  /// which is Pro-only and never has one).
  final Map<String, String> shortStories;

  /// The actual photo the user captured or picked for this scan, if any —
  /// there's no real identification backend yet, so the rest of the data
  /// above still comes from mock content regardless of what was photographed.
  final String? scannedImagePath;

  bool get isLowConfidence => confidence < 60;

  /// The story text to actually show for [depth]: the short (free-tier)
  /// version unless [isPro], falling back to the full story when no short
  /// version exists for that depth.
  String storyFor(String depth, {required bool isPro}) {
    if (isPro) return stories[depth] ?? '';
    return shortStories[depth] ?? stories[depth] ?? '';
  }

  Painting withScannedImagePath(String? path) => Painting(
        title: title,
        artist: artist,
        year: year,
        movement: movement,
        museum: museum,
        confidence: confidence,
        imageSeed: imageSeed,
        hook: hook,
        stories: stories,
        shortStories: shortStories,
        details: details,
        scannedImagePath: path,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'year': year,
        'movement': movement,
        'museum': museum,
        'confidence': confidence,
        'imageSeed': imageSeed,
        'hook': hook,
        'stories': stories,
        'shortStories': shortStories,
        'details': details.map((d) => d.toJson()).toList(),
        'scannedImagePath': scannedImagePath,
      };

  factory Painting.fromJson(Map<String, dynamic> json) => Painting(
        title: json['title'] as String,
        artist: json['artist'] as String,
        year: json['year'] as String,
        movement: json['movement'] as String,
        museum: json['museum'] as String,
        confidence: json['confidence'] as int,
        imageSeed: json['imageSeed'] as int,
        hook: json['hook'] as String,
        stories: Map<String, String>.from(json['stories'] as Map),
        shortStories: json['shortStories'] == null ? const {} : Map<String, String>.from(json['shortStories'] as Map),
        details: (json['details'] as List)
            .map((d) => PaintingDetail.fromJson(Map<String, dynamic>.from(d as Map)))
            .toList(),
        scannedImagePath: json['scannedImagePath'] as String?,
      );
}
