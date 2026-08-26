// ─────────────────────────────────────────────────────────────────────────────
//  Reading the passport, and checking it against what was typed.
//
//  Written 25 August 2026.
//
//  ── ⚠ WHAT WAS MISSING, AND FOR HOW LONG ────────────────────────────────────
//
//  Nothing read the document. The KYC screen photographed a passport, scored
//  the PICTURE for sharpness and brightness, and then showed the applicant the
//  name and date of birth THEY had typed — next to a photograph nobody had
//  read. Somebody could type one name and photograph a different person's
//  passport and the app would not notice. Only an admin comparing the two by
//  eye would.
//
//  ── WHY THE MRZ AND NOT GENERAL OCR ─────────────────────────────────────────
//
//  The two lines at the bottom of a passport are the Machine Readable Zone,
//  standardised by ICAO 9303. They are fixed-width, use one font, and — the
//  part that matters — CARRY THEIR OWN CHECK DIGITS.
//
//  General OCR across a passport page returns soup: headings, the issuing
//  authority, the holder's signature, glare. You cannot tell a misread surname
//  from a correct one. In the MRZ you can, because the checksum fails.
//
//  ⚠ SO THIS FILE REFUSES A READ IT CANNOT VERIFY. A field whose check digit
//  does not match is discarded rather than reported. Half-read data that looks
//  confident is worse than no data at all here — it would be compared against
//  the applicant's typing and generate a mismatch that is OUR fault, on a
//  screen that accuses them of getting their own name wrong.
//
//  ── ⚠ THIS IS NOT DOCUMENT AUTHENTICATION ──────────────────────────────────
//
//  It proves the text on the page is internally consistent. It does NOT prove
//  the passport is real — no security features are checked, the chip is not
//  read, and a good forgery has a valid MRZ because the checksums are public
//  arithmetic. It also cannot read a UK driving licence, which has no MRZ at
//  all.
//
//  What it is genuinely for: catching the honest mismatch and the lazy fraud.
//  Real authentication is Stripe Identity's job.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// What the document says, when it could be read and verified.
@immutable
class MrzResult {
  const MrzResult({
    required this.found,
    this.surname,
    this.givenNames,
    this.dateOfBirth,
    this.documentNumber,
    this.expiry,
    this.nationality,
    this.checksumsPassed = false,
  });

  /// An MRZ was located. Says nothing about whether it was trustworthy.
  final bool found;

  final String? surname;
  final String? givenNames;
  final DateTime? dateOfBirth;
  final String? documentNumber;
  final DateTime? expiry;
  final String? nationality;

  /// Every check digit that was tested matched.
  ///
  /// ⚠ NOTHING SHOULD BE COMPARED AGAINST A USER'S TYPING UNLESS THIS IS TRUE.
  /// See the header — a bad read produces a mismatch we caused.
  final bool checksumsPassed;

  static const MrzResult none = MrzResult(found: false);
}

/// How the document compares with what the applicant typed.
enum MrzMatch {
  /// No MRZ, or one that failed its own checksums. Not the applicant's problem.
  notChecked,

  /// Everything tested agrees.
  agrees,

  /// Something differs. The screen shows WHAT, and lets them correct it.
  differs,

  /// The document has expired.
  expired,
}

class MrzCheck {
  const MrzCheck({
    required this.match,
    required this.mrz,
    this.nameNote,
    this.dobNote,
  });

  final MrzMatch match;
  final MrzResult mrz;
  final String? nameNote;
  final String? dobNote;

  bool get isProblem => match == MrzMatch.differs || match == MrzMatch.expired;
}

class MrzReader {
  MrzReader._();

  /// ICAO 9303 weights, repeating 7-3-1 across the field.
  static const List<int> _weights = <int>[7, 3, 1];

  /// Reads a passport photograph and, when the MRZ verifies, compares it with
  /// the details the applicant entered.
  ///
  /// ⚠ NEVER THROWS. A failure to read is [MrzMatch.notChecked] — this must not
  /// be able to block somebody from finishing their verification because a
  /// model would not load on their handset. The app assists; the admin judges.
  static Future<MrzCheck> checkPassport({
    required String imagePath,
    required String typedFirstName,
    required String typedLastName,
    required DateTime? typedDob,
  }) async {
    final MrzResult mrz = await read(imagePath);
    if (!mrz.found || !mrz.checksumsPassed) {
      return MrzCheck(match: MrzMatch.notChecked, mrz: mrz);
    }

    // Expiry first — an expired passport is a fact about the document, not a
    // disagreement with the applicant, and saying "your name does not match"
    // to somebody whose passport simply ran out would send them hunting for
    // the wrong problem.
    if (mrz.expiry != null && mrz.expiry!.isBefore(DateTime.now())) {
      return MrzCheck(match: MrzMatch.expired, mrz: mrz);
    }

    String? nameNote;
    String? dobNote;

    if (mrz.surname != null && typedLastName.trim().isNotEmpty) {
      if (!_looseNameMatch(mrz.surname!, typedLastName)) {
        nameNote = 'The passport shows the surname '
            '"${_titleCase(mrz.surname!)}".';
      }
    }
    if (nameNote == null &&
        mrz.givenNames != null &&
        typedFirstName.trim().isNotEmpty) {
      // ⚠ FIRST GIVEN NAME ONLY. A passport carries every given name; people
      // type the one they use. Requiring all of them would flag a majority of
      // honest applicants — which would train whoever reviews these to ignore
      // the warning, and then it catches nothing.
      final String first = mrz.givenNames!.split(' ').first;
      if (!_looseNameMatch(first, typedFirstName)) {
        nameNote = 'The passport shows the first name '
            '"${_titleCase(first)}".';
      }
    }

    if (mrz.dateOfBirth != null && typedDob != null) {
      final DateTime a = mrz.dateOfBirth!;
      if (a.year != typedDob.year ||
          a.month != typedDob.month ||
          a.day != typedDob.day) {
        dobNote = 'The passport shows '
            '${a.day.toString().padLeft(2, '0')}/'
            '${a.month.toString().padLeft(2, '0')}/${a.year}.';
      }
    }

    return MrzCheck(
      match: (nameNote == null && dobNote == null)
          ? MrzMatch.agrees
          : MrzMatch.differs,
      mrz: mrz,
      nameNote: nameNote,
      dobNote: dobNote,
    );
  }

  /// Finds and parses the MRZ. Returns [MrzResult.none] if there is not one.
  static Future<MrzResult> read(String imagePath) async {
    TextRecognizer? recognizer;
    try {
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText result =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));

      // The MRZ is the only place on a passport where a line is 44 characters
      // of A-Z, 0-9 and '<'. Looking for that shape is far more reliable than
      // looking at the bottom of the image, because people photograph passports
      // at every angle and crop.
      final List<String> candidates = <String>[];
      for (final TextBlock b in result.blocks) {
        for (final TextLine l in b.lines) {
          final String s =
              l.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9<]'), '');
          if (s.length >= 40 && s.contains('<')) candidates.add(s);
        }
      }
      if (candidates.length < 2) return MrzResult.none;

      // Take the last two of the right shape — on a TD3 passport the MRZ is
      // two lines and nothing else on the page looks like this.
      final String l1 = _pad44(candidates[candidates.length - 2]);
      final String l2 = _pad44(candidates[candidates.length - 1]);

      return _parseTd3(l1, l2);
    } catch (e) {
      // Model missing, unsupported device, unreadable file. Say nothing and
      // let the admin look at the picture — see the header.
      debugPrint('MrzReader: could not read — $e');
      return MrzResult.none;
    } finally {
      try {
        await recognizer?.close();
      } catch (_) {}
    }
  }

  static String _pad44(String s) =>
      s.length >= 44 ? s.substring(0, 44) : s.padRight(44, '<');

  static MrzResult _parseTd3(String l1, String l2) {
    // Line 1: P<ISSUER SURNAME<<GIVEN<NAMES<<<...
    final int sep = l1.indexOf('<<');
    if (sep < 5) return MrzResult.none;
    final String namePart = l1.substring(5);
    final List<String> halves = namePart.split('<<');
    final String surname = halves.first.replaceAll('<', ' ').trim();
    final String given = halves.length > 1
        ? halves[1].replaceAll('<', ' ').trim().replaceAll(RegExp(r'\s+'), ' ')
        : '';

    // Line 2 is fixed width, which is the whole point of the format.
    final String docNum = l2.substring(0, 9).replaceAll('<', '');
    final String docChk = l2.substring(9, 10);
    final String nationality = l2.substring(10, 13).replaceAll('<', '');
    final String dob = l2.substring(13, 19);
    final String dobChk = l2.substring(19, 20);
    final String exp = l2.substring(21, 27);
    final String expChk = l2.substring(27, 28);

    // ⚠ ALL THREE MUST PASS. Any one failing means the line was misread, and a
    // misread line produces a plausible wrong name — the worst possible output
    // for something that gets compared against a person's own typing.
    final bool ok = _checkDigit(l2.substring(0, 9)) == docChk &&
        _checkDigit(dob) == dobChk &&
        _checkDigit(exp) == expChk;

    return MrzResult(
      found: true,
      surname: surname.isEmpty ? null : surname,
      givenNames: given.isEmpty ? null : given,
      documentNumber: docNum.isEmpty ? null : docNum,
      nationality: nationality.isEmpty ? null : nationality,
      dateOfBirth: _yymmdd(dob, past: true),
      expiry: _yymmdd(exp, past: false),
      checksumsPassed: ok,
    );
  }

  /// ICAO 9303 check digit: 7-3-1 weighting, letters as A=10..Z=35, '<' as 0.
  static String _checkDigit(String field) {
    int sum = 0;
    for (int i = 0; i < field.length; i++) {
      final String ch = field[i];
      int v;
      if (ch == '<') {
        v = 0;
      } else if (RegExp(r'[0-9]').hasMatch(ch)) {
        v = int.parse(ch);
      } else {
        v = ch.codeUnitAt(0) - 55; // 'A' is 65 -> 10
      }
      sum += v * _weights[i % 3];
    }
    return (sum % 10).toString();
  }

  /// YYMMDD with no century in it — the format simply does not carry one.
  ///
  /// ⚠ THE PIVOT IS THE ONLY HONEST GUESS AVAILABLE. A birth date must be in
  /// the past, so a two digit year later than this year is the previous
  /// century. An expiry must be ahead, so it is not. Getting this backwards
  /// would age somebody by a hundred years and refuse them.
  static DateTime? _yymmdd(String s, {required bool past}) {
    if (s.length != 6 || !RegExp(r'^\d{6}$').hasMatch(s)) return null;
    final int yy = int.parse(s.substring(0, 2));
    final int mm = int.parse(s.substring(2, 4));
    final int dd = int.parse(s.substring(4, 6));
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;

    final int nowYy = DateTime.now().year % 100;
    final int century = past
        ? (yy > nowYy ? 1900 : 2000)
        : (yy < nowYy ? 2100 : 2000);
    final DateTime d = DateTime(century + yy, mm, dd);
    // DateTime rolls 31 February forward silently. Reading the parts back is
    // the only way to know the date is the date.
    if (d.month != mm || d.day != dd) return null;
    return d;
  }

  /// ⚠ DELIBERATELY FORGIVING. Accents, hyphens, spacing and case all differ
  /// between a passport's MRZ — which is stripped to plain A-Z — and what
  /// somebody types on a phone. O'Brien is OBRIEN in the MRZ; Muller is
  /// MUELLER. Comparing strictly would flag honest people constantly and the
  /// warning would stop being read.
  static bool _looseNameMatch(String a, String b) {
    String clean(String s) => s
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');
    final String x = clean(a);
    final String y = clean(b);
    if (x.isEmpty || y.isEmpty) return true; // nothing to disagree about
    return x == y || x.startsWith(y) || y.startsWith(x);
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((String w) => w.isEmpty
          ? w
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}
