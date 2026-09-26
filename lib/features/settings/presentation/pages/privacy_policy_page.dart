import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../widgets/legal_document_page.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentPage(
      title: 'Privacy Policy',
      updatedOn: 'September 2026',
      sections: [
        (
          heading: 'What we collect',
          body: 'When you scan a painting, we process the photo you take or upload to identify the artwork. We '
              'also store your scan history, saved paintings, and depth-level preference so ${AppStrings.appName} '
              'can work the way you expect.',
        ),
        (
          heading: 'How we use it',
          body: "Photos are sent to our identification service only to generate a result and are not used to "
              "train models or shared with advertisers. Your scan history stays tied to your device or account "
              "so you can revisit it in Collection.",
        ),
        (
          heading: 'Your choices',
          body: 'You can delete any saved painting from your Collection at any time, and clearing app data '
              'removes your local scan history. Contact support if you would like your account data removed '
              'entirely.',
        ),
        (
          heading: 'Contact us',
          body: 'Questions about this policy can be sent to ryan@veradostudio.com.',
        ),
      ],
    );
  }
}
