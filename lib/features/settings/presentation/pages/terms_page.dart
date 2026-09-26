import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../widgets/legal_document_page.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentPage(
      title: 'Terms of Service',
      updatedOn: 'September 2026',
      sections: [
        (
          heading: 'Using the app',
          body: '${AppStrings.appName} identifies paintings from photos you provide and generates informational '
              'content about them. Results are AI-generated and may occasionally be inaccurate — use the "Wrong '
              'ID?" option to help us improve.',
        ),
        (
          heading: 'Free and Pro plans',
          body: 'The free plan includes a limited number of scans per day. Pro is billed through your app store '
              'account as a monthly or annual subscription and can be managed or cancelled from your device '
              'settings at any time.',
        ),
        (
          heading: 'Acceptable use',
          body: "Don't use the app to scan or generate content for copyrighted material you don't have rights to "
              "distribute, or to attempt to disrupt or reverse-engineer the identification service.",
        ),
        (
          heading: 'Changes to these terms',
          body: "We may update these terms as the app evolves. Continued use after an update means you accept "
              "the revised terms.",
        ),
      ],
    );
  }
}
