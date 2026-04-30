import 'package:flutter/cupertino.dart';

import 'media_preview_action_button.dart';

class MediaActionBar extends StatelessWidget {
  final bool isVideo;
  final bool isPlaying;
  final VoidCallback onShare;
  final VoidCallback onTogglePlay;
  final VoidCallback onOpenGallery;
  final VoidCallback onDelete;

  const MediaActionBar({
    super.key,
    required this.isVideo,
    required this.isPlaying,
    required this.onShare,
    required this.onTogglePlay,
    required this.onOpenGallery,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          MediaPreviewActionButton(
            icon: CupertinoIcons.share,
            label: 'Compartir',
            onTap: onShare,
          ),
          if (isVideo)
            MediaPreviewActionButton(
              icon: isPlaying
                  ? CupertinoIcons.pause_fill
                  : CupertinoIcons.play_fill,
              label: isPlaying ? 'Pausar' : 'Reproducir',
              onTap: onTogglePlay,
            ),
          MediaPreviewActionButton(
            icon: CupertinoIcons.photo_on_rectangle,
            label: 'Galeria',
            onTap: onOpenGallery,
          ),
          MediaPreviewActionButton(
            icon: CupertinoIcons.trash,
            label: 'Eliminar',
            isDestructive: true,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}
