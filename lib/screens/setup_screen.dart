import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:block_flutter/block_flutter.dart';
import '../providers/connection_provider.dart';
import '../core/platform_helper.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(text: '我的节点');
  final _addressCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _ipfsCtrl = TextEditingController();
  bool _testing = false;
  bool _savingIpfs = false;
  bool _keyVisible = false;
  String? _testError;
  String? _initialIpfsEndpoint;
  String? _lastTestSignature;
  Map<String, dynamic>? _lastTestNodeData;

  @override
  void initState() {
    super.initState();
    final active = context.read<ConnectionProvider>().activeConnection;
    if (active != null) {
      _nameCtrl.text = active.name;
      _addressCtrl.text = active.address;
      _keyCtrl.text = active.keyBase64;
      _lastTestSignature =
          '${active.address.trim().replaceAll(RegExp(r'/+$'), '')}|${active.keyBase64.trim()}';
      _lastTestNodeData = active.nodeData;
    }
    _initialIpfsEndpoint = context.read<ConnectionProvider>().ipfsEndpoint ?? '';
    _ipfsCtrl.text = _initialIpfsEndpoint!;
    _ipfsCtrl.addListener(() => setState(() {}));
    _addressCtrl.addListener(_invalidateNodeTestCache);
    _keyCtrl.addListener(_invalidateNodeTestCache);
  }

  void _invalidateNodeTestCache() {
    final sig = _nodeSignature();
    if (_lastTestSignature != null && _lastTestSignature != sig) {
      _lastTestSignature = null;
      _lastTestNodeData = null;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _keyCtrl.dispose();
    _ipfsCtrl.dispose();
    super.dispose();
  }

  String _normalizedAddress() =>
      _addressCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');

  String _normalizedIpfsInput() =>
      _ipfsCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');

  String _nodeSignature() =>
      '${_normalizedAddress()}|${_keyCtrl.text.trim()}';

  bool _isValidIpfs(String v) {
    if (v.trim().isEmpty) return true;
    final u = Uri.tryParse(v.trim());
    if (u == null) return false;
    return u.hasScheme && (u.scheme == 'http' || u.scheme == 'https');
  }

  Future<Map<String, dynamic>> _testNodeConnection() async {
    final connection = ConnectionModel(
      name: _nameCtrl.text.trim(),
      address: _normalizedAddress(),
      keyBase64: _keyCtrl.text.trim(),
      status: ConnectionStatus.connecting,
    );

    final api = NodeApi(connection: connection);
    await api.getSignature();

    return ApiClient(connection: connection).postToBridge(
      protocol: 'open',
      routing: '/node/node',
      data: const {},
    );
  }

  Future<void> _testNodeOnly() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _testError = null;
    });

    try {
      final nodeData = await _testNodeConnection();
      _lastTestSignature = _nodeSignature();
      _lastTestNodeData = nodeData;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('节点连接测试成功')),
        );
      }
    } catch (e) {
      setState(() => _testError = '连接失败：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saveNode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _testError = null;
    });

    try {
      final sig = _nodeSignature();
      final nodeData = (_lastTestSignature == sig && _lastTestNodeData != null)
          ? _lastTestNodeData!
          : await _testNodeConnection();

      _lastTestSignature = sig;
      _lastTestNodeData = nodeData;

      if (!mounted) return;
      final provider = context.read<ConnectionProvider>();
      final connection = ConnectionModel(
        name: _nameCtrl.text.trim(),
        address: _normalizedAddress(),
        keyBase64: _keyCtrl.text.trim(),
        status: ConnectionStatus.connected,
        nodeData: nodeData,
      );
      await provider.setSingleConnection(connection, setActive: true);

      if (_ipfsCtrl.text.trim() != _initialIpfsEndpoint) {
        final ipfs = _ipfsCtrl.text.trim();
        await provider.setIpfsEndpoint(ipfs.isEmpty ? null : ipfs);
        _initialIpfsEndpoint = ipfs;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('节点已保存并设为当前')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _testError = '连接失败：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saveIpfsOnly() async {
    final ipfs = _normalizedIpfsInput();
    if (!_isValidIpfs(ipfs)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IPFS 地址格式不正确，请使用 http/https')),
      );
      return;
    }
    if (ipfs == (_initialIpfsEndpoint ?? '')) return;
    setState(() => _savingIpfs = true);
    try {
      await context
          .read<ConnectionProvider>()
          .setIpfsEndpoint(ipfs.isEmpty ? null : ipfs);
      _initialIpfsEndpoint = ipfs;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('IPFS 地址已保存')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingIpfs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();
    final cs = Theme.of(context).colorScheme;
    final isMacOS = PlatformHelper.isMacOS;
    final bgColor = isMacOS ? const Color(0xFF1A1A2E) : const Color(0xFFF5F6FA);
    final ipfsChanged = _normalizedIpfsInput() != (_initialIpfsEndpoint ?? '');
    final ipfsConfigured = provider.ipfsEndpoint?.trim().isNotEmpty == true;
    final active = provider.activeConnection;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        title: Text(
          '节点与 IPFS 设置',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isMacOS ? const Color(0xFFF2F6FF) : null,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusOverviewCard(
              activeName: active?.name,
              activeAddress: active?.address,
              ipfsEndpoint: provider.ipfsEndpoint,
            ),
            const SizedBox(height: 14),
            // ── IPFS 地址 ──
            _SectionLabel(label: 'IPFS 服务（可选）'),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_rounded,
                        size: 17,
                        color: ipfsConfigured
                            ? const Color(0xFF8DA6FF)
                            : (isMacOS
                                ? const Color(0xFF95A0BD)
                                : cs.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '对象存储端点',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isMacOS
                              ? const Color(0xFFEAF0FF)
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (ipfsConfigured
                                  ? const Color(0xFF8DA6FF)
                                  : (isMacOS
                                      ? const Color(0xFF95A0BD)
                                      : cs.onSurfaceVariant))
                              .withValues(alpha: isMacOS ? 0.18 : 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: (ipfsConfigured
                                    ? const Color(0xFF8DA6FF)
                                    : (isMacOS
                                        ? const Color(0xFF95A0BD)
                                        : cs.onSurfaceVariant))
                                .withValues(alpha: isMacOS ? 0.34 : 0.2),
                          ),
                        ),
                        child: Text(
                          ipfsConfigured ? '已配置' : '未配置',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ipfsConfigured
                                ? const Color(0xFF8DA6FF)
                                : (isMacOS
                                    ? const Color(0xFF95A0BD)
                                    : cs.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isMacOS
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.01),
                    ),
                    child: TextField(
                      controller: _ipfsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'IPFS 端点',
                        hintText: 'http://192.168.1.100:8080',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '留空表示不使用独立 IPFS 服务；可在任意时刻修改。',
                    style: TextStyle(
                      fontSize: 11,
                      color: isMacOS ? const Color(0xFF95A0BD) : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: (_savingIpfs || !ipfsChanged)
                          ? null
                          : _saveIpfsOnly,
                      child: _savingIpfs
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存 IPFS'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 节点配置（单节点） ──
            _SectionLabel(label: '节点配置'),
            _Card(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _CardRow(
                      icon: Icons.label_outline_rounded,
                      iconColor: cs.primary,
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: '节点名称',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? '请输入名称' : null,
                      ),
                    ),
                    _CardDivider(),
                    _CardRow(
                      icon: Icons.dns_rounded,
                      iconColor: cs.primary,
                      child: TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(
                          labelText: '节点地址',
                          hintText: 'http://192.168.1.100:8080',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        keyboardType: TextInputType.url,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '请输入地址';
                          if (!v.trim().startsWith('http')) return '地址需以 http:// 开头';
                          return null;
                        },
                      ),
                    ),
                    _CardDivider(),
                    _CardRow(
                      icon: Icons.key_rounded,
                      iconColor: cs.primary,
                      child: TextFormField(
                        controller: _keyCtrl,
                        obscureText: !_keyVisible,
                        decoration: InputDecoration(
                          labelText: 'AES 密钥（Base64）',
                          border: InputBorder.none,
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _keyVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                            ),
                            onPressed: () =>
                                setState(() => _keyVisible = !_keyVisible),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? '请输入密钥' : null,
                      ),
                    ),
                    if (_testError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: cs.onErrorContainer, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_testError!,
                                  style: TextStyle(
                                      color: cs.onErrorContainer, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _testing ? null : _testNodeOnly,
                            icon: const Icon(Icons.wifi_find_rounded),
                            label: const Text('测试连接'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _testing ? null : _saveNode,
                            icon: _testing
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle_outline_rounded),
                            label: Text(_testing ? '连接中...' : '保存节点配置'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── 节点卡片 ──────────────────────────────────────────────────

class _StatusOverviewCard extends StatelessWidget {
  const _StatusOverviewCard({
    required this.activeName,
    required this.activeAddress,
    required this.ipfsEndpoint,
  });

  final String? activeName;
  final String? activeAddress;
  final String? ipfsEndpoint;

  @override
  Widget build(BuildContext context) {
    final isMacOS = PlatformHelper.isMacOS;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isMacOS ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        border: isMacOS
            ? Border.all(color: Colors.white.withValues(alpha: 0.14))
            : Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前状态',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isMacOS ? const Color(0xFFEAF0FF) : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          _StatusRow(
            icon: Icons.hub_rounded,
            label: '当前节点',
            value: activeName == null
                ? '未配置'
                : '$activeName (${activeAddress ?? '-'})',
            isMacOS: isMacOS,
          ),
          const SizedBox(height: 8),
          _StatusRow(
            icon: Icons.cloud_rounded,
            label: 'IPFS',
            value: ipfsEndpoint?.trim().isNotEmpty == true
                ? ipfsEndpoint!
                : '未配置（可选）',
            isMacOS: isMacOS,
            accentColor: ipfsEndpoint?.trim().isNotEmpty == true
                ? const Color(0xFF34C759)
                : cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isMacOS,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isMacOS;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: accentColor ?? (isMacOS ? const Color(0xFF9EB5FF) : const Color(0xFF4A6CF7)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isMacOS ? const Color(0xFF95A0BD) : const Color(0xFF7A7A85),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMacOS ? const Color(0xFFEAF0FF) : const Color(0xFF1A1A2E),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 通用组件 ──────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isMacOS = PlatformHelper.isMacOS;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isMacOS ? const Color(0xFF87A1FF) : const Color(0xFF4A6CF7),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isMacOS = PlatformHelper.isMacOS;
    final theme = Theme.of(context);
    final cardTheme = isMacOS
        ? theme.copyWith(
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              labelStyle: const TextStyle(color: Color(0xFFC5D0EC)),
              hintStyle: const TextStyle(color: Color(0xFF7E8AAF)),
            ),
            textTheme: theme.textTheme.apply(
              bodyColor: const Color(0xFFF2F6FF),
              displayColor: const Color(0xFFF2F6FF),
            ),
          )
        : theme;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isMacOS ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isMacOS
            ? Border.all(color: Colors.white.withValues(alpha: 0.14))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isMacOS ? 0.18 : 0.05),
            blurRadius: isMacOS ? 14 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Theme(data: cardTheme, child: child),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }
}

class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMacOS = PlatformHelper.isMacOS;
    return Divider(
      height: 20,
      indent: 30,
      color: isMacOS
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.black.withValues(alpha: 0.06),
    );
  }
}
