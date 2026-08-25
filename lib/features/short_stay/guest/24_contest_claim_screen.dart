// ─────────────────────────────────────────────────────────────────────────────
//  Dispute a damage claim.
//
//  Rewritten 25 August 2026. Was Stitch output from 3 August, never wired.
//
//  ── ⚠ WHY THE REASON IS COMPULSORY, AND WHY THAT IS NOT A HURDLE ────────────
//
//  respondToStayClaim refuses a dispute with fewer than ten characters. That
//  looks like friction placed in front of the person defending themselves,
//  which would be indefensible — so the reasoning matters.
//
//  An admin deciding a claim is holding the host's account of what happened,
//  usually several paragraphs, alongside their photographs. If the other side
//  of that file says only "disputed", the host's version is the only version
//  with any content in it, and it wins on the page whether or not it is true.
//
//  The requirement is not there to make disputing harder. It is there to make
//  the dispute ANSWERABLE. This screen says so, in those words, rather than
//  showing a validation error and leaving them to guess.
//
//  ── WHAT THIS SCREEN DELIBERATELY DOES NOT DO ───────────────────────────────
//
//  No photo upload. The guest's evidence was captured at arrival and frozen to
//  the claim already — that is the whole point of the capture flow. Inviting
//  them to add photographs now would suggest that pictures taken after they
//  left carry the same weight, and would leave anyone who did not take any
//  believing they had lost by default.
//
//  ⚠ IT DOES NOT PROMISE AN OUTCOME. "We will review this" is the truth.
//  "You will not be charged" is not ours to say before an admin has looked.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/stay_claim_service.dart';
import '../theme/stay_colors.dart';

class ContestClaimScreen extends StatefulWidget {
  const ContestClaimScreen({super.key, this.claimId});

  final String? claimId;

  @override
  State<ContestClaimScreen> createState() => _ContestClaimScreenState();
}

class _ContestClaimScreenState extends State<ContestClaimScreen> {
  final TextEditingController _reason = TextEditingController();
  bool _busy = false;
  String _error = '';
  String _id = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠ A MAP, NOT A BARE STRING — see the note in screen 23. `as String?`
    // here is null on every route in this app, and the failure is silent: the
    // screen renders perfectly and then refuses to send.
    final Map<String, dynamic> args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    _id = widget.claimId ?? (args['claimId'] as String? ?? '');
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final String note = _reason.text.trim();
    if (note.length < 10) {
      setState(() => _error =
          'Please say a little more — a reviewer needs something to weigh '
          'against what your host wrote.');
      return;
    }
    if (_id.isEmpty) {
      setState(() => _error = 'No claim was selected.');
      return;
    }

    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await StayClaimService.instance
          .respond(claimId: _id, accept: false, note: note);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Sent'),
          content: Text(
            'Your host has been told you disagree, and GoOuts will review the '
            'claim with your arrival photos alongside theirs.\n\n'
            'We will let you know the outcome.',
            style: GoogleFonts.inter(fontSize: 13.5, height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK')),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ClaimError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoOutsColors.pageBackground,
      appBar: AppBar(
        backgroundColor: GoOutsColors.cardSurface,
        elevation: 0,
        foregroundColor: GoOutsColors.deepNavy,
        title: Text('Tell us why',
            style:
                GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: <Widget>[
          Text(
            'What happened?',
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: GoOutsColors.deepNavy),
          ),
          const SizedBox(height: 8),
          Text(
            // The honest explanation of the ten character minimum. See header.
            'Your arrival photos are already attached to this claim. What a '
            'reviewer does not have is your side of it — so tell them what you '
            'remember, even briefly.',
            style: GoogleFonts.inter(
                fontSize: 13.5, height: 1.55, color: GoOutsColors.bodyText),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _reason,
            maxLines: 8,
            maxLength: 4000,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'For example: the mark was already there when I '
                  'arrived, or nobody used that room during my stay.',
              hintStyle: GoogleFonts.inter(
                  fontSize: 13, color: GoOutsColors.textVariant),
              filled: true,
              fillColor: GoOutsColors.cardSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.45,
                      color: const Color(0xFFB91C1C))),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : _send,
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
                  : Text('Send my response',
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A person at GoOuts reads every disputed claim. Nothing is settled '
            'automatically.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 11.5, height: 1.45, color: GoOutsColors.textVariant),
          ),
        ],
      ),
    );
  }
}
