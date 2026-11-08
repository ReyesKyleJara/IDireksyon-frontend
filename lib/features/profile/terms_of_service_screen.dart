import 'package:flutter/material.dart';

import 'legal_page.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key, this.isModal = false});

  final bool isModal;

  @override
  Widget build(BuildContext context) {
    return LegalPage(
      isModal: isModal,
      title: 'Terms of Service',
      subtitle: 'Last updated: November 9, 2026',
      introIcon: Icons.article_outlined,
      introTitle: 'A guide, not a government service.',
      introBody: const [
        'These terms explain what IDireksyon does, what it does not do, and '
            'what we expect when you use it. By creating an account, you '
            'agree to them.',
        'Official government agencies remain the authority on ID '
            'requirements and applications.',
      ],
      groups: const [
        LegalGroup('ABOUT IDIREKSYON', [
          LegalSection(
            icon: Icons.explore_outlined,
            title: 'What IDireksyon is',
            body: [
              LegalParagraph(
                'IDireksyon is an independent academic project developed by '
                'GeoBytes. It helps you understand Philippine government ID '
                'requirements, keep track of the IDs and documents you '
                'have, plan which ones to prepare, and find relevant '
                'offices.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.menu_book_outlined,
            title: 'Informational guidance only',
            body: [
              LegalParagraph(
                'Everything in the app is for information and preparation. '
                'Roadmaps and suggestions are based on what you enter and '
                'are meant to help you get ready. They are not official '
                'advice or a decision about your application.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.account_balance_outlined,
            title: 'Not an official government service',
            body: [
              LegalParagraph(
                'IDireksyon is not affiliated with, endorsed by, or operated '
                'by any government agency. The app does not:',
              ),
              LegalBullets([
                LegalItem('issue government IDs or documents'),
                LegalItem('submit or process applications'),
                LegalItem('accept payments'),
                LegalItem('book appointments'),
              ]),
            ],
          ),
        ]),
        LegalGroup('THE INFORMATION IN THE APP', [
          LegalSection(
            icon: Icons.published_with_changes_rounded,
            title: 'Information can change',
            body: [
              LegalParagraph(
                'Requirements, fees, office locations and schedules, and '
                'procedures are set by government agencies and can change '
                'at any time. Information in the app may not always reflect '
                'the latest updates.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.verified_outlined,
            title: 'Check with official sources',
            body: [
              LegalParagraph(
                'Before you apply, pay, or travel to an office, confirm the '
                'important details with the relevant agency through its '
                'official website, hotline, or office.',
              ),
            ],
          ),
        ]),
        LegalGroup('YOUR ACCOUNT', [
          LegalSection(
            icon: Icons.person_outline_rounded,
            title: 'Your responsibilities',
            body: [
              LegalBullets([
                LegalItem('Provide accurate information about yourself.'),
                LegalItem(
                  'Keep your password private, and use your account only '
                  'for yourself.',
                ),
                LegalItem(
                  'Review your own documents and complete official '
                  'applications with the relevant agency.',
                ),
              ]),
            ],
          ),
          LegalSection(
            icon: Icons.rule_rounded,
            title: 'Acceptable use',
            body: [
              LegalParagraph('When using IDireksyon, please do not:'),
              LegalBullets([
                LegalItem('use the app for anything unlawful or fraudulent'),
                LegalItem(
                  'access or try to access another person\'s account',
                ),
                LegalItem(
                  'interfere with the app or its servers, or try to get '
                  'around its security',
                ),
                LegalItem(
                  'present IDireksyon or its content as an official '
                  'government service',
                ),
              ]),
            ],
          ),
          LegalSection(
            icon: Icons.delete_outline_rounded,
            title: 'Deleting or ending an account',
            body: [
              LegalParagraph(
                'You can permanently delete your account at any time in '
                'Profile > Password & security. Deletion happens right away '
                'and cannot be undone. If you cannot log in, see '
                'www.idireksyon.online/account-deletion.',
              ),
            ],
          ),
        ]),
        LegalGroup('LIMITS OF THE APP', [
          LegalSection(
            icon: Icons.info_outline_rounded,
            title: 'What we cannot guarantee',
            body: [
              LegalParagraph(
                'Using IDireksyon does not guarantee eligibility, approval, '
                'or the issuance of any ID or document. Those decisions '
                'belong to the government agency concerned.',
              ),
              LegalParagraph(
                'The app is provided as it is. To the extent allowed by '
                'law, GeoBytes is not responsible for losses that result '
                'from relying on information in the app without confirming '
                'it with official sources.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.open_in_new_rounded,
            title: 'External services',
            body: [
              LegalParagraph(
                'Some features open map services or government websites. '
                'These are run independently and have their own terms and '
                'privacy practices.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.cloud_outlined,
            title: 'Availability',
            body: [
              LegalParagraph(
                'Some features need an internet connection. As an academic '
                'project, IDireksyon may go through testing, maintenance, '
                'or changes, and some functions may not always be '
                'available.',
              ),
            ],
          ),
          LegalSection(
            icon: Icons.update_rounded,
            title: 'Changes to these terms',
            body: [
              LegalParagraph(
                'These terms may be updated as the app changes. The date at '
                'the top shows the latest version.',
              ),
            ],
          ),
        ]),
      ],
    );
  }
}
