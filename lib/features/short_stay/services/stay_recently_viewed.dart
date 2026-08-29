import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  "Recently viewed", made real.
//
//  Written 27 August 2026.
//
//  ── ⚠ WHY THIS EXISTS RATHER THAN THE SECTION SIMPLY COMING BACK ────────────
//
//  Stitch drew three sections on the home screen. On 22 August two of them were
//  DELETED rather than wired, and the file header said why: "Recently viewed"
//  was `_buildHorizontalList(HomeScreenData.partnersNearby)` — the same two
//  hardcoded properties as the section above it, relabelled as things the guest
//  had looked at when they had just opened the app for the first time.
//
//  Deleting it was right at the time. Nothing in the product recorded a view, so
//  the heading could only ever be a lie.
//
//  This records the view. Now the heading can be true, and the Stitch layout can
//  come back without inventing anything.
//
//  ── DESIGN NOTES ────────────────────────────────────────────────────────────
//
//  ⚠ DEVICE-LOCAL ON PURPOSE. This is not written to Firestore.
//
//  What a person browsed — before they booked anything, before they committed to
//  anything — is not something we need on a server. It buys us nothing: the
//  section only ever renders on the device that did the browsing. Putting it in
//  Firestore would mean a per-user document recording property-viewing history,
//  which is a genuine privacy liability, a write on every card tap, and a GDPR
//  subject-access item, in exchange for the ability to show the same list on a
//  second phone. Not worth any of that.
//
//  It also means signing out clears it with everything else, and there is no
//  cross-account leak on a shared device.
//
//  ⚠ IDS ONLY, NEVER SNAPSHOTS. We store listing IDs and re-read the listings.
//  Caching title, price and photo here would mean the section shows yesterday's
//  price — the exact class of bug this codebase keeps hitting, where one fact
//  has two homes and only one of them is maintained.
// ─────────────────────────────────────────────────────────────────────────────

class StayRecentlyViewed {
  StayRecentlyViewed._();
  static final StayRecentlyViewed instance = StayRecentlyViewed._();

  static const String _key = 'stay_recently_viewed_v1';

  /// Six is what the Stitch layout shows before it runs out of row.
  ///
  /// Kept small deliberately: a long history is a tracking record, and nobody
  /// scrolls sideways past the fourth item.
  static const int _max = 6;

  /// Record that this listing was opened. Most recent first, no duplicates.
  ///
  /// Never throws. A failure to write a browsing convenience must not be able
  /// to stop a listing from opening, so every path here swallows.
  Future<void> record(String listingId) async {
    final String id = listingId.trim();
    if (id.isEmpty) return;
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final List<String> ids = p.getStringList(_key) ?? <String>[];
      ids.remove(id); // re-viewing moves it to the front rather than duplicating
      ids.insert(0, id);
      if (ids.length > _max) ids.removeRange(_max, ids.length);
      await p.setStringList(_key, ids);
    } catch (_) {
      // Deliberately silent. See above.
    }
  }

  /// Most recently opened first. Empty when nothing has been opened yet, which
  /// is the correct state for a new install — the section hides itself.
  Future<List<String>> ids() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      return p.getStringList(_key) ?? <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  /// Used by sign-out. A shared device must not show one person's browsing to
  /// the next person who logs in.
  Future<void> clear() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.remove(_key);
    } catch (_) {}
  }
}
