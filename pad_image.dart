import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/images/app_icon.png');
  if (!file.existsSync()) {
    print('File not found!');
    return;
  }

  // Read the original image
  final original = img.decodeImage(file.readAsBytesSync());
  if (original == null) {
    print('Could not decode image!');
    return;
  }

  // Calculate new padded size (adding generous transparent padding to make it fit)
  // Let original take up 50% of the width
  final int newWidth = (original.width * 2).round();
  final int newHeight = (original.height * 2).round();

  // Create new transparent image
  final padded = img.Image(width: newWidth, height: newHeight, numChannels: 4);
  img.fill(padded, color: img.ColorRgba8(0, 0, 0, 0));

  // Draw the original image centered
  final int dstX = (newWidth - original.width) ~/ 2;
  final int dstY = (newHeight - original.height) ~/ 2;
  img.compositeImage(padded, original, dstX: dstX, dstY: dstY);

  // Save the result for splash screen
  final paddedFile = File('assets/images/app_icon_padded.png');
  paddedFile.writeAsBytesSync(img.encodePng(padded));

  print(
    'Padded image generated successfully: ${padded.width}x${padded.height}',
  );
}
