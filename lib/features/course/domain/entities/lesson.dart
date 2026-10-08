/// One video lesson inside a [CourseSection] — always sourced from
/// [CourseRepository], never constructed ad hoc by the UI.
class Lesson {
  const Lesson({
    required this.id,
    required this.sectionId,
    required this.title,
    required this.description,
    required this.duration,
    required this.order,
    required this.videoAssetId,
  });

  final String id;
  final String sectionId;
  final String title;
  final String description;
  final Duration duration;

  /// Position within its section — lessons render in this order, never in
  /// fetch order.
  final int order;

  /// An opaque reference to wherever the real video eventually lives (see
  /// `docs/ARCHITECTURE.md` §13.3/§25) — never a vendor-specific URL,
  /// player id, or embed code. **No real video exists yet** — see
  /// `COURSE_API_REQUIREMENTS.md`'s "Video hosting status". The lesson
  /// screen shows an honest placeholder instead of pretending to play
  /// this.
  final String videoAssetId;
}
