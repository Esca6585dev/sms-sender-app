class SmsSendCoordinator {
  final Set<String> _inFlightPhones = <String>{};

  bool isPhoneInFlight(String phone) {
    return _inFlightPhones.contains(phone.trim());
  }

  Future<bool> runPhoneSend(String phone, Future<bool> Function() action) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) {
      return false;
    }

    if (_inFlightPhones.contains(normalizedPhone)) {
      return false;
    }

    _inFlightPhones.add(normalizedPhone);

    try {
      return await action();
    } finally {
      _inFlightPhones.remove(normalizedPhone);
    }
  }

  void clear() {
    _inFlightPhones.clear();
  }
}
