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
    final ideas = _filtered;
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
        label: const Text('New Idea', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search ideas, tags...',
                    prefixIcon: const Icon(Icons.search, color: C.hint),
                    filled: true,
                    fillColor: C.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => FilterChip(
                      label: Text(_categories[i],
                          style: TextStyle(
                              fontSize: 12,
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
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (_ideas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('${ideas.length} idea${ideas.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: C.hint, fontSize: 12)),
                  const Spacer(),
                  if (_search.isNotEmpty || _filter != 'All')
                    TextButton(
                      onPressed: () => setState(() { _search = ''; _filter = 'All'; }),
                      child: const Text('Clear', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ideas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lightbulb_outline,
                                size: 64, color: C.hint),
                            const SizedBox(height: 12),
                            Text(
                              _search.isNotEmpty || _filter != 'All'
                                  ? 'No ideas match'
                                  : 'No ideas yet',
                              style: const TextStyle(color: C.hint),
                            ),
                            if (_search.isEmpty && _filter == 'All')
                              const Text('Tap + to capture your first idea',
                                  style: TextStyle(color: C.hint, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: ideas.length,
                        itemBuilder: (_, i) => IdeaCard(
                          idea: ideas[i],
                          onDelete: () => _deleteIdea(ideas[i]),
                          onPin: () => _togglePin(ideas[i]),
                          onEdit: () async {
                            await Navigator.pushNamed(context, '/newIdea',
                                arguments: ideas[i]);
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
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: catColor, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(idea.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: C.textPrimary)),
                  ),
                  Text(_moodEmoji[idea.mood.clamp(1, 5)],
                      style: const TextStyle(fontSize: 18)),
                  if (idea.pinned)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.push_pin, size: 14, color: C.accentLight),
                    ),
                ],
              ),
              if (idea.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(idea.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: C.textSecondary, fontSize: 13)),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(idea.category,
                        style: TextStyle(color: catColor, fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: idea.tags
                            .map((t) => Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: C.surface,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('#$t',
                                      style: const TextStyle(
                                          color: C.hint, fontSize: 11)),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      idea.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 18,
                      color: idea.pinned ? C.accentLight : C.hint,
                    ),
                    onPressed: onPin,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: C.hint),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(_formatDate(idea.createdAt),
                  style: const TextStyle(color: C.hint, fontSize: 11)),
            ],
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
