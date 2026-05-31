import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scales_mobile/domain/entities/singer_profile.dart';
import 'package:scales_mobile/presentation/providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _stageNameController;
  late final TextEditingController _realNameController;
  late final TextEditingController _pronounsController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;

  double _uploadProgress = 0.0;
  bool _isUploading = false;
  bool _isSaving = false;
  bool _isLoading = true;

  String? _avatarUrl;
  List<SocialLink> _socialLinks = [];

  @override
  void initState() {
    super.initState();
    _stageNameController = TextEditingController();
    _realNameController = TextEditingController();
    _pronounsController = TextEditingController();
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(myProfileProvider.future);
      _stageNameController.text = profile.name;
      _realNameController.text = profile.realName ?? '';
      _pronounsController.text = profile.pronouns ?? '';
      _phoneController.text = profile.phone ?? '';
      _bioController.text = profile.bio ?? '';
      _avatarUrl = profile.avatarUrl;
      _socialLinks = List.from(profile.socialLinks);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _stageNameController.dispose();
    _realNameController.dispose();
    _pronounsController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final repo = ref.read(singerProfileRepoProvider);
      final url = await repo.uploadAvatar(
        image,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
      if (url != null && mounted) {
        setState(() => _avatarUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(singerProfileRepoProvider);
      await repo.updateMyProfile(
        stageName: _stageNameController.text.trim().isNotEmpty
            ? _stageNameController.text.trim()
            : null,
        realName: _realNameController.text.trim().isNotEmpty
            ? _realNameController.text.trim()
            : null,
        pronouns: _pronounsController.text.trim().isNotEmpty
            ? _pronounsController.text.trim()
            : null,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        socialLinks: _socialLinks.isNotEmpty ? _socialLinks : null,
      );
      // Invalidate caches
      ref.invalidate(myProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addSocialLink() async {
    final platformController = TextEditingController();
    final urlController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Social Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: platformController,
              decoration: const InputDecoration(
                labelText: 'Platform (e.g. Instagram)',
                hintText: 'instagram',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final platform = platformController.text.trim();
      final url = urlController.text.trim();
      if (platform.isNotEmpty && url.isNotEmpty) {
        setState(() {
          _socialLinks = [..._socialLinks, SocialLink(platform: platform, url: url)];
        });
      }
    }

    platformController.dispose();
    urlController.dispose();
  }

  void _removeSocialLink(int index) {
    setState(() {
      _socialLinks = List.from(_socialLinks)..removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatarPicker(),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _stageNameController,
                    label: 'Stage Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _realNameController,
                    label: 'Real Name',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _pronounsController,
                    label: 'Pronouns',
                    icon: Icons.people_outline,
                    hint: 'she/her, they/them, etc.',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _bioController,
                    label: 'Bio',
                    icon: Icons.text_snippet_outlined,
                    maxLines: 3,
                    hint: 'Tell others about yourself...',
                  ),
                  const SizedBox(height: 24),
                  _buildSocialLinksSection(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarPicker() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Hero(
          tag: 'avatar_edit',
          child: CircleAvatar(
            radius: 56,
            backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: _avatarUrl == null
                ? Icon(Icons.person,
                    size: 56,
                    color: Theme.of(context).colorScheme.onPrimaryContainer)
                : null,
          ),
        ),
        if (_isUploading)
          Positioned.fill(
            child: CircleAvatar(
              radius: 56,
              backgroundColor: Colors.black54,
              child: CircularProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                color: Colors.white,
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Material(
            color: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isUploading ? null : _pickAvatar,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.camera_alt, size: 20, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: maxLines > 1
          ? TextCapitalization.sentences
          : TextCapitalization.none,
    );
  }

  Widget _buildSocialLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Social Links', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: _addSocialLink,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        if (_socialLinks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No social links yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          ..._socialLinks.asMap().entries.map((entry) => _SocialLinkTile(
                index: entry.key,
                link: entry.value,
                onDelete: () => _removeSocialLink(entry.key),
              )),
      ],
    );
  }
}

class _SocialLinkTile extends StatelessWidget {
  final int index;
  final SocialLink link;
  final VoidCallback onDelete;
  const _SocialLinkTile({
    required this.index,
    required this.link,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${index + 1}'),
        ),
        title: Text(link.platform),
        subtitle: Text(
          link.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
          tooltip: 'Remove',
        ),
      ),
    );
  }
}
