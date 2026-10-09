/// A readable name for a signed-in device from its User-Agent — e.g.
/// "MADEEN app · iPhone", "Chrome · Windows". Product names aren't
/// translated; an agent it can't read is shown as-is (shortened).
String deviceNameFromUserAgent(String userAgent) {
  final ua = userAgent.toLowerCase();

  final String? os = switch (ua) {
    _ when ua.contains('ipad') => 'iPad',
    _ when ua.contains('iphone') || ua.contains('(ios') => 'iPhone',
    _ when ua.contains('android') => 'Android',
    _ when ua.contains('windows') => 'Windows',
    _
        when ua.contains('mac os') ||
            ua.contains('macintosh') ||
            ua.contains('(macos') =>
      'Mac',
    _ when ua.contains('linux') => 'Linux',
    _ => null,
  };

  // Order matters: Edge and Chrome both say "Chrome", Chrome says "Safari".
  final String? app = switch (ua) {
    _ when ua.startsWith('madeen') => 'MADEEN app',
    _ when ua.contains('edg/') => 'Edge',
    _ when ua.contains('opr/') || ua.contains('opera') => 'Opera',
    _ when ua.contains('firefox') || ua.contains('fxios') => 'Firefox',
    _ when ua.contains('chrome') || ua.contains('crios') => 'Chrome',
    _ when ua.contains('safari') => 'Safari',
    _ => null,
  };

  if (app != null && os != null) return '$app · $os';
  if (app != null) return app;
  if (os != null) return os;
  final trimmed = userAgent.trim();
  if (trimmed.isEmpty) return '—';
  return trimmed.length <= 40 ? trimmed : '${trimmed.substring(0, 40)}…';
}
