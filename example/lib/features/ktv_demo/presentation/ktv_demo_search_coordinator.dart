import 'package:flutter/material.dart';

class KtvDemoSearchCoordinator {
  KtvDemoSearchCoordinator({required ValueChanged<String> onQueryChanged})
    : _onQueryChanged = onQueryChanged {
    controller.addListener(_handleTextChanged);
  }

  final TextEditingController controller = TextEditingController();
  final ValueChanged<String> _onQueryChanged;
  bool _isSyncingFromState = false;

  void syncFromQuery(String query) {
    if (controller.text == query) {
      return;
    }
    _isSyncingFromState = true;
    controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _isSyncingFromState = false;
  }

  void appendToken(String token) {
    final String nextText = '${controller.text}$token';
    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  void removeLastCharacter() {
    if (controller.text.isEmpty) {
      return;
    }
    final String nextText = controller.text.substring(
      0,
      controller.text.length - 1,
    );
    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  void clear() {
    if (controller.text.isEmpty) {
      return;
    }
    controller.clear();
  }

  void dispose() {
    controller
      ..removeListener(_handleTextChanged)
      ..dispose();
  }

  void _handleTextChanged() {
    if (_isSyncingFromState) {
      return;
    }
    _onQueryChanged(controller.text);
  }
}
