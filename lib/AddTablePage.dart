import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'Styles/my_font.dart';

const _navy = Color(0xFF1A3A5C);
const _navyDk = Color(0xFF0D2137);
const _orange = Color(0xFFf57c35);
const _green = Color(0xFF4CAF50);

class AddTablePage extends StatefulWidget {
  const AddTablePage({super.key});

  @override
  State<AddTablePage> createState() => _AddTablePageState();
}

class _AddTablePageState extends State<AddTablePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _tableNameController = TextEditingController();
  bool _isAdding = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  Future<void> _addTable() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAdding = true);
    try {
      final name = _tableNameController.text.trim();
      await FirebaseFirestore.instance.collection('tables').add({
        'name': name,
        'createdAt': Timestamp.now(),
      });
      _tableNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Table "$name" added')));
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteTable(String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Table',
          style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 18),
        ),
        content: Text(
          "Are you sure you want to delete '$name'?",
          style: const TextStyle(fontFamily: fontMulishRegular, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: fontMulishSemiBold,
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: fontMulishSemiBold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await FirebaseFirestore.instance.collection('tables').doc(docId).delete();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Table "$name" deleted')));
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _tableNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Manage Tables',
          style: TextStyle(
            fontSize: 16,
            fontFamily: fontMulishBold,
            color: Colors.white,
          ),
        ),
      ),
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  Widget _wideLayout() {
    return Row(
      children: [
        Expanded(flex: 5, child: _sidePanel()),
        Expanded(flex: 6, child: _contentPanel()),
      ],
    );
  }

  Widget _narrowLayout() {
    return Column(children: [Expanded(child: _contentPanel())]);
  }

  Widget _sidePanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _navyDk],
        ),
      ),
      child: Stack(
        children: [
          ..._decorCircles(),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Center(child: _tableIllustration()),
                const Spacer(),
                const Text(
                  'Table\nManagement',
                  style: TextStyle(
                    fontSize: 28,
                    fontFamily: fontMulishBold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add and organize dining tables\n'
                  'for your restaurant floor plan.',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: fontMulishRegular,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                Row(children: List.generate(3, (i) => _dot(i == 0))),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBanner() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, _navyDk],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          ..._decorCircles(),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Manage Tables',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: fontMulishBold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          // Positioned(
          //   left: 0,
          //   right: 0,
          //   bottom: 24,
          //   child: Column(
          //     children: [
          //       _tableIllustration(size: 64),
          //       const SizedBox(height: 8),
          //       Text(
          //         'Organize your restaurant floor',
          //         style: TextStyle(
          //           fontSize: 12,
          //           fontFamily: fontMulishRegular,
          //           color: Colors.white.withValues(alpha: 0.8),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _contentPanel() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (MediaQuery.of(context).size.width > 700) ...[
                const Text(
                  'Manage Tables',
                  style: TextStyle(
                    fontSize: 24,
                    fontFamily: fontMulishBold,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add new tables and manage your floor layout',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: fontMulishRegular,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Table Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tableNameController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _addTable(),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a table name'
                          : null,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: fontMulishRegular,
                        color: _navy,
                      ),
                      decoration: _inputDecoration(
                        hint: 'e.g. Table 1, VIP Room',
                        icon: Icons.table_restaurant_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _isAdding
                        ? const Center(
                            child: CircularProgressIndicator(color: _orange),
                          )
                        : _primaryButton(
                            label: 'Add Table',
                            icon: Icons.add_rounded,
                            onTap: _addTable,
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'your tables',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontFamily: fontMulishRegular,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildTablesList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTablesList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tables')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _orange));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.table_restaurant_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 10),
                Text(
                  'No tables found',
                  style: TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add your first table above',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: fontMulishRegular,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        final tables = snapshot.data!.docs;

        return ListView.separated(
          itemCount: tables.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = tables[index];
            final name = doc.data()['name']?.toString() ?? '';
            final isTakeAway = name.contains('Take Away');

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: _navy.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (isTakeAway ? _navy : _orange).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isTakeAway
                        ? Icons.delivery_dining_outlined
                        : Icons.table_restaurant_outlined,
                    color: isTakeAway ? _navy : _orange,
                    size: 22,
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 15,
                    color: _navy,
                  ),
                ),
                subtitle: Text(
                  isTakeAway ? 'Take away' : 'Dining table',
                  style: TextStyle(
                    fontFamily: fontMulishRegular,
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  tooltip: 'Delete table',
                  onPressed: () => _deleteTable(doc.id, name),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _tableIllustration({double size = 120}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi, color: _orange, size: size * 0.2),
              SizedBox(height: size * 0.04),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.table_restaurant,
                    color: Colors.white,
                    size: size * 0.26,
                  ),
                  SizedBox(width: size * 0.05),
                  Container(
                    width: size * 0.18,
                    height: size * 0.18,
                    decoration: const BoxDecoration(
                      color: _orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: size * 0.12,
                    ),
                  ),
                  SizedBox(width: size * 0.05),
                  Icon(Icons.chair_outlined, color: _green, size: size * 0.26),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _decorCircles() {
    return [
      _circle(
        top: -30,
        right: -30,
        size: 140,
        color: Colors.white.withValues(alpha: 0.04),
      ),
      _circle(
        top: 80,
        left: -20,
        size: 80,
        color: _orange.withValues(alpha: 0.12),
      ),
      _circle(
        bottom: 60,
        right: 20,
        size: 60,
        color: _green.withValues(alpha: 0.12),
      ),
      _circle(
        bottom: -20,
        left: 40,
        size: 100,
        color: Colors.white.withValues(alpha: 0.04),
      ),
    ];
  }

  Widget _circle({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  Widget _dot(bool active) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    margin: const EdgeInsets.only(right: 6),
    width: active ? 24 : 8,
    height: 8,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      color: active ? _orange : Colors.white38,
    ),
  );

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontFamily: fontMulishSemiBold,
      color: _navy,
    ),
  );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 13,
        fontFamily: fontMulishRegular,
      ),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontFamily: fontMulishSemiBold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 4,
          shadowColor: _orange.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
