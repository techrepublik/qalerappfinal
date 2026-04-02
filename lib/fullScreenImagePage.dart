// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
//
// class FullScreenImagePage extends StatelessWidget {
//   final String imageUrl;
//
//   const FullScreenImagePage({Key? key, required this.imageUrl}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.close, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: InteractiveViewer(
//         minScale: 0.5,
//         maxScale: 4.0,
//         child: SizedBox.expand(       // allows scaling
//           child: FittedBox(
//             fit: BoxFit.contain,      // full screen, no crop, zoom works
//             child: CachedNetworkImage(
//               imageUrl: imageUrl,
//               placeholder: (_, __) =>
//               const Center(child: CircularProgressIndicator(color: Colors.white)),
//               errorWidget: (_, __, ___) =>
//               const Icon(Icons.error, color: Colors.red, size: 60),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
