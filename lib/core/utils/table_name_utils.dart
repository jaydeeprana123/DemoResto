/// Dining tables use names like "Table 1". Any other name is treated as take-away.
bool isTakeAwayOrderName(String name) => !name.contains('Table');

bool isDiningTableName(String name) => name.contains('Table');
