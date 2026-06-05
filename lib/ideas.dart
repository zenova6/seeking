import 'package:flutter/material.dart';
import 'package:seeking/main.dart';
import 'package:seeking/newidea.dart';
import 'package:seeking/db_helper.dart';

class IdeasScreen extends StatefulWidget {
  const IdeasScreen({super.key});
  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  List<Idea> _ideas = [];
  bool _loading = true;
  String _search = '';
  String _filter = 'All';
  String _sort = 'Newest';

  final List<String> _categories = [
    'All', 'Business', 'Creative', 'Tech', 'Personal', 'Random'
  ];
  final List<String> _sorts = ['Newest', 'Oldest', 'A-Z'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ideas = await DBHelper.getIdeas();
    setState(() { _ideas = ideas; _loading = false; });
  }

  List<Idea> get _filtered {
    var list = List<Idea>.from(_ideas);
    if (_filter != 'All') list = list.where((i) => i.category == _filter).toList();
    if (_search.isNotEmpty) {
      list = list.where((i) =>
          i.title.toLowerCase().contains(_search.toLowerCase()) ||
          i.description.toLowerCase().contains(_search.toLowerCase()) ||
          i.tags.any((t) => t.toLowerCase().contains(_search.toLowerCase()))).toList();
    }
    switch (_sort) {
      case 'Oldest':
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'A-Z':
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    list.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return 0;
    });
    return list;
  }

  Future<void> _deleteIdea(Idea idea) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        title: const Text('Delete Idea?'),
        content: Text('"${idea.title}" will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DBHelper.deleteIdea(idea.id);
      _load();
    }
  }

  Future<void> _togglePin(Idea idea) async {
    idea.pinned = !idea.pinned;
    await DBHelper.updateIdea(idea);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ideas Vault'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            color: C.card,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => _sorts.map((s) => PopupMenuItem(
              value: s,
              child: Row(children: [
                Icon(_sort == s ? Icons.check : Icons.sort,
                    size: 18, color: _sort == s ? C.accentLight : C.hint),
                const SizedBox(width: 8),
                Text(s),
              ]),
            )).toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/newIdea');
          _load();
        },
        backgroundColor: C.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Idea', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search and Filter Section with Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  C.bg,
                  C.bg.withOpacity(0.95),
                  C.bg,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search ideas, tags...',
                      prefixIcon: const Icon(Icons.search, color: C.hint),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: C.hint),
                              onPressed: () => setState(() => _search = ''),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => FilterChip(
                        label: Text(_categories[i],
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: _filter == _categories[i] ? FontWeight.bold : FontWeight.normal,
                                color: _filter == _categories[i]
                                    ? Colors.white
                                    : C.textSecondary)),
                        selected: _filter == _categories[i],
                        onSelected: (_) => setState(() => _filter = _categories[i]),
                        selectedColor: C.accent,
                        backgroundColor: C.card,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('${_filtered.length} idea${_filtered.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: C.hint, fontSize: 12)),
                const Spacer(),
                if (_search.isNotEmpty || _filter != 'All')
                  TextButton(
                    onPressed: () => setState(() { _search = ''; _filter = 'All'; }),
                    child: const Text('Clear Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Loading ideas...', style: TextStyle(color: C.hint)),
                      ],
                    ),
                  )
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lightbulb_outline,
                                size: 80, color: C.hint.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            Text(
                              _search.isNotEmpty || _filter != 'All'
                                  ? 'No ideas match your search'
                                  : 'No ideas yet',
                              style: const TextStyle(color: C.hint, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            if (_search.isEmpty && _filter == 'All')
                              Text('Tap + to capture your first idea',
                                  style: TextStyle(color: C.hint.withOpacity(0.7), fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => IdeaCard(
                          idea: _filtered[i],
                          onDelete: () => _deleteIdea(_filtered[i]),
                          onPin: () => _togglePin(_filtered[i]),
                          onEdit: () async {
                            await Navigator.pushNamed(context, '/newIdea',
                                arguments: _filtered[i]);
                            _load();
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Idea Card ────────────────────────────────────────────────────────────────

class IdeaCard extends StatelessWidget {
  final Idea idea;
  final VoidCallback onDelete, onPin, onEdit;

  const IdeaCard({
    super.key,
    required this.idea,
    required this.onDelete,
    required this.onPin,
    required this.onEdit,
  });

  static const _moodEmoji = ['', '😴', '🤔', '💡', '🔥', '🚀'];
  static const _categoryColors = {
    'Business': Color(0xFF4A90D9),
    'Creative': Color(0xFFD97B4A),
    'Tech': Color(0xFF4AD9A0),
    'Personal': Color(0xFFD94A90),
    'Random': Color(0xFF9D7DD1),
  };

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColors[idea.category] ?? C.accentLight;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: idea.pinned
                ? LinearGradient(
                    colors: [
                      C.card,
                      C.accent.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: idea.pinned ? C.accent.withOpacity(0.3) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                          color: catColor, shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: catColor.withOpacity(0.4), blurRadius: 8),
                          ],
                      ),
                    ),
                    Expanded(
                      child: Text(idea.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: C.textPrimary)),
                    ),
                    Text(_moodEmoji[idea.mood.clamp(1, 5)],
                        style: const TextStyle(fontSize: 20)),
                    if (idea.pinned)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.push_pin, size: 16, color: C.accentLight),
                      ),
                  ],
                ),
                if (idea.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(idea.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: C.textSecondary, fontSize: 14, height: 1.4)),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: catColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.label_outline, size: 12, color: catColor),
                          const SizedBox(width: 4),
                          Text(idea.category,
                              style: TextStyle(color: catColor, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    ...idea.tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: C.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text('#$t',
                                  style: const TextStyle(
                                      color: C.hint, fontSize: 11)),
                            )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(_formatDate(idea.createdAt),
                          style: const TextStyle(color: C.hint, fontSize: 12)),
                    ),
                    IconButton(
                      icon: Icon(
                        idea.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 20,
                        color: idea.pinned ? C.accentLight : C.hint,
                      ),
                      onPressed: onPin,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: C.hint),
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
