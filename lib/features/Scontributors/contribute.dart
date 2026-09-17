import 'package:flutter/material.dart';
import 'package:navi_sante/core/utils/language_cubit/app_translations.dart';


class ContributeScreen extends StatelessWidget {
  const ContributeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Contribute to the community', 'Contribuez à la communauté'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
          ),
        ],
      ),
    );
  }
}
