import 'package:flutter/material.dart';
import 'package:mobile/app.dart';
import 'package:mobile/config/dependencies.dart';
import 'package:provider/provider.dart';

void main() =>
    runApp(MultiProvider(providers: providersLocal, child: const EchoApp()));
