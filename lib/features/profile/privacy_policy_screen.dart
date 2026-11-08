import 'package:flutter/material.dart';

import 'legal_page.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key, this.isModal = false});

  final bool isModal;

  @override
  Widget build(BuildContext context) {
    return LegalPage(
      isModal: isModal,
      title: 'Privacy Policy',
      subtitle: 'Last updated: November 9, 2026',
      introIcon: Icons.privacy_tip_outlined,
      introTitle: 'What we collect, and why.',
      introBody: const [
        'IDireksyon helps residents understand Philippine government ID '
            'requirements, keep track of their IDs and documents, and plan '
            'the steps for getting them. This policy explains what the app '
            'collects and how it is used.',
        'IDireksyon is an independent academic project developed by GeoBytes. '
            'It is not an official government app and is not affiliated with, '
            'endorsed by, or operated by any government agency.',
      ],
      groups: const [
        LegalGroup('WHAT THE APP COLLECTS', [
          LegalSection(
            icon: Icons.badge_outlined,
            title: 'Information you give us',
            body: [
              LegalBullets([
                LegalItem(
                  'your email address or mobile number, and your password, '
                  'which is stored in hashed form, not as readable text.',
                  lead: 'Account details',
                ),
                LegalItem(
                  'your name, birth date, and barangay.',
                  lead: 'Profile details',
                ),
                LegalItem(
                  'the items you mark as already having in your inventory.',
                  lead: 'IDs and documents you own',
                ),
                LegalItem(
                  'your target IDs, journey plan, choices, completed steps, '
                  'and the requirements you mark as prepared.',
                  lead: 'Roadmap and journey progress',
                ),
              ]),
              LegalParagraph(
                'The app does not ask you to upload copies of your IDs or '
                'documents, and does not ask for their ID numbers.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.location_on_outlined,
            title: 'Location',
            body: [
              LegalParagraph(
                'Office Finder can use your device\'s location to show '
                'offices near you and to get directions. The app asks for '
                'permission first, and only uses location while you are '
                'using the app. It may ask when you tap "Use my current '
                'location", request directions, or start typing in the '
                'Office Finder search. You can decline and still browse '
                'offices.',
              ),
              LegalParagraph(
                'When you request directions inside Office Finder, the app '
                'sends your current location and the office\'s location to '
                'the IDireksyon server so a route can be calculated with '
                'Google Maps Platform. Your location is not saved to your '
                'IDireksyon account.',
              ),
              LegalParagraph(
                'The Get Directions option on ID and document pages opens '
                'Google Maps with the office as the destination.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.account_circle_outlined,
            title: 'Profile photo',
            body: [
              LegalParagraph(
                'If you add a profile photo, it stays on your device and is '
                'not uploaded to IDireksyon\'s servers. You can change or '
                'remove it in the app.',
              ),
            ],
          ),
        ]),
        LegalGroup('HOW IT IS USED', [
          LegalSection(
            icon: Icons.tune_rounded,
            title: 'How we use your information',
            body: [
              LegalParagraph(
                'We use this information to run your account, save your '
                'inventory and journey progress, and show guidance based on '
                'what you enter. We also use your email address to send '
                'sign-up verification codes and password reset links.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.hub_outlined,
            title: 'Services we use',
            body: [
              LegalBullets([
                LegalItem(
                  'hosts the IDireksyon server and database, where your '
                  'account information is stored.',
                  lead: 'Railway',
                ),
                LegalItem(
                  'provides the maps, office locations, and directions. '
                  'Google handles information it receives under its own '
                  'privacy policy.',
                  lead: 'Google Maps Platform',
                ),
                LegalItem(
                  'delivers verification and password reset emails, and '
                  'receives your email address for that purpose.',
                  lead: 'Resend',
                ),
              ]),
              LegalParagraph(
                'Our hosting provider may keep technical request records, '
                'such as IP addresses and access times, as part of running '
                'the service.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.block_rounded,
            title: 'We do not sell your data',
            body: [
              LegalParagraph(
                'IDireksyon does not sell your personal information. The app '
                'does not contain advertising or analytics SDKs.',
              ),
            ],
          ),
        ]),
        LegalGroup('YOUR DATA AND CHOICES', [
          LegalSection(
            icon: Icons.lock_outline_rounded,
            title: 'How your information is protected',
            body: [
              LegalParagraph(
                'The app connects to the production IDireksyon server over '
                'HTTPS. Your sign-in session is kept in your device\'s '
                'secure storage and expires after 30 days. No app or service '
                'can guarantee complete security, so please keep your '
                'password private.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.delete_outline_rounded,
            title: 'Keeping and deleting your information',
            body: [
              LegalParagraph(
                'Your account information stays saved until your account is '
                'deleted. You can edit your details, update your inventory, '
                'change your password, or permanently delete your account in '
                'Profile > Password & security. Deletion happens right away '
                'and cannot be undone.',
              ),
              LegalParagraph(
                'Technical records and backups held by our hosting provider '
                'follow that provider\'s own practices.',
              ),
              LegalParagraph(
                'If you cannot log in, see '
                'www.idireksyon.online/account-deletion for how to request '
                'deletion.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.update_rounded,
            title: 'Changes to this policy',
            body: [
              LegalParagraph(
                'We may update this policy as the app changes. The date at '
                'the top shows the latest version.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.mail_outline_rounded,
            title: 'Contact',
            body: [
              LegalParagraph(
                'The contact email for GeoBytes is published at '
                'www.idireksyon.online/privacy.',
              ),
            ],
          ),
        ]),
      ],
    );
  }
}
