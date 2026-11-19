import 'package:material_ui/material_ui.dart';

import 'theme.dart';
import 'widgets/common.dart';

/// Behaviour check (report Table 4.4 screens 4 and 5). Built in stage 5.
class CheckScreen extends StatelessWidget {
  const CheckScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Behaviour check')),
        body: ListView(padding: const EdgeInsets.all(Tokens.space4), children: const [
          EmptyState(
            icon: Icons.mic_none,
            title: 'Behaviour check',
            body: 'Record 10 seconds of your pet\'s sounds to see their likely emotion. Coming next.',
          ),
        ]),
      );
}
