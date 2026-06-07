import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

const String fontMulishBlack = 'Mulish Black';
const String fontMulishBold = 'Mulish Bold';
const String fontMulishLight = 'Mulish Light';
const String fontMulishMedium = 'Mulish Medium';
const String fontMulishRegular = 'Mulish Regular';
const String fontMulishSemiBold = 'Mulish SemiBold';
const String fontNotoSans = 'NotoSans';

class MyFont {
  static TextStyle bold(double size, {Color? color}) => TextStyle(
        fontFamily: fontMulishBold,
        fontSize: size,
        color: color,
      );

  static TextStyle semiBold(double size, {Color? color}) => TextStyle(
        fontFamily: fontMulishSemiBold,
        fontSize: size,
        color: color,
      );

  static TextStyle regular(double size, {Color? color}) => TextStyle(
        fontFamily: fontMulishRegular,
        fontSize: size,
        color: color,
      );
}
