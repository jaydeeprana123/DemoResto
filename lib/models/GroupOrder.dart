/// TableGroup
/// 
/// Represents a structured grouping of ordered items under a particular table or takeaway order
/// along with their timeline metadata and active order attributes.
class TableGroup {
  final String tableName;
  final List<Map<String, dynamic>> items;
  final int groupTime;
  final String key;
  final String docId;
  final bool isPaid;

  TableGroup(
    this.tableName,
    this.items,
    this.groupTime, {
    this.key = '',
    this.docId = '',
    this.isPaid = false,
  });
}
