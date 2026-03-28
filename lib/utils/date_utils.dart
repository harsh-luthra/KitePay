/// Converts a [DateTime] to IST (Indian Standard Time, UTC+5:30).
/// Use this instead of `.toLocal()` so the app always shows IST
/// regardless of the device's local timezone.
DateTime toIST(DateTime dt) {
  final utc = dt.toUtc();
  return utc.add(const Duration(hours: 5, minutes: 30));
}

/// Converts an IST [DateTime] (as picked by user) back to UTC.
/// Use this instead of `.toUtc()` when the user picks a date/time
/// that should be treated as IST.
DateTime istToUtc(DateTime ist) {
  return ist.subtract(const Duration(hours: 5, minutes: 30)).toUtc();
}
