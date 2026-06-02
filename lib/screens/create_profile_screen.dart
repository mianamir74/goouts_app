import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  bool _hasPhoto = false;
  File? _profileImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
        _hasPhoto = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0392CA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // ── Header ─────────────────────────────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    'GoOuts',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Step indicator ─────────────────────────────────────────
              _buildStepIndicator(),

              const SizedBox(height: 24),

              // ── Title ──────────────────────────────────────────────────
              Text(
                'Set Up Your Profile',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a profile photo to personalise your account.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // ── Profile Picture ────────────────────────────────────────
              _label('Profile Picture'),
              const SizedBox(height: 6),
              Text(
                'Optional — you can add one later from your profile.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white.withOpacity(0.65)),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _hasPhoto
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: _profileImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(_profileImage!, fit: BoxFit.cover),
                              Container(
                                color: Colors.black.withOpacity(0.25),
                              ),
                              Center(
                                child: Text(
                                  'Tap to change',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_a_photo_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Upload from Gallery',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'JPG or PNG supported',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Info card ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your identity will be verified in the next step. Make sure your details match your official ID.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Continue button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                      context, '/create-profile-expanded'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0392CA),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Skip for now ───────────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(
                      context, '/create-profile-expanded'),
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );

  Widget _buildStepIndicator() => Row(
        children: [
          _stepDot(1, active: true, done: false),
          _stepLine(active: false),
          _stepDot(2, active: false, done: false),
        ],
      );

  Widget _stepDot(int step, {required bool active, required bool done}) =>
      Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: active || done
                  ? Colors.white
                  : Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check_rounded,
                      color: Color(0xFF0392CA), size: 16)
                  : Text(
                      '$step',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? const Color(0xFF0392CA)
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            step == 1 ? 'Profile Photo' : 'Your Details',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color:
                  active ? Colors.white : Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      );

  Widget _stepLine({required bool active}) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: active ? Colors.white : Colors.white.withOpacity(0.25),
        ),
      );
}
