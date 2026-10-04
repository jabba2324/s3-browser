import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s3_browser/utils/file_type_utils.dart';

void main() {
  group('FileTypeUtils.isImage', () {
    test('recognizes common image extensions', () {
      for (final name in ['photo.jpg', 'photo.jpeg', 'photo.png', 'photo.gif', 'photo.webp', 'photo.bmp', 'photo.heic']) {
        expect(FileTypeUtils.isImage(name), isTrue, reason: name);
      }
    });

    test('is case-insensitive', () {
      expect(FileTypeUtils.isImage('PHOTO.JPG'), isTrue);
    });

    test('rejects non-image and extension-less names', () {
      expect(FileTypeUtils.isImage('video.mp4'), isFalse);
      expect(FileTypeUtils.isImage('README'), isFalse);
    });
  });

  group('FileTypeUtils.isVideo', () {
    test('recognizes common video extensions', () {
      for (final name in ['clip.mp4', 'clip.mov', 'clip.m4v', 'clip.avi', 'clip.mkv', 'clip.webm', 'clip.flv', 'clip.wmv']) {
        expect(FileTypeUtils.isVideo(name), isTrue, reason: name);
      }
    });

    test('is case-insensitive', () {
      expect(FileTypeUtils.isVideo('CLIP.MP4'), isTrue);
    });

    test('rejects non-video and extension-less names', () {
      expect(FileTypeUtils.isVideo('photo.png'), isFalse);
      expect(FileTypeUtils.isVideo('README'), isFalse);
    });
  });

  group('FileTypeUtils.getIcon/getIconColor', () {
    test('folders take precedence regardless of name', () {
      expect(FileTypeUtils.getIcon(isFolder: true, filename: 'clip.mp4'), Icons.folder);
    });

    test('images, videos, and other files get distinct icons', () {
      expect(FileTypeUtils.getIcon(isFolder: false, filename: 'photo.png'), Icons.photo);
      expect(FileTypeUtils.getIcon(isFolder: false, filename: 'clip.mp4'), Icons.video_library);
      expect(FileTypeUtils.getIcon(isFolder: false, filename: 'doc.pdf'), Icons.insert_drive_file);
    });
  });
}
