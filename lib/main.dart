import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    try {
      await AwesomeNotifications().initialize(null, [
        NotificationChannel(
          channelKey: 'alarms',
          channelName: 'Alarmas ARK',
          channelDescription: 'Alarmas de tus habitos',
          importance: NotificationImportance.Max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          defaultRingtoneType: DefaultRingtoneType.Alarm,
        ),
      ]);
    } catch (_) {}
  }
  runApp(const ArkApp());
}

class Habit {
  final String id;
  final String name;
  final String icon;
  final int color;
  final int target;
  final String? alarm;

  Habit({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.target,
    this.alarm,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'target': target,
    'alarm': alarm,
  };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
    id: j['id'] as String,
    name: j['name'] as String,
    icon: j['icon'] as String,
    color: (j['color'] as num).toInt(),
    target: (j['target'] as num).toInt(),
    alarm: j['alarm'] as String?,
  );
}

class ArkApp extends StatefulWidget {
  const ArkApp({super.key});
  @override
  State<ArkApp> createState() => _ArkAppState();
}

class _ArkAppState extends State<ArkApp> {
  bool dark = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => dark = p.getBool('ark_dark') ?? true);
    });
  }

  void _toggle(bool v) {
    setState(() => dark = v);
    SharedPreferences.getInstance().then((p) => p.setBool('ark_dark', v));
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
    title: 'ARK',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0B0F14)
          : const Color(0xFFF6F4EF),
      colorSchemeSeed: dark ? const Color(0xFF39FF88) : const Color(0xFF16A34A),
    ),
    home: Home(dark: dark, onTheme: _toggle),
  );
}

class Home extends StatefulWidget {
  final bool dark;
  final void Function(bool) onTheme;
  const Home({super.key, required this.dark, required this.onTheme});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  int tab = 0;
  List<Habit> habits = [];
  Map<String, Map<String, int>> logs = {};
  Map<String, List<String>> failed = {};
  final Set<String> _fired = {};
  Habit? _active;
  Timer? _tick;
  static void Function(bool)? _bridge;
  late final AnimationController _flame = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final AnimationController _ovl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  bool get _dark => widget.dark;
  Color get bg => _dark ? const Color(0xFF0B0F14) : const Color(0xFFF6F4EF);
  Color get card => _dark ? const Color(0xFF141B24) : const Color(0xFFFFFFFF);
  Color get ink => _dark ? const Color(0xFFEAF2EF) : const Color(0xFF20241F);
  Color get sub => _dark ? const Color(0xFF8FA0AB) : const Color(0xFF79806F);
  Color get line => _dark ? const Color(0xFF24313D) : const Color(0xFFE5E2D9);
  Color get green => _dark ? const Color(0xFF39FF88) : const Color(0xFF16A34A);
  Color get greenDark =>
      _dark ? const Color(0xFF1FBF63) : const Color(0xFF15803D);
  Color get amber => _dark ? const Color(0xFFFFC24D) : const Color(0xFFD97706);
  Color get amberDark =>
      _dark ? const Color(0xFFE09A00) : const Color(0xFFB45309);
  Color get red => _dark ? const Color(0xFFFF5C5C) : const Color(0xFFDC2626);
  Color get redDark =>
      _dark ? const Color(0xFFE04444) : const Color(0xFFB91C1C);
  Color get cyan => _dark ? const Color(0xFF00E5FF) : const Color(0xFF0891B2);

  static const _colors = [
    0xFF39FF88,
    0xFF00E5FF,
    0xFFFFC24D,
    0xFFFF5C5C,
    0xFFB388FF,
    0xFFFF3D81,
  ];
  static const _icons = [
    'drop',
    'book',
    'fit',
    'code',
    'sleep',
    'med',
    'run',
    'star',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => _checkTime());
    if (!kIsWeb) {
      AwesomeNotifications().setListeners(onActionReceivedMethod: _onAction);
    }
    _bridge = (done) {
      if (_active == null) return;
      _closeOverlay(done);
    };
  }

  @override
  void dispose() {
    _tick?.cancel();
    _flame.dispose();
    _ovl.dispose();
    super.dispose();
  }

  @pragma('vm:entry-point')
  static Future<void> _onAction(ReceivedAction a) async {
    if (a.buttonKeyPressed == 'DONE') _bridge?.call(true);
    if (a.buttonKeyPressed == 'FAIL') _bridge?.call(false);
  }

  void _haptic() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  IconData _icon(String k) {
    switch (k) {
      case 'drop':
        return Icons.water_drop_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      case 'fit':
        return Icons.fitness_center_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'sleep':
        return Icons.nightlight_rounded;
      case 'med':
        return Icons.self_improvement_rounded;
      case 'run':
        return Icons.directions_run_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final hs = p.getString('ark_habits');
    if (hs == null) {
      habits = [
        Habit(
          id: 'h1',
          name: 'Agua',
          icon: 'drop',
          color: _colors[1],
          target: 8,
        ),
        Habit(
          id: 'h2',
          name: 'Estudio',
          icon: 'book',
          color: _colors[0],
          target: 2,
        ),
        Habit(
          id: 'h3',
          name: 'Entrenar',
          icon: 'fit',
          color: _colors[2],
          target: 1,
        ),
      ];
      await _save();
    } else {
      habits = (jsonDecode(hs) as List)
          .map((e) => Habit.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final ls = p.getString('ark_logs') ?? '{}';
    logs = (jsonDecode(ls) as Map).map(
      (k, v) => MapEntry(
        k as String,
        (v as Map).map((a, b) => MapEntry(a as String, (b as num).toInt())),
      ),
    );
    final fs = p.getString('ark_failed') ?? '{}';
    failed = (jsonDecode(fs) as Map).map(
      (k, v) => MapEntry(k as String, (v as List).cast<String>()),
    );
    setState(() {});
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'ark_habits',
      jsonEncode(habits.map((e) => e.toJson()).toList()),
    );
    await p.setString('ark_logs', jsonEncode(logs));
    await p.setString('ark_failed', jsonEncode(failed));
  }

  int _count(Habit h, [String? day]) => logs[day ?? _today()]?[h.id] ?? 0;
  bool _done(Habit h, [String? day]) => _count(h, day) >= h.target;
  bool _failed(Habit h) => failed[_today()]?.contains(h.id) == true;

  double _dayFraction([String? day]) {
    if (habits.isEmpty) return 0;
    final d = day ?? _today();
    return habits.where((h) => _done(h, d)).length / habits.length;
  }

  int get _streak {
    var r = 0;
    var d = DateTime.now();
    while (true) {
      final f = d.toIso8601String().substring(0, 10);
      if (!(logs[f] != null && logs[f]!.isNotEmpty && _dayFraction(f) >= 0.999))
        break;
      r++;
      d = d.subtract(const Duration(days: 1));
    }
    return r;
  }

  int _streakOf(Habit h) {
    var r = 0;
    var d = DateTime.now();
    while (_done(h, d.toIso8601String().substring(0, 10))) {
      r++;
      d = d.subtract(const Duration(days: 1));
    }
    return r;
  }

  void _increment(Habit h) {
    final f = _today();
    final m = logs.putIfAbsent(f, () => {});
    if ((m[h.id] ?? 0) >= h.target) return;
    setState(() {
      m[h.id] = (m[h.id] ?? 0) + 1;
      if (m[h.id]! >= h.target) {
        failed[f]?.remove(h.id);
      }
    });
    _haptic();
    _save();
    if (_dayFraction() >= 0.999) {
      Future.delayed(const Duration(milliseconds: 350), _showDayDone);
    }
  }

  void _showDayDone() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _flame,
              builder: (c, ch) => Transform.scale(
                scale: 1 + 0.1 * _flame.value,
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: amber,
                  size: 60,
                  shadows: _dark ? [Shadow(color: amber, blurRadius: 30)] : [],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Dia completado',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Racha: $_streak dias. Sigue.',
              style: TextStyle(color: sub, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(
              'SEGUIR',
              style: TextStyle(color: green, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  int _notifId(Habit h) => 1000 + h.id.hashCode.abs() % 9000;

  Future<void> _schedule(Habit h) async {
    if (kIsWeb) return;
    try {
      await AwesomeNotifications().cancel(_notifId(h));
      if (h.alarm == null) return;
      final parts = h.alarm!.split(':');
      final hh = int.tryParse(parts[0]) ?? 7;
      final mm = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _notifId(h),
          channelKey: 'alarms',
          title: h.name,
          body: 'Cumplido o fallido. Tu eliges.',
          category: NotificationCategory.Alarm,
          wakeUpScreen: true,
          autoDismissible: false,
          displayOnBackground: true,
          displayOnForeground: true,
        ),
        schedule: NotificationCalendar(hour: hh, minute: mm, repeats: true),
        actionButtons: [
          NotificationActionButton(
            key: 'DONE',
            label: 'CUMPLIDO',
            color: const Color(0xFF39FF88),
          ),
          NotificationActionButton(
            key: 'FAIL',
            label: 'FALLIDO',
            color: const Color(0xFFFF5C5C),
          ),
        ],
      );
    } catch (_) {}
  }

  Future<void> _fireNow(Habit h) async {
    if (!kIsWeb) {
      try {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: _notifId(h),
            channelKey: 'alarms',
            title: h.name,
            body: 'Cumplido o fallido. Tu eliges.',
            category: NotificationCategory.Alarm,
            wakeUpScreen: true,
            autoDismissible: false,
            displayOnBackground: true,
            displayOnForeground: true,
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'DONE',
              label: 'CUMPLIDO',
              color: const Color(0xFF39FF88),
            ),
            NotificationActionButton(
              key: 'FAIL',
              label: 'FALLIDO',
              color: const Color(0xFFFF5C5C),
            ),
          ],
        );
      } catch (_) {}
    }
    if (_active == null) {
      setState(() => _active = h);
      _ovl.forward(from: 0);
    }
  }

  void _checkTime() {
    if (_active != null) return;
    final n = DateTime.now();
    final hm =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
    for (final h in habits) {
      if (h.alarm == null) continue;
      final key = '${h.id}_$hm';
      if (h.alarm == hm && !_fired.contains(key)) {
        _fired.add(key);
        _fireNow(h);
        return;
      }
    }
  }

  void _closeOverlay(bool done) {
    final h = _active;
    if (h == null) return;
    if (!kIsWeb) {
      try {
        AwesomeNotifications().cancel(_notifId(h));
      } catch (_) {}
    }
    setState(() {
      _active = null;
      if (!done) {
        final list = failed.putIfAbsent(_today(), () => []);
        if (!list.contains(h.id)) list.add(h.id);
      }
    });
    if (done) _increment(h);
    _save();
    _haptic();
  }

  Future<void> _perms() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'En web no hay notificaciones: aqui la alarma es el overlay con la pestana abierta.',
          ),
        ),
      );
      return;
    }
    try {
      await Permission.notification.request();
    } catch (_) {}
    try {
      await Permission.scheduleExactAlarm.request();
    } catch (_) {}
    try {
      final ok = await AwesomeNotifications().isNotificationAllowed();
      if (!ok) {
        await AwesomeNotifications().requestPermissionToSendNotifications(
          channelKey: 'alarms',
          permissions: [
            NotificationPermission.Alert,
            NotificationPermission.Sound,
            NotificationPermission.Badge,
            NotificationPermission.Vibration,
            NotificationPermission.Light,
          ],
        );
      }
    } catch (_) {}
  }

  Future<void> _newHabit() async {
    final name = TextEditingController();
    int color = _colors[0];
    String icon = 'star';
    int target = 1;
    String? alarm;
    await showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setS) => AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Nuevo habito',
            style: TextStyle(fontWeight: FontWeight.w800, color: ink),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  style: TextStyle(color: ink),
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    filled: true,
                    fillColor: bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Meta: ',
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                    IconButton(
                      onPressed: () =>
                          setS(() => target = target > 1 ? target - 1 : 1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$target',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          setS(() => target = target < 20 ? target + 1 : 20),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c2 in _colors)
                      GestureDetector(
                        onTap: () => setS(() => color = c2),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(c2),
                            shape: BoxShape.circle,
                            boxShadow: _dark && color == c2
                                ? [BoxShadow(color: Color(c2), blurRadius: 14)]
                                : [],
                            border: Border.all(
                              color: color == c2 ? ink : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in _icons)
                      GestureDetector(
                        onTap: () => setS(() => icon = k),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: icon == k ? Color(color).withAlpha(50) : bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: icon == k
                                  ? Color(color)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(_icon(k), color: Color(color), size: 20),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.alarm, color: sub),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alarm ?? 'Sin alarma',
                        style: TextStyle(
                          color: sub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: d,
                          initialTime: const TimeOfDay(hour: 7, minute: 0),
                        );
                        if (t != null) {
                          setS(
                            () => alarm =
                                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                          );
                        }
                      },
                      child: Text(
                        'HORA',
                        style: TextStyle(
                          color: green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (alarm != null)
                      IconButton(
                        onPressed: () => setS(() => alarm = null),
                        icon: Icon(Icons.close, size: 18, color: red),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: Text('CANCELAR', style: TextStyle(color: sub)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: green,
                foregroundColor: const Color(0xFF0B0F14),
              ),
              onPressed: () async {
                final n = name.text.trim();
                if (n.isEmpty) return;
                final h = Habit(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: n,
                  icon: icon,
                  color: color,
                  target: target,
                  alarm: alarm,
                );
                setState(() => habits.add(h));
                await _save();
                await _schedule(h);
                if (mounted) Navigator.pop(d);
              },
              child: const Text('CREAR'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editHabit(Habit h) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              h.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () async {
                  Navigator.pop(c);
                  final t = await showTimePicker(
                    context: context,
                    initialTime: h.alarm != null
                        ? TimeOfDay(
                            hour: int.parse(h.alarm!.split(':')[0]),
                            minute: int.parse(h.alarm!.split(':')[1]),
                          )
                        : const TimeOfDay(hour: 7, minute: 0),
                  );
                  if (t == null) return;
                  final a =
                      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                  setState(() {
                    habits.remove(h);
                    habits.add(
                      Habit(
                        id: h.id,
                        name: h.name,
                        icon: h.icon,
                        color: h.color,
                        target: h.target,
                        alarm: a,
                      ),
                    );
                  });
                  await _save();
                  await _schedule(habits.last);
                },
                child: const Text('CAMBIAR ALARMA'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () {
                  Navigator.pop(c);
                  _fireNow(h);
                },
                child: const Text('PROBAR ALARMA AHORA'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: red,
                  side: BorderSide(color: red),
                ),
                onPressed: () async {
                  Navigator.pop(c);
                  if (!kIsWeb) {
                    try {
                      await AwesomeNotifications().cancel(_notifId(h));
                    } catch (_) {}
                  }
                  setState(() => habits.remove(h));
                  await _save();
                },
                child: const Text('ELIMINAR'),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _bigButton(String label, Color c, Color dark2, VoidCallback on) {
    return GestureDetector(
      onTap: on,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: dark2, offset: const Offset(0, 4), blurRadius: 0),
            if (_dark) BoxShadow(color: c.withAlpha(60), blurRadius: 18),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _dark ? const Color(0xFF0B0F14) : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _habitCard(Habit h, int i) {
    final c = Color(h.color);
    final cnt = _count(h);
    final done = _done(h);
    final fail = _failed(h);
    final border = fail ? red : (done ? c : line);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + i * 80),
      curve: Curves.easeOutBack,
      builder: (c2, t, ch) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.96 + 0.04 * t, child: ch),
      ),
      child: GestureDetector(
        onLongPress: () => _editHabit(h),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: (done || fail) ? 2 : 1),
            boxShadow: _dark && (done || fail)
                ? [
                    BoxShadow(
                      color: (fail ? red : c).withAlpha(50),
                      blurRadius: 16,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.withAlpha(40),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _icon(h.icon),
                  color: c,
                  size: 26,
                  shadows: _dark ? [Shadow(color: c, blurRadius: 12)] : [],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            h.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ),
                        if (h.alarm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: amber.withAlpha(40),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              h.alarm!,
                              style: TextStyle(
                                color: amber,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (cnt / h.target).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: line,
                        valueColor: AlwaysStoppedAnimation(fail ? red : c),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fail
                          ? 'FALLIDO HOY · aun puedes remediarlo'
                          : '$cnt / ${h.target}',
                      style: TextStyle(
                        color: fail ? red : sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _increment(h),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: fail ? red : (done ? c : bg),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: fail ? red : (done ? c : line),
                      width: 2,
                    ),
                    boxShadow: (done || fail)
                        ? [
                            BoxShadow(
                              color: (fail ? red : c).withAlpha(90),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    fail
                        ? Icons.close_rounded
                        : (done ? Icons.check_rounded : Icons.add_rounded),
                    color: (done || fail)
                        ? (_dark ? const Color(0xFF0B0F14) : Colors.white)
                        : sub,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flameIcon(double size) {
    return AnimatedBuilder(
      animation: _flame,
      builder: (c, ch) {
        final f = _flame.value;
        final s = 0.92 + 0.12 * f;
        return Transform.scale(
          scale: s,
          child: Icon(
            Icons.local_fire_department_rounded,
            color: amber,
            size: size,
            shadows: _dark
                ? [
                    Shadow(color: amber, blurRadius: 22),
                    Shadow(color: red.withAlpha(120), blurRadius: 40),
                  ]
                : [],
          ),
        );
      },
    );
  }

  Widget _todayPage() {
    final frac = _dayFraction();
    final doneCount = habits.where((h) => _done(h)).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        Row(
          children: [
            _flameIcon(34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ARK',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: ink,
                      letterSpacing: 3,
                      shadows: _dark
                          ? [
                              Shadow(
                                color: green.withAlpha(120),
                                blurRadius: 18,
                              ),
                            ]
                          : [],
                    ),
                  ),
                  Text(
                    '$_streak dias de racha',
                    style: TextStyle(
                      color: sub,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                _haptic();
                widget.onTheme(!_dark);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line),
                  boxShadow: _dark
                      ? [BoxShadow(color: cyan.withAlpha(40), blurRadius: 12)]
                      : [],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (ch, a) => RotationTransition(
                    turns: Tween(begin: 0.7, end: 1.0).animate(a),
                    child: FadeTransition(opacity: a, child: ch),
                  ),
                  child: Icon(
                    _dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey<bool>(_dark),
                    color: _dark ? amber : cyan,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: line),
            boxShadow: _dark
                ? [BoxShadow(color: green.withAlpha(30), blurRadius: 20)]
                : [],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: frac),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (c, f, ch) => CircularProgressIndicator(
                        value: f,
                        strokeWidth: 7,
                        backgroundColor: line,
                        valueColor: AlwaysStoppedAnimation(
                          frac >= 1 ? green : cyan,
                        ),
                      ),
                    ),
                    Text(
                      '${(frac * 100).round()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: ink,
                        fontSize: 14,
                        shadows: _dark
                            ? [Shadow(color: cyan, blurRadius: 10)]
                            : [],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOY',
                      style: TextStyle(
                        color: sub,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$doneCount de ${habits.length} habitos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      frac >= 1
                          ? 'Dia perfecto. La racha vive.'
                          : 'Toca el + para cumplir.',
                      style: TextStyle(
                        color: sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...habits.asMap().entries.map((e) => _habitCard(e.value, e.key)),
        const SizedBox(height: 6),
        _bigButton('NUEVO HABITO', green, greenDark, _newHabit),
        const SizedBox(height: 8),
        Text(
          'Manten presionado un habito para alarma / eliminar',
          textAlign: TextAlign.center,
          style: TextStyle(color: sub, fontSize: 11),
        ),
      ],
    );
  }

  Widget _statsPage() {
    final days = <DateTime>[];
    for (var i = 6; i >= 0; i--) {
      days.add(DateTime.now().subtract(Duration(days: i)));
    }
    const letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        Text(
          'PROGRESO',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: ink,
            letterSpacing: 1,
            shadows: _dark
                ? [Shadow(color: cyan.withAlpha(120), blurRadius: 16)]
                : [],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: line),
            boxShadow: _dark
                ? [BoxShadow(color: amber.withAlpha(40), blurRadius: 20)]
                : [],
          ),
          child: Row(
            children: [
              _flameIcon(44),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_streak',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: ink,
                      shadows: _dark
                          ? [Shadow(color: amber, blurRadius: 16)]
                          : [],
                    ),
                  ),
                  Text(
                    'dias seguidos cumpliendo todo',
                    style: TextStyle(
                      color: sub,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ULTIMOS 7 DIAS',
                style: TextStyle(
                  color: sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 100,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: days.map((d) {
                    final f = d.toIso8601String().substring(0, 10);
                    final fr = _dayFraction(f);
                    final full = fr >= 0.999;
                    final bc = full ? green : (fr > 0 ? amber : line);
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: fr),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (c, v, ch) => Container(
                              width: 16,
                              height: 6 + 74 * v,
                              decoration: BoxDecoration(
                                color: bc,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: _dark && full
                                    ? [BoxShadow(color: green, blurRadius: 12)]
                                    : [],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            letras[d.weekday - 1],
                            style: TextStyle(
                              color: sub,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...habits.map(
          (h) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
            ),
            child: Row(
              children: [
                Icon(
                  _icon(h.icon),
                  color: Color(h.color),
                  size: 22,
                  shadows: _dark
                      ? [Shadow(color: Color(h.color), blurRadius: 10)]
                      : [],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    h.name,
                    style: TextStyle(fontWeight: FontWeight.w800, color: ink),
                  ),
                ),
                Text(
                  '${_streakOf(h)} dias',
                  style: TextStyle(
                    color: Color(h.color),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        Text(
          'AJUSTES',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: ink,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),
        _bigButton('PERMITIR NOTIFICACIONES', green, greenDark, _perms),
        const SizedBox(height: 12),
        _bigButton('PROBAR ALARMA DEL PRIMER HABITO', amber, amberDark, () {
          if (habits.isNotEmpty) _fireNow(habits.first);
        }),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.phone_android_rounded, color: green),
                  const SizedBox(width: 8),
                  Text(
                    'PARA QUE SUENE EN TU INFINIX',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: ink,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...[
                '1. Ajustes > Aplicaciones > ARK > Inicio automatico: PERMITIR',
                '2. Ajustes > Bateria > ARK: Sin restriccion / segundo plano',
                '3. Ajustes > Notificaciones > ARK: todo + pantalla de bloqueo',
                '4. Recientes: candado sobre ARK',
              ].map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded, color: green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t,
                          style: TextStyle(
                            color: sub,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ARK v2',
                style: TextStyle(fontWeight: FontWeight.w900, color: ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Tema oscuro neon + claro. Overlay CUMPLIDO/FALLIDO. Web-safe para pruebas.',
                style: TextStyle(
                  color: sub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overlay() {
    final h = _active!;
    final c = Color(h.color);
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _ovl,
        builder: (ctx, ch) {
          final t = Curves.easeOutBack.transform(_ovl.value.clamp(0.0, 1.0));
          return Container(
            color: bg,
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 44),
                  Text(
                    'HORA DE CUMPLIR',
                    style: TextStyle(
                      color: sub,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    h.name,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: ink,
                      shadows: _dark ? [Shadow(color: c, blurRadius: 26)] : [],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    h.alarm ?? '',
                    style: TextStyle(color: sub, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Transform.scale(
                    scale: 0.6 + 0.4 * t,
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: c.withAlpha(40),
                        shape: BoxShape.circle,
                        boxShadow: _dark
                            ? [
                                BoxShadow(
                                  color: c.withAlpha(120),
                                  blurRadius: 50,
                                ),
                              ]
                            : [],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _icon(h.icon),
                          color: _dark ? const Color(0xFF0B0F14) : Colors.white,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        _bigButton(
                          'CUMPLIDO',
                          green,
                          greenDark,
                          () => _closeOverlay(true),
                        ),
                        const SizedBox(height: 14),
                        _bigButton(
                          'FALLIDO',
                          red,
                          redDark,
                          () => _closeOverlay(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Stack(
    children: [
      Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: [_todayPage(), _statsPage(), _settingsPage()][tab],
        ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: line),
            boxShadow: _dark
                ? [
                    BoxShadow(
                      color: green.withAlpha(25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navBtn(0, Icons.home_rounded, 'HOY'),
              _navBtn(1, Icons.bar_chart_rounded, 'PROGRESO'),
              _navBtn(2, Icons.settings_rounded, 'AJUSTES'),
            ],
          ),
        ),
      ),
      if (_active != null) _overlay(),
    ],
  );

  Widget _navBtn(int i, IconData ic, String label) {
    final sel = tab == i;
    final c = sel ? green : sub;
    return GestureDetector(
      onTap: () {
        _haptic();
        setState(() => tab = i);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? green.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: sel && _dark
              ? [BoxShadow(color: green.withAlpha(50), blurRadius: 14)]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ic,
              color: c,
              size: 24,
              shadows: _dark && sel
                  ? [Shadow(color: green, blurRadius: 12)]
                  : [],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: c,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
