import 'package:flutter/widgets.dart';

/// `await` sonrası [BuildContext] ile işlem yapmadan önce kullanın.
void guardContext(BuildContext context, VoidCallback fn) {
  if (context.mounted) {
    fn();
  }
}
