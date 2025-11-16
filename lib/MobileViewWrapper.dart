import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';

/// Cart Page
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get_utils/src/platform/platform.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:math';

import 'Styles/my_icons.dart'; // 👈 needed for max()

class MobileViewWrapper extends StatelessWidget {
  final Widget child;

  const MobileViewWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    const baseWidth = 480.0; // iPhone 14 width
    const baseHeight = 844.0; // iPhone 14 height
    const minPhoneWidth = 280.0; // 👈 minimum width

    final screenSize = MediaQuery.of(context).size;

    // Scale based on available height (responsive)
    double scale = screenSize.height / baseHeight;
    if (scale > 1) scale = 1; // prevent too large
    if (scale < 0.6) scale = 0.6; // prevent too small

    // Calculate scaled phone dimensions
    double phoneWidth = baseWidth * scale;
    double phoneHeight = baseHeight * scale;

    // Enforce minimum width
    if (phoneWidth < minPhoneWidth) {
      phoneWidth = minPhoneWidth;
      phoneHeight = baseHeight * (phoneWidth / baseWidth);
    }

    return kIsWeb && GetPlatform.isDesktop
        ? Scaffold(
            backgroundColor: Colors.white,
            body: Stack(
              children: [
                SvgPicture.asset(
                  img_top_hompage_bg,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),

                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: scale >= 1 ? phoneWidth + 10 : phoneWidth,
                    height: phoneHeight + 20,
                    margin: EdgeInsets.only(
                      bottom: scale >= 1 ? 20 : 20,
                      top: scale >= 1 ? 20 : 20,
                      left: scale >= 1 ? 0 : 20,
                      right: scale >= 1 ? 0 : 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(scale >= 1 ? 40 : 30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            scale >= 1 ? 0.8 : 0.6,
                          ),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          top: scale >= 1 ? 12 : 6,
                          bottom: scale >= 1 ? 12 : 6,
                          left: scale >= 1 ? 10 : 4,
                          right: scale >= 1 ? 10 : 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              scale >= 1 ? 40 : 30,
                            ),
                            child: MediaQuery(
                              data: MediaQueryData(
                                size: Size(phoneWidth, phoneHeight),
                                devicePixelRatio: 3,
                              ),
                              child: child,
                            ),
                          ),
                        ),

                        // Notch
                        Positioned(
                          top: scale >= 1 ? 3 : 1,
                          child: Container(
                            width: 120 * scale,
                            height: scale >= 1 ? 18 * scale : 15 * scale,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        : child;
  }
}

// import 'dart:ui';
//
// import 'package:flutter/material.dart';
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/svg.dart';
// import 'package:user/Styles/my_colors.dart';
// import 'package:user/Styles/my_icons.dart';
//
// class MobileViewWrapper extends StatelessWidget {
//   final Widget child;
//   const MobileViewWrapper({super.key, required this.child});
//
//   @override
//   Widget build(BuildContext context) {
//     // const double phoneWidth = 390; // iPhone 14 width
//     // const double phoneHeight = 844; // iPhone 14 height
//
//     double phoneHeight = 844;
//     double phoneWidth = 390;
//
//     if (phoneHeight > MediaQuery.of(context).size.height) {
//       phoneWidth = 280;
//     }
//     return kIsWeb
//         ? Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: Container(
//           margin: EdgeInsets.symmetric(
//               vertical: phoneHeight > MediaQuery.of(context).size.height
//                   ? 12
//                   : 0),
//           width: (phoneWidth + 20),
//           height: phoneHeight + 40,
//           decoration: BoxDecoration(
//             color: Colors.black,
//             borderRadius: BorderRadius.circular(
//                 phoneHeight > MediaQuery.of(context).size.height
//                     ? 20
//                     : 50),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(1),
//                 blurRadius: 20,
//                 spreadRadius: 2,
//               ),
//             ],
//           ),
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               // Screen area
//               phoneHeight > MediaQuery.of(context).size.height
//                   ? Positioned(
//                 top: 3,
//                 bottom: 3,
//                 left: 3,
//                 right: 3,
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(phoneHeight >
//                       MediaQuery.of(context).size.height
//                       ? 17
//                       : 40),
//                   child: SizedBox(
//                     width: phoneWidth,
//                     height: phoneHeight,
//                     child: MediaQuery(
//                       // Force mobile screen size for layout
//                       data: MediaQueryData(
//                         size: Size(phoneWidth, phoneHeight),
//                         devicePixelRatio: 3,
//                       ),
//                       child: child,
//                     ),
//                   ),
//                 ),
//               )
//                   : Positioned(
//                 top: 20,
//                 bottom: 20,
//                 left: 10,
//                 right: 10,
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(phoneHeight >
//                       MediaQuery.of(context).size.height
//                       ? 18
//                       : 40),
//                   child: SizedBox(
//                     width: phoneWidth,
//                     height: phoneHeight,
//                     child: MediaQuery(
//                       // Force mobile screen size for layout
//                       data: MediaQueryData(
//                         size: Size(phoneWidth, phoneHeight),
//                         devicePixelRatio: 3,
//                       ),
//                       child: child,
//                     ),
//                   ),
//                 ),
//               ),
//               // Notch
//               Positioned(
//                 top: phoneHeight > MediaQuery.of(context).size.height
//                     ? 3
//                     : 8,
//                 child: Container(
//                   width: phoneHeight > MediaQuery.of(context).size.height
//                       ? 80
//                       : 120,
//                   height: phoneHeight > MediaQuery.of(context).size.height
//                       ? 8
//                       : 20,
//                   decoration: BoxDecoration(
//                     color: Colors.black,
//                     borderRadius: BorderRadius.circular(15),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//
//       // Stack(
//       //   children: [
//       //     SvgPicture.asset(
//       //       img_abha_bg,
//       //       width: double.infinity,
//       //       height: double.infinity,
//       //       fit: BoxFit.cover,
//       //     ),
//       //     Row(
//       //       children: [
//       //         Expanded(
//       //             child: Container(
//       //                 child: Column(
//       //           children: [
//       //             // Image.asset(
//       //             //   icon_logo,
//       //             //   width: 200,
//       //             //   height: 200,
//       //             // ),
//       //             // Text(
//       //             //   "Health ke leke no bahas, Only THS",
//       //             //   style: TextStyle(fontSize: 52, color: Colors.white),
//       //             // )
//       //           ],
//       //         ))),
//       //         Center(
//       //           child: Container(
//       //             width: (phoneWidth + 20),
//       //             height: phoneHeight + 40,
//       //             decoration: BoxDecoration(
//       //               color: Colors.black,
//       //               borderRadius: BorderRadius.circular(50),
//       //               boxShadow: [
//       //                 BoxShadow(
//       //                   color: Colors.black.withOpacity(1),
//       //                   blurRadius: 20,
//       //                   spreadRadius: 2,
//       //                 ),
//       //               ],
//       //             ),
//       //             child: Stack(
//       //               alignment: Alignment.center,
//       //               children: [
//       //                 // Screen area
//       //                 Positioned(
//       //                   top: 20,
//       //                   bottom: 20,
//       //                   left: 10,
//       //                   right: 10,
//       //                   child: ClipRRect(
//       //                     borderRadius: BorderRadius.circular(40),
//       //                     child: SizedBox(
//       //                       width: phoneWidth,
//       //                       height: phoneHeight,
//       //                       child: MediaQuery(
//       //                         // Force mobile screen size for layout
//       //                         data: MediaQueryData(
//       //                           size: Size(phoneWidth, phoneHeight),
//       //                           devicePixelRatio: 3,
//       //                         ),
//       //                         child: child,
//       //                       ),
//       //                     ),
//       //                   ),
//       //                 ),
//       //                 // Notch
//       //                 Positioned(
//       //                   top: 8,
//       //                   child: Container(
//       //                     width: 120,
//       //                     height: 20,
//       //                     decoration: BoxDecoration(
//       //                       color: Colors.black,
//       //                       borderRadius: BorderRadius.circular(15),
//       //                     ),
//       //                   ),
//       //                 ),
//       //               ],
//       //             ),
//       //           ),
//       //         ),
//       //         Expanded(child: Container())
//       //       ],
//       //     ),
//       //   ],
//       // )
//
//       // Stack(
//       //   children: [
//       //     Image.asset(
//       //       ths_login_banner,
//       //       height: double.infinity,
//       //       width: double.infinity,
//       //     ),
//       //     Stack(
//       //       children: [
//       //         Row(
//       //           children: [
//       //             Expanded(
//       //               child: Image.asset(
//       //                 bg_web,
//       //                 height: double.infinity,
//       //                 width: double.infinity,
//       //                 fit: BoxFit.cover,
//       //               ),
//       //             ),
//       //             // Container(
//       //             //   color: half_transaprent,
//       //             //   height: double.infinity,
//       //             //   width: double.infinity,
//       //             // ),
//       //
//       //             Expanded(
//       //               child: Image.asset(
//       //                 ths_login_banner,
//       //                 height: double.infinity,
//       //                 width: double.infinity,
//       //                 fit: BoxFit.fitHeight,
//       //               ),
//       //             )
//       //
//       //             // Expanded(
//       //             //   child: Image.asset(
//       //             //     greenbg,
//       //             //     height: double.infinity,
//       //             //     width: double.infinity,
//       //             //     fit: BoxFit.cover,
//       //             //   ),
//       //             // ),
//       //           ],
//       //         ),
//       //         Container(
//       //           color: half_transaprent,
//       //           height: double.infinity,
//       //           width: double.infinity,
//       //         ),
//       //         // BackdropFilter(
//       //         //   filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
//       //         //   child: Container(
//       //         //     color: Colors.black.withOpacity(
//       //         //         0), // Transparent container to apply blur
//       //         //   ),
//       //         // ),
//       //         Center(
//       //           child: Container(
//       //             width: phoneWidth + 20,
//       //             height: phoneHeight + 40,
//       //             decoration: BoxDecoration(
//       //               color: Colors.black,
//       //               borderRadius: BorderRadius.circular(50),
//       //               boxShadow: [
//       //                 BoxShadow(
//       //                   color: Colors.black.withOpacity(1),
//       //                   blurRadius: 20,
//       //                   spreadRadius: 2,
//       //                 ),
//       //               ],
//       //             ),
//       //             child: Stack(
//       //               alignment: Alignment.center,
//       //               children: [
//       //                 // Screen area
//       //                 Positioned(
//       //                   top: 20,
//       //                   bottom: 20,
//       //                   left: 10,
//       //                   right: 10,
//       //                   child: ClipRRect(
//       //                     borderRadius: BorderRadius.circular(40),
//       //                     child: SizedBox(
//       //                       width: phoneWidth,
//       //                       height: phoneHeight,
//       //                       child: MediaQuery(
//       //                         // Force mobile screen size for layout
//       //                         data: const MediaQueryData(
//       //                           size: Size(phoneWidth, phoneHeight),
//       //                           devicePixelRatio: 3,
//       //                         ),
//       //                         child: child,
//       //                       ),
//       //                     ),
//       //                   ),
//       //                 ),
//       //                 // Notch
//       //                 Positioned(
//       //                   top: 8,
//       //                   child: Container(
//       //                     width: 120,
//       //                     height: 20,
//       //                     decoration: BoxDecoration(
//       //                       color: Colors.black,
//       //                       borderRadius: BorderRadius.circular(15),
//       //                     ),
//       //                   ),
//       //                 ),
//       //               ],
//       //             ),
//       //           ),
//       //         ),
//       //       ],
//       //     ),
//       //   ],
//       // ),
//     )
//         : child;
//   }
// }
