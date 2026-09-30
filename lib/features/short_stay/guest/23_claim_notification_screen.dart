// ─────────────────────────────────────────────────────────────────────────────
//  A claim has been made against your stay.
//
//  Rewritten 25 August 2026. Was Stitch output from 3 August, never wired —
//  every handler empty, no service behind it.
//
//  ── ⚠ WHAT THIS SCREEN OWES THE PERSON READING IT ───────────────────────────
//
//  Somebody has asked for up to £150 of their money and said they broke
//  something. This is the only place they find out, and the only place they can
//  answer. It is written on the assumption that they might be innocent.
//
//  So:
//
//    THE HOST'S CASE IS SHOWN IN FULL — the amount, what they wrote, and their
//    photographs. Summarising it would mean deciding for the guest which parts
//    matter.
//
//    THEIR OWN EVIDENCE IS SHOWN NEXT TO IT. The arrival photographs frozen to
//    the claim, on the same screen, at the same size. This is the moment the
//    capture flow they were asked to complete either protects them or does not,
//    and they should be able to see which.
//
//    ⚠ SKIPPED ROOMS ARE SHOWN TOO. It would be easy to hide them — they weaken
//    the guest's position. Hiding them would mean the record an admin reads and
//    the record the guest reads are different documents, and the guest would be
//    arguing without knowing what was in front of the person deciding.
//
//    DISPUTING IS AS PROMINENT AS ACCEPTING. Not buried, not greyed, not a text
//    link under a large blue button. A screen that makes agreeing easy and
//    disagreeing hard is collecting consent, not asking for it.
//
//  ⚠ NOTHING HERE PROMISES OR THREATENS A PAYMENT. No provider is connected and
//  no deposit is held on any booking. Saying "£150 will be taken" would be
//  false, and saying it to somebody deciding whether to fight a claim would be
//  worse than false.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/stay_claim_service.dart';
import '../stay_routes.dart';
import '../theme/stay_colors.dart';

class ClaimNotificationScreen extends StatelessWidget {
  const ClaimNotificationScreen({super.key, this.claimId});

  final String? claimId;

  @override
  Widget build(BuildContext context) {
    // ⚠ THE FALLBACK READS A MAP TOO. `as String?` here would be null on every
    // route in this app and quietly show "No claim was selected" — the screen
    // would look like it worked and tell the guest nothing exists.
    final Map<String, dynamic> args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    final String id = claimId ?? (args['claimId'] as String? ?? '');

    return Scaffold(
      backgroundColor: GoOutsColors.pageBackground,
      appBar: AppBar(
        backgroundColor: GoOutsColors.cardSurface,
        elevation: 0,
        foregroundColor: GoOutsColors.deepNavy,
        title: Text('Damage claim',
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool desktop = kIsWeb && constraints.maxWidth >= 900;
          final Widget content = id.isEmpty
              ? _centered('No claim was selected.')
              : StreamBuilder<StayClaim?>(
              stream: StayClaimService.instance.watchClaim(id),
              builder: (BuildContext c,
                  AsyncSnapshot<StayClaim?> snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // ⚠ A CLAIM THAT WILL NOT LOAD IS NOT A CLAIM THAT DOES NOT
                // EXIST. Saying "not found" to somebody who was just notified
                // of one would be alarming and probably wrong — the rules only
                // let the two parties read it, so an error here is far more
                // likely to be a signal problem.
                if (snap.hasError) {
                  return _centered(
                      'We could not load this claim just now. Please check '
                      'your connection and try again.');
                }
                final StayClaim? claim = snap.data;
                if (claim == null) {
                  return _centered('This claim is no longer available.');
                }
                return _Body(claim: claim);
              },
            );
          if (!desktop) return content;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: content,
            ),
          );
        },
      ),
    );
  }

  Widget _centered(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(msg,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.55,
                  color: GoOutsColors.textVariant)),
        ),
      );
}

class _Body extends StatefulWidget {
  const _Body({required this.claim});
  final StayClaim claim;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _busy = false;
  String _error = '';

  Future<void> _accept() async {
    // ⚠ CONFIRMED, BECAUSE IT CANNOT BE UNDONE. respondToStayClaim refuses a
    // second response — the status has moved on. A mis-tap here is somebody
    // agreeing to a £150 charge they meant to contest.
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Accept this claim?'),
        content: Text(
          'You are agreeing that the damage described happened during your '
          'stay. You will not be able to dispute it afterwards.\n\n'
          'GoOuts still reviews every claim before anything is settled.',
          style: GoogleFonts.inter(fontSize: 13.5, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Go back')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Accept')),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await StayClaimService.instance
          .respond(claimId: widget.claim.id, accept: true);
      if (!mounted) return;
      setState(() => _busy = false);
    } on ClaimError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  void _dispute() {
    // ⚠ A MAP, NOT A BARE STRING. StayRoutes.onGenerateRoute reads
    // (settings.arguments as Map<String, dynamic>)['claimId'] — a plain string
    // casts to null silently and the dispute screen opens with no claim on it,
    // then refuses to send with "No claim was selected". The host app uses bare
    // strings; this one does not. Two apps, two conventions.
    Navigator.of(context).pushNamed(
      StayRoutes.contestClaim,
      arguments: <String, dynamic>{'claimId': widget.claim.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    final StayClaim c = widget.claim;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: <Widget>[
        _statusBanner(c),
        const SizedBox(height: 18),

        _amountCard(c),
        const SizedBox(height: 18),

        _heading('What your host says'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: GoOutsColors.cardSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            c.description.isEmpty ? 'No description was given.' : c.description,
            style: GoogleFonts.inter(
                fontSize: 13.5, height: 1.55, color: GoOutsColors.bodyText),
          ),
        ),

        if (c.hostPhotoUrls.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          _heading('Their photos'),
          const SizedBox(height: 8),
          _photoStrip(c.hostPhotoUrls),
        ],

        const SizedBox(height: 22),
        _heading('Your photos from arrival'),
        const SizedBox(height: 6),
        Text(
          c.evidence.isEmpty
              ? 'No arrival photos were taken for this stay, so there is '
                  'nothing on your side of the record.'
              : 'These were frozen when the claim was made and cannot be '
                  'changed by anyone, including us.',
          style: GoogleFonts.inter(
              fontSize: 13.5, height: 1.45, color: GoOutsColors.textVariant),
        ),
        const SizedBox(height: 10),
        _evidenceList(c),

        const SizedBox(height: 26),
        if (_error.isNotEmpty) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_error,
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.45,
                    color: const Color(0xFFB91C1C))),
          ),
          const SizedBox(height: 16),
        ],
        if (c.needsReply) _actions() else _alreadyAnswered(c),
      ],
    );
  }

  /// ⚠ TWO BUTTONS OF EQUAL WEIGHT. See the header. Disputing is not a
  /// secondary action and must not be styled as one.
  Widget _actions() => Column(
        children: <Widget>[
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _busy ? null : _dispute,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                foregroundColor: GoOutsColors.deepNavy,
                side: const BorderSide(color: GoOutsColors.deepNavy, width: 1.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
              ),
              child: Text('I disagree with this',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : _accept,
              style: ElevatedButton.styleFrom(
                backgroundColor: GoOutsColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('I accept this claim',
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'GoOuts reviews every claim. Nothing is taken from you '
            'automatically.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 12, height: 1.45, color: GoOutsColors.textVariant),
          ),
        ],
      );

  Widget _alreadyAnswered(StayClaim c) {
    final String msg = switch (c.status) {
      GuestClaimStatus.accepted =>
        'You accepted this claim. GoOuts will confirm the outcome.',
      GuestClaimStatus.disputed =>
        'You disputed this claim. GoOuts is reviewing it and will be in touch.',
      GuestClaimStatus.decided => c.decision == 'rejected'
          ? 'This claim was not upheld. Nothing is owed.'
          : '£${c.awarded.toStringAsFixed(2)} was awarded to your host.',
      _ => 'This claim is being reviewed.',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GoOutsColors.paleBlueTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(msg,
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: GoOutsColors.deepNavy)),
          // ⚠ THE REASON IS SHOWN, INCLUDING WHEN THE DECISION WENT AGAINST
          // THEM. A decision with no reason attached is one nobody can question,
          // and this one moved money.
          if ((c.decisionReason ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(c.decisionReason!,
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.5,
                    color: GoOutsColors.bodyText)),
          ],
          if ((c.guestResponseNote ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text('What you told us',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GoOutsColors.textVariant)),
            const SizedBox(height: 2),
            Text(c.guestResponseNote!,
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.5,
                    color: GoOutsColors.bodyText)),
          ],
        ],
      ),
    );
  }

  Widget _statusBanner(StayClaim c) {
    if (!c.needsReply) return const SizedBox.shrink();
    final Duration? left = c.timeLeft;
    final bool overdue = left != null && left.isNegative;
    final int hours = left == null ? 0 : left.inHours.abs();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: overdue ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(overdue ? Icons.warning_amber_rounded : Icons.schedule,
              size: 20,
              color: overdue
                  ? const Color(0xFFB91C1C)
                  : const Color(0xFFC2410C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // ⚠ LATE IS NOT LOCKED OUT, AND IT SAYS SO. respondToStayClaim
              // accepts a late reply on purpose. Telling somebody the deadline
              // passed without telling them they can still answer would stop
              // them answering.
              overdue
                  ? 'The reply window closed $hours hours ago. You can still '
                      'respond, and we will take it into account.'
                  : 'You have about $hours hours to respond.',
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  height: 1.45,
                  color: overdue
                      ? const Color(0xFF991B1B)
                      : const Color(0xFF9A3412)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountCard(StayClaim c) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GoOutsColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Amount claimed',
                style: GoogleFonts.inter(
                    fontSize: 13.5, color: GoOutsColors.textVariant)),
            const SizedBox(height: 4),
            Text('£${c.amount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: GoOutsColors.deepNavy)),
            if (c.depositCapPence > 0) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Out of the £${(c.depositCapPence / 100).toStringAsFixed(2)} '
                'deposit for this booking. A claim can never be more than that.',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: GoOutsColors.textVariant),
              ),
            ],
          ],
        ),
      );

  Widget _evidenceList(StayClaim c) {
    if (c.evidence.isEmpty) return const SizedBox.shrink();
    final List<ClaimEvidence> shots =
        c.evidence.where((ClaimEvidence e) => !e.skipped).toList();
    final List<ClaimEvidence> skipped =
        c.evidence.where((ClaimEvidence e) => e.skipped).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (shots.isNotEmpty)
          _photoStrip(shots.map((ClaimEvidence e) => e.url).toList(),
              captions: shots.map((ClaimEvidence e) => e.room).toList()),
        // ⚠ SHOWN EVEN THOUGH IT WEAKENS THEIR POSITION. See the header — the
        // guest must be reading the same record as the person deciding.
        if (skipped.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            'You skipped ${skipped.length} '
            '${skipped.length == 1 ? 'room' : 'rooms'}: '
            '${skipped.map((ClaimEvidence e) => e.room).join(', ')}. '
            'A reviewer sees this as well.',
            style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.45,
                color: GoOutsColors.textVariant),
          ),
        ],
      ],
    );
  }

  Widget _photoStrip(List<String> urls, {List<String>? captions}) => SizedBox(
        height: captions == null ? 100 : 122,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          separatorBuilder: (BuildContext _, int __) => const SizedBox(width: 10),
          itemBuilder: (BuildContext c, int i) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  urls[i],
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  // A broken image must look broken, not absent. An empty gap
                  // where evidence should be reads as evidence that never
                  // existed.
                  errorBuilder: (_, Object __, StackTrace? ___) => Container(
                    width: 100,
                    height: 100,
                    color: GoOutsColors.paleBlueTint,
                    child: const Icon(Icons.broken_image_outlined,
                        color: GoOutsColors.textVariant),
                  ),
                ),
              ),
              if (captions != null && i < captions.length)
                SizedBox(
                  width: 100,
                  child: Text(captions[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: GoOutsColors.textVariant)),
                ),
            ],
          ),
        ),
      );

  Widget _heading(String s) => Text(s,
      style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: GoOutsColors.deepNavy));
}
