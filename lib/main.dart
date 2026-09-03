import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'app/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 초기화 (.env에서 URL/KEY 로드)
  await SupabaseConfig.initialize();

  // 날짜 포맷 로케일 초기화 (table_calendar 등에서 필요)
  await initializeDateFormatting('ko_KR');

  runApp(
    const ProviderScope(
      child: HotelManagementApp(),
    ),
  );
}
