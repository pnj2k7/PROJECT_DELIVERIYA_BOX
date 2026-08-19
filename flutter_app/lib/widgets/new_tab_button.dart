import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the current app URL in a brand-new browser tab. Only rendered
/// on web (there's no concept of "a new tab" on mobile).
///
/// IMPORTANT LIMITATION: on web, Firebase Auth and the AppSession are
/// both persisted to the browser's local storage, which is SHARED
/// across every tab of the same browser on the same origin. That
/// means opening a new tab does NOT give you an independently logged
/// in second session — both tabs will reflect whichever account most
/// recently signed in. To genuinely watch the sender view and the
/// customer view live at the same time, open one of them in a
/// separate browser (or an Incognito/Private window), not just a
/// second tab of the same browser.
class NewTabButton extends StatelessWidget {
  const NewTabButton({super.key});

  Future<void> _open() async {
    final uri = Uri.base;
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.open_in_new_rounded),
      tooltip: 'Open in new tab',
      onPressed: () {
        _open();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Opened a new tab. Note: on web, both tabs share the same '
              'login — use a separate browser window (or Incognito) to '
              'watch sender + customer live at the same time.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      },
    );
  }
}
