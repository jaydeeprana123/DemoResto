class ZomatoOrderUtils {
  ZomatoOrderUtils._();

  static const sourceZomato = 'ZOMATO';

  static const statuses = [
    'Pending',
    'Preparing',
    'Ready',
    'Completed',
  ];

  static bool isZomatoSource(String? source) =>
      source?.trim().toUpperCase() == sourceZomato;

  static bool isZomatoOrderName(String name) =>
      name.trim().toLowerCase().startsWith('zomato');

  static bool isZomatoDoc(Map<String, dynamic> data) =>
      isZomatoSource(data['source']?.toString()) ||
      isZomatoOrderName(data['name']?.toString() ?? '');

  static String normalizeStatus(String? status) {
    final value = status?.trim();
    if (value == null || value.isEmpty) return statuses.first;
    for (final option in statuses) {
      if (option.toLowerCase() == value.toLowerCase()) return option;
    }
    return statuses.first;
  }

  static bool isCompletedStatus(String? status) =>
      normalizeStatus(status) == 'Completed';

  static String statusColorHex(String? status) {
    switch (normalizeStatus(status)) {
      case 'Preparing':
        return '#F57C35';
      case 'Ready':
        return '#2E7D32';
      case 'Completed':
        return '#6B7280';
      default:
        return '#E53935';
    }
  }
}
