import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/auth/token_storage.dart';
import '../../models/document.dart';
import '../../widgets/common_widgets.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiClient().dio;
  late TabController _tabCtrl;
  final _categories = ['all', 'contract_template', 'employee_handbook', 'policy', 'form', 'other'];
  Map<String, List<Document>> _docsByCategory = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _categories.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get(ApiConstants.documents);
      final docs = (res.data is Map ? (res.data['data'] ?? []) : res.data as List)
          .map((j) => Document.fromJson(j))
          .toList();
      setState(() {
        _docsByCategory = {'all': List<Document>.from(docs)};
        for (final cat in _categories.skip(1)) {
          _docsByCategory[cat] = docs.where((d) => d.category == cat).toList();
        }
      });
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _download(Document doc) async {
    final token = await TokenStorage.getToken();
    if (token == null) return;

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/${doc.filename}';

    final snack = ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading...'), duration: Duration(seconds: 30)),
    );

    try {
      await _api.download(
        '${ApiConstants.documents}/${doc.id}/download',
        filePath,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      snack.close();
      await OpenFile.open(filePath);
    } catch (_) {
      snack.close();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    final file = result.files.single;
    try {
      final formData = FormData.fromMap({
        'title': file.name,
        'file': await MultipartFile.fromFile(file.path!, filename: file.name),
      });
      await _api.post(ApiConstants.documents, data: formData);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          if (user.isAdmin) IconButton(icon: const Icon(Icons.upload_file), onPressed: _upload),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: _categories.map((c) => Tab(text: c.replaceAll('_', ' '))).toList(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
        ),
      ),
      body: _loading
          ? const ShimmerList()
          : TabBarView(
              controller: _tabCtrl,
              children: _categories.map((cat) {
                final docs = _docsByCategory[cat] ?? [];
                if (docs.isEmpty) return const EmptyWidget(message: 'No documents', icon: Icons.folder_open);
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (_, i) => _DocumentCard(doc: docs[i], onDownload: () => _download(docs[i])),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Document doc;
  final VoidCallback onDownload;
  const _DocumentCard({required this.doc, required this.onDownload});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
            child: Icon(_iconForMime(doc.mimeType), color: Colors.blue),
          ),
          title: Text(doc.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${doc.category.replaceAll('_', ' ')} • ${doc.fileSizeDisplay}'),
          trailing: IconButton(icon: const Icon(Icons.download), onPressed: onDownload),
        ),
      );

  IconData _iconForMime(String mime) {
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.contains('word') || mime.contains('document')) return Icons.description;
    if (mime.contains('sheet') || mime.contains('excel')) return Icons.table_chart;
    if (mime.contains('image')) return Icons.image;
    return Icons.insert_drive_file;
  }
}
