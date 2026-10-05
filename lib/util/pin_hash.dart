import 'dart:convert';

import 'package:crypto/crypto.dart';

String hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

bool esPinValido(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);
