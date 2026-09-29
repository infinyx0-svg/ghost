import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'ghost_alarm',
      channelName: 'Alarmas Ghost',
      channelDescription: 'Recordatorios que cubren la pantalla',
      defaultColor: const Color(0xFF00D4FF),
      importance: NotificationImportance.Max,
      playSound: true,
      criticalAlerts: true,
      locked: true,
      enableVibration: true,
      defaultRingtoneType: DefaultRingtoneType.Alarm,
    ),
  ]);
  runApp(const GhostApp());
}

class Habito {
  final String id;
  final String nombre;
  final String icono;
  final int color;
  final int meta;
  final bool alarma;
  final String hora;
  final String? sonido;

  Habito({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.color,
    required this.meta,
    this.alarma = false,
    this.hora = '07:00',
    this.sonido,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'icono': icono,
    'color': color,
    'meta': meta,
    'alarma': alarma,
    'hora': hora,
    'sonido': sonido,
  };

  factory Habito.fromJson(Map<String, dynamic> j) => Habito(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    icono: j['icono'] as String,
    color: (j['color'] as num).toInt(),
    meta: (j['meta'] as num).toInt(),
    alarma: j['alarma'] == true,
    hora: (j['hora'] ?? '07:00') as String,
    sonido: j['sonido'] as String?,
  );
}

class Recordatorio {
  final String id;
  final String nombre;
  final String icono;
  final int color;
  final String hora;
  final String anim;
  final bool activo;
  final String? sonido;

  Recordatorio({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.color,
    required this.hora,
    required this.anim,
    this.activo = true,
    this.sonido,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'icono': icono,
    'color': color,
    'hora': hora,
    'anim': anim,
    'activo': activo,
    'sonido': sonido,
  };

  factory Recordatorio.fromJson(Map<String, dynamic> j) => Recordatorio(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    icono: j['icono'] as String,
    color: (j['color'] as num).toInt(),
    hora: (j['hora'] ?? '07:00') as String,
    anim: (j['anim'] ?? 'water') as String,
    activo: j['activo'] != false,
    sonido: j['sonido'] as String?,
  );
}

class _WavePainter extends CustomPainter {
  final double t;
  final Color color;
  final double level;
  final double amp;
  _WavePainter({
    required this.t,
    required this.color,
    required this.level,
    required this.amp,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path();
    final baseY = size.height * level;
    path.moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 6) {
      path.lineTo(x, baseY + sin((x / size.width) * 2 * pi + t * 2 * pi) * amp);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}

class GhostApp extends StatelessWidget {
  const GhostApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
    title: 'Ghost',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0A0E14),
    ),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  int tab = 0;
  int xp = 0;
  int retoDias = 90;
  String retoInicio = '';
  int? _stampNum;
  DateTime _mesVisto = DateTime.now();
  List<Habito> habitos = [];
  List<Recordatorio> recordatorios = [];
  Map<String, Map<String, int>> regs = {};
  bool celebrando = false;
  Recordatorio? _activo;
  final Set<String> _firedDia = {};
  final Map<String, DateTime> _pospuestos = {};
  Timer? _tick;
  static void Function(bool)? _puente;
  late final AnimationController _m = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final AnimationController _reloj = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  late final AnimationController _fuego = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final AnimationController _stamp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  static const fondo = Color(0xFF0A0E14);
  static const tarjeta = Color(0xFF121822);
  static const cian = Color(0xFF00D4FF);
  static const lima = Color(0xFF7CFF00);
  static const magenta = Color(0xFFFF3D71);
  static const oro = Color(0xFFFFB300);
  static const rojo = Color(0xFFFF4D4D);

  static const _palette = [
    0xFF00D4FF,
    0xFF7CFF00,
    0xFFFFB300,
    0xFFFF3D71,
    0xFFB388FF,
    0xFF00FFA3,
    0xFFFF6B00,
    0xFF4D7CFF,
    0xFFFF4D4D,
    0xFF00E5FF,
    0xFFFFEA00,
    0xFFE040FB,
  ];
  static const _iconKeys = [
    'drop',
    'fit',
    'brain',
    'book',
    'sleep',
    'money',
    'code',
    'star',
    'food',
    'run',
    'meditate',
    'music',
    'study',
    'heart',
    'fire',
    'target',
  ];
  static const _animKeys = ['water', 'fire', 'bolt', 'zen'];
  static const _rangos = [
    'Principiante',
    'Constante',
    'Disciplinado',
    'Maestro',
    'Leyenda',
  ];
  static const _diasL = [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
    'domingo',
  ];
  static const _mesesL = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  @override
  void initState() {
    super.initState();
    _cargar().then((_) => _pedirPermisos());
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => _revisar());
    AwesomeNotifications().setListeners(onActionReceivedMethod: _onAction);
    _puente = (hecho) {
      if (_activo == null) return;
      _cerrar(hecho);
    };
  }

  @override
  void dispose() {
    _tick?.cancel();
    _m.dispose();
    _reloj.dispose();
    _fuego.dispose();
    _wave.dispose();
    _stamp.dispose();
    super.dispose();
  }

  @pragma('vm:entry-point')
  static Future<void> _onAction(ReceivedAction a) async {
    if (a.buttonKeyPressed == 'HECHO') {
      _puente?.call(true);
    }
    if (a.buttonKeyPressed == 'POSTERGAR') {
      if (_puente == null) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: a.id ?? 1,
            channelKey: 'ghost_alarm',
            title: a.title,
            body: a.body,
            wakeUpScreen: true,
            fullScreenIntent: true,
            category: NotificationCategory.Alarm,
            criticalAlert: true,
            autoDismissible: false,
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'HECHO',
              label: 'HECHO',
              color: const Color(0xFF7CFF00),
              actionType: ActionType.DismissAction,
            ),
            NotificationActionButton(
              key: 'POSTERGAR',
              label: '+10 MIN',
              color: const Color(0xFFFFB300),
            ),
          ],
        );
      } else {
        _puente!.call(false);
      }
    }
  }

  Future<void> _pedirPermisos() async {
    final ok = await AwesomeNotifications().isNotificationAllowed();
    if (!ok)
      await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  IconData _icon(String k) {
    switch (k) {
      case 'drop':
        return Icons.water_drop_rounded;
      case 'fit':
        return Icons.fitness_center_rounded;
      case 'brain':
        return Icons.psychology_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      case 'sleep':
        return Icons.nightlight_rounded;
      case 'money':
        return Icons.payments_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'run':
        return Icons.directions_run_rounded;
      case 'meditate':
        return Icons.self_improvement_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'study':
        return Icons.school_rounded;
      case 'heart':
        return Icons.favorite_rounded;
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'target':
        return Icons.track_changes_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  IconData _animIcon(String a) => a == 'water'
      ? Icons.waves_rounded
      : a == 'fire'
      ? Icons.local_fire_department_rounded
      : a == 'bolt'
      ? Icons.flash_on_rounded
      : Icons.self_improvement_rounded;

  String _hoy() => DateTime.now().toIso8601String().substring(0, 10);
  String _fecha(DateTime d) => d.toIso8601String().substring(0, 10);

  String _fechaBonita(String f) {
    final d = DateTime.tryParse(f) ?? DateTime.now();
    return _diasL[d.weekday - 1] +
        ' ' +
        d.day.toString() +
        ' ' +
        _mesesL[d.month - 1];
  }

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos dias';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _fechaLarga() {
    final n = DateTime.now();
    return _diasL[n.weekday - 1] +
        ' ' +
        n.day.toString() +
        ' ' +
        _mesesL[n.month - 1];
  }

  int _count(String hid) => regs[_hoy()]?[hid] ?? 0;
  bool _done(Habito h, [String? f]) =>
      (regs[f ?? _hoy()]?[h.id] ?? 0) >= h.meta;

  double _fracDia(String f) => habitos.isEmpty
      ? 0
      : habitos.where((h) => _done(h, f)).length / habitos.length;

  Color _colorCumple(double f) => f >= 1.0 ? lima : (f >= 0.5 ? oro : rojo);

  int get _racha {
    var r = 0;
    var d = DateTime.now();
    while (true) {
      final f = _fecha(d);
      if (!(regs[f] != null && regs[f]!.isNotEmpty)) break;
      r++;
      d = d.subtract(const Duration(days: 1));
    }
    return r;
  }

  int _rachaDe(Habito h) {
    var r = 0;
    var d = DateTime.now();
    while (_done(h, _fecha(d))) {
      r++;
      d = d.subtract(const Duration(days: 1));
    }
    return r;
  }

  int get _diasReto {
    if (retoInicio.isEmpty) return 0;
    final ini = DateTime.tryParse(retoInicio) ?? DateTime.now();
    return DateTime.now().difference(ini).inDays + 1;
  }

  int get _rangoIdx {
    if (retoDias <= 0) return 0;
    final p = (_diasReto.clamp(0, retoDias) / retoDias).clamp(0.0, 1.0);
    return (p * _rangos.length).floor().clamp(0, _rangos.length - 1);
  }

  Future<void> _cargar() async {
    final p = await SharedPreferences.getInstance();
    final hs = p.getString('g_habitos');
    habitos = hs == null
        ? []
        : (jsonDecode(hs) as List)
              .map((e) => Habito.fromJson(e as Map<String, dynamic>))
              .toList();
    final rs2 = p.getString('g_records');
    recordatorios = rs2 == null
        ? []
        : (jsonDecode(rs2) as List)
              .map((e) => Recordatorio.fromJson(e as Map<String, dynamic>))
              .toList();
    final rs = p.getString('g_regs') ?? '{}';
    regs = (jsonDecode(rs) as Map).map(
      (k, v) => MapEntry(
        k as String,
        (v as Map).map((a, b) => MapEntry(a as String, (b as num).toInt())),
      ),
    );
    xp = p.getInt('g_xp') ?? 0;
    retoDias = p.getInt('g_reto_dias') ?? 90;
    retoInicio = p.getString('g_reto_inicio') ?? '';
    setState(() {});
  }

  Future<void> _guardar() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'g_habitos',
      jsonEncode(habitos.map((e) => e.toJson()).toList()),
    );
    await p.setString(
      'g_records',
      jsonEncode(recordatorios.map((e) => e.toJson()).toList()),
    );
    await p.setString('g_regs', jsonEncode(regs));
    await p.setInt('g_xp', xp);
    await p.setInt('g_reto_dias', retoDias);
    await p.setString('g_reto_inicio', retoInicio);
  }

  void _sumar(Habito h) {
    final f = _hoy();
    final m = regs.putIfAbsent(f, () => {});
    final cur = m[h.id] ?? 0;
    if (cur >= h.meta) return;
    setState(() {
      m[h.id] = cur + 1;
      xp += 5;
      if (cur + 1 == h.meta) xp += 10;
    });
    HapticFeedback.lightImpact();
    if (cur + 1 == h.meta) {
      final n = habitos.where((x) => _done(x)).length;
      _estampar(n);
    }
    final todos = habitos.isNotEmpty && habitos.every((x) => _done(x));
    if (todos && !celebrando) _celebrar();
    _guardar();
  }

  void _estampar(int n) {
    setState(() => _stampNum = n);
    _stamp.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _stampNum = null);
    });
  }

  Future<void> _celebrar() async {
    setState(() => celebrando = true);
    _fuego.forward(from: 0);
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 2600));
    if (mounted) setState(() => celebrando = false);
  }

  void _revisar() {
    if (_activo != null) return;
    final n = DateTime.now();
    final hm =
        n.hour.toString().padLeft(2, '0') +
        ':' +
        n.minute.toString().padLeft(2, '0');
    for (final r in recordatorios) {
      if (!r.activo) continue;
      final pos = _pospuestos[r.id];
      if (pos != null && n.isAfter(pos)) {
        _pospuestos.remove(r.id);
        _disparar(r);
        return;
      }
      final key = r.id + '_' + _hoy();
      if (r.hora == hm && !_firedDia.contains(key)) {
        _firedDia.add(key);
        _disparar(r);
        return;
      }
    }
  }

  void _disparar(Recordatorio r) {
    setState(() => _activo = r);
    _wave.repeat();
    _stamp.forward(from: 0);
    HapticFeedback.heavyImpact();
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 500000 + r.id.hashCode.abs() % 100000,
        channelKey: 'ghost_alarm',
        title: r.nombre,
        body: 'Recordatorio: cumple ahora',
        wakeUpScreen: true,
        fullScreenIntent: true,
        category: NotificationCategory.Alarm,
        criticalAlert: true,
        autoDismissible: false,
        customSound: r.sonido,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'HECHO',
          label: 'HECHO',
          color: const Color(0xFF7CFF00),
          actionType: ActionType.DismissAction,
        ),
        NotificationActionButton(
          key: 'POSTERGAR',
          label: '+10 MIN',
          color: const Color(0xFFFFB300),
        ),
      ],
    );
  }

  void _cerrar(bool hecho) {
    final r = _activo;
    if (r == null) return;
    setState(() {
      _activo = null;
      if (hecho) {
        final f = _hoy();
        regs.putIfAbsent(f, () => {})[r.id] = (regs[f]?[r.id] ?? 0) + 1;
        xp += 5;
      } else {
        _pospuestos[r.id] = DateTime.now().add(const Duration(minutes: 10));
      }
    });
    _wave.stop();
    _guardar();
    HapticFeedback.mediumImpact();
  }

  Future<void> _borrar(Habito h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: tarjeta,
        title: Text(
          'Eliminar ' + h.nombre,
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Se borra el habito, no tu historial.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: magenta),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Si'),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (h.alarma)
        await AwesomeNotifications().cancel(h.id.hashCode.abs() % 100000);
      setState(() => habitos.remove(h));
      _guardar();
    }
  }

  Future<void> _borrarRec(Recordatorio r) async {
    await AwesomeNotifications().cancel(500000 + r.id.hashCode.abs() % 100000);
    setState(() => recordatorios.remove(r));
    _guardar();
  }

  Future<void> _programarAlarma(Habito h) async {
    if (!h.alarma) {
      await AwesomeNotifications().cancel(h.id.hashCode.abs() % 100000);
      return;
    }
    final partes = h.hora.split(':');
    final hh = int.tryParse(partes[0]) ?? 7;
    final mm = int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0;
    var when = DateTime.now().copyWith(hour: hh, minute: mm, second: 0);
    if (when.isBefore(DateTime.now())) when = when.add(const Duration(days: 1));
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: h.id.hashCode.abs() % 100000,
        channelKey: 'ghost_alarm',
        title: h.nombre,
        body: 'Hora de cumplir. Meta: ' + h.meta.toString(),
        wakeUpScreen: true,
        fullScreenIntent: true,
        category: NotificationCategory.Alarm,
        criticalAlert: true,
        autoDismissible: false,
        customSound: h.sonido,
        displayOnForeground: true,
        displayOnBackground: true,
      ),
      schedule: NotificationCalendar.fromDate(date: when),
      actionButtons: [
        NotificationActionButton(
          key: 'HECHO',
          label: 'HECHO',
          color: const Color(0xFF7CFF00),
          actionType: ActionType.DismissAction,
        ),
        NotificationActionButton(
          key: 'POSTERGAR',
          label: '+10 MIN',
          color: const Color(0xFFFFB300),
        ),
      ],
    );
  }

  Future<void> _programarRec(Recordatorio r) async {
    await AwesomeNotifications().cancel(500000 + r.id.hashCode.abs() % 100000);
    if (!r.activo) return;
    final partes = r.hora.split(':');
    final hh = int.tryParse(partes[0]) ?? 7;
    final mm = int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0;
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 500000 + r.id.hashCode.abs() % 100000,
        channelKey: 'ghost_alarm',
        title: r.nombre,
        body: 'Recordatorio diario',
        wakeUpScreen: true,
        fullScreenIntent: true,
        category: NotificationCategory.Alarm,
        criticalAlert: true,
        autoDismissible: false,
        customSound: r.sonido,
      ),
      schedule: NotificationCalendar(hour: hh, minute: mm, repeats: true),
      actionButtons: [
        NotificationActionButton(
          key: 'HECHO',
          label: 'HECHO',
          color: const Color(0xFF7CFF00),
          actionType: ActionType.DismissAction,
        ),
        NotificationActionButton(
          key: 'POSTERGAR',
          label: '+10 MIN',
          color: const Color(0xFFFFB300),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext c) => Stack(
    children: [
      Scaffold(
        backgroundColor: fondo,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (ch, a) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(a),
              child: FadeTransition(opacity: a, child: ch),
            ),
            child: KeyedSubtree(
              key: ValueKey<int>(tab),
              child: [_hoyTab(), _progTab(), _recTab(), _habTab()][tab],
            ),
          ),
        ),
        bottomNavigationBar: _bar(),
      ),
      if (celebrando) _celebracion(),
      if (_stampNum != null) _stampProgreso(),
      if (_activo != null) _lockOverlay(),
    ],
  );

  Widget _stampProgreso() {
    final n = _stampNum ?? 0;
    final frac = habitos.isEmpty ? 0.0 : n / habitos.length;
    final c = _colorCumple(frac);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _stamp,
        builder: (ctx, ch) {
          final t = _stamp.value;
          final op = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
          return Opacity(
            opacity: op,
            child: Center(
              child: Transform.rotate(
                angle: -0.14,
                child: Transform.scale(
                  scale:
                      1 +
                      2.0 *
                          (1 - Curves.easeOutBack.transform(t.clamp(0.0, 1.0))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        n.toString(),
                        style: TextStyle(
                          fontSize: 150,
                          fontWeight: FontWeight.w900,
                          color: c,
                          shadows: [
                            Shadow(
                              color: c.withValues(alpha: 0.8),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'DE ' + habitos.length.toString() + ' HOY',
                        style: const TextStyle(
                          color: Colors.white70,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _lockOverlay() {
    final r = _activo!;
    final c = Color(r.color);
    final t = _wave.value;
    final s = _stamp.value;
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          color: fondo,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [c.withValues(alpha: 0.5), fondo],
                    radius: 0.95,
                  ),
                ),
              ),
              if (r.anim == 'water') ...[
                CustomPaint(
                  painter: _WavePainter(
                    t: t,
                    color: c.withValues(alpha: 0.3),
                    level: 0.58,
                    amp: 18,
                  ),
                  size: Size.infinite,
                ),
                CustomPaint(
                  painter: _WavePainter(
                    t: t + 0.4,
                    color: c.withValues(alpha: 0.5),
                    level: 0.66,
                    amp: 12,
                  ),
                  size: Size.infinite,
                ),
                for (var i = 0; i < 8; i++)
                  Positioned(
                    left: (i * 47.0) % 320 + 20,
                    bottom: (t * 300 + i * 90) % 520,
                    child: Opacity(
                      opacity: 0.5,
                      child: Icon(
                        Icons.water_drop_rounded,
                        color: c,
                        size: 10 + (i % 3) * 6,
                      ),
                    ),
                  ),
              ],
              if (r.anim == 'fire') ...[
                for (var i = 0; i < 12; i++)
                  Positioned(
                    left: (i * 61.0) % 320 + 16,
                    bottom: (t * 420 + i * 70) % 620,
                    child: Opacity(
                      opacity: 0.6 - 0.4 * (((t * 420 + i * 70) % 620) / 620),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        color: c,
                        size: 12 + (i % 4) * 5,
                      ),
                    ),
                  ),
                Center(
                  child: Transform.scale(
                    scale: 1 + 0.15 * sin(t * 2 * pi),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      color: c.withValues(alpha: 0.35),
                      size: 190,
                    ),
                  ),
                ),
              ],
              if (r.anim == 'bolt') ...[
                Opacity(
                  opacity: 0.2 + 0.2 * sin(t * 4 * pi),
                  child: Container(color: c.withValues(alpha: 0.3)),
                ),
                Center(
                  child: Transform.rotate(
                    angle: 0.08 * sin(t * 6 * pi),
                    child: Icon(
                      Icons.flash_on_rounded,
                      color: c.withValues(alpha: 0.4),
                      size: 200,
                    ),
                  ),
                ),
              ],
              if (r.anim == 'zen') ...[
                Center(
                  child: Transform.scale(
                    scale: 1 + 0.25 * sin(t * 2 * pi),
                    child: Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.withValues(alpha: 0.6),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.withValues(alpha: 0.5),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.self_improvement_rounded,
                    color: c.withValues(alpha: 0.4),
                    size: 100,
                  ),
                ),
              ],
              Center(
                child: Transform.rotate(
                  angle: -0.16,
                  child: Transform.scale(
                    scale:
                        1 +
                        2.2 *
                            (1 -
                                Curves.easeOutBack.transform(
                                  s.clamp(0.0, 1.0),
                                )),
                    child: Opacity(
                      opacity: s.clamp(0.0, 1.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icon(r.icono), color: Colors.white, size: 64),
                          const SizedBox(height: 10),
                          Text(
                            r.nombre.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            r.hora,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: c,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'CUMPLE AHORA',
                            style: TextStyle(
                              color: Colors.white70,
                              letterSpacing: 3,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 46,
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: c,
                          foregroundColor: const Color(0xFF0A0E14),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onPressed: () => _cerrar(true),
                        child: const Text('HECHO'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onPressed: () => _cerrar(false),
                        child: const Text('+10 MIN'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _celebracion() {
    final r = _racha;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _fuego,
        builder: (c, ch) {
          final t = _fuego.value;
          return Opacity(
            opacity: t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0),
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < 26; i++)
                    Transform.translate(
                      offset: Offset(
                        cos(i * 2 * pi / 26) * 220 * t,
                        sin(i * 2 * pi / 26) * 220 * t - 60 * t,
                      ),
                      child: Transform.rotate(
                        angle: t * 6 + i,
                        child: Icon(
                          Icons.auto_awesome,
                          color: [lima, cian, oro, magenta][i % 4],
                          size: 18 + 10 * sin(t * pi),
                        ),
                      ),
                    ),
                  Transform.scale(
                    scale:
                        0.6 +
                        0.5 * Curves.elasticOut.transform(t.clamp(0.0, 1.0)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          color: oro,
                          size: 90 + 20 * sin(t * pi * 3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'RACHA x' + r.toString(),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'TODOS LOS HABITOS HOY',
                          style: TextStyle(
                            color: lima,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
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

  Color _tabColor(int i) =>
      i == 0 ? cian : (i == 1 ? lima : (i == 2 ? magenta : oro));

  Widget _bar() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: tarjeta,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cian.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: cian.withValues(alpha: 0.12), blurRadius: 20),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [0, 1, 2, 3]
            .map(
              (i) => _btn(
                i,
                i == 0
                    ? Icons.bolt_rounded
                    : (i == 1
                          ? Icons.bar_chart_rounded
                          : (i == 2
                                ? Icons.alarm_rounded
                                : Icons.tune_rounded)),
                i == 0
                    ? 'HOY'
                    : (i == 1 ? 'PROG' : (i == 2 ? 'RECORD' : 'HABITOS')),
              ),
            )
            .toList(),
      ),
    ),
  );

  Widget _btn(int i, IconData ic, String l) {
    final sel = tab == i;
    final c = _tabColor(i);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => tab = i);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? c.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: sel
              ? [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 14)]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic, color: sel ? c : Colors.white38, size: 22),
            const SizedBox(height: 3),
            Text(
              l,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: sel ? c : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowCard(
    Color c,
    Widget child, {
    double blur = 16,
    double alpha = 0.2,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: tarjeta,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: c.withValues(alpha: alpha + 0.15)),
      boxShadow: [
        BoxShadow(
          color: c.withValues(alpha: alpha),
          blurRadius: blur,
          spreadRadius: 1,
        ),
      ],
    ),
    child: child,
  );

  Widget _hoyTab() {
    final doneCount = habitos.where((h) => _done(h)).length;
    final frac = habitos.isEmpty ? 0.0 : doneCount / habitos.length;
    final cc = _colorCumple(frac);
    final rango = _rangos[_rangoIdx];
    final progReto = retoDias <= 0
        ? 0.0
        : (_diasReto.clamp(0, retoDias) / retoDias).clamp(0.0, 1.0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Row(
          children: [
            AnimatedBuilder(
              animation: _m,
              builder: (c, ch) => Transform.translate(
                offset: Offset(0, -4 * sin(_m.value * pi)),
                child: Transform.rotate(
                  angle: 0.07 * sin(_m.value * 2 * pi),
                  child: ch,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cian.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: cian.withValues(alpha: 0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: oro,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _saludo() + ', capitan',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _fechaLarga(),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _reloj,
              builder: (c, ch) {
                final n = DateTime.now();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cian.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cian.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    n.hour.toString().padLeft(2, '0') +
                        ':' +
                        n.minute.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      color: cian,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _glowCard(
          cian,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: oro, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    rango.toUpperCase(),
                    style: const TextStyle(
                      color: oro,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Dia ' + _diasReto.toString() + ' / ' + retoDias.toString(),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progReto),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (c, f, ch) => LinearProgressIndicator(
                    value: f,
                    minHeight: 10,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(cian),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _rangos
                    .asMap()
                    .entries
                    .map(
                      (e) => Text(
                        e.value.substring(0, 1),
                        style: TextStyle(
                          fontSize: 9,
                          color: e.key <= _rangoIdx ? cian : Colors.white24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          alpha: 0.22,
        ),
        _glowCard(
          cc,
          Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: frac),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (c, f, ch) => SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: f,
                        strokeWidth: 8,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(cc),
                      ),
                      Text(
                        (f * 100).round().toString() + '%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: cc,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COMPLETADO HOY',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      doneCount.toString() +
                          ' de ' +
                          habitos.length.toString() +
                          ' habitos',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Racha: ' +
                          _racha.toString() +
                          ' dias  ·  XP ' +
                          xp.toString(),
                      style: TextStyle(
                        color: oro,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          alpha: 0.25,
        ),
        if (habitos.isEmpty)
          _glowCard(
            magenta,
            Column(
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: magenta,
                  size: 40,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sin habitos aun',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Ve a HABITOS y crea tu primer reto',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            alpha: 0.2,
          )
        else
          ...habitos.asMap().entries.map((e) => _card(e.value, e.key)),
      ],
    );
  }

  Widget _card(Habito h, int i) {
    final c = Color(h.color);
    final cnt = _count(h.id);
    final frac = (cnt / h.meta).clamp(0.0, 1.0);
    final done = cnt >= h.meta;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 340 + i * 70),
      curve: Curves.easeOutBack,
      builder: (c2, t, ch) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: ch),
      ),
      child: GestureDetector(
        onTap: () => _sumar(h),
        onLongPress: () => _borrar(h),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tarjeta,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: c.withValues(alpha: done ? 0.9 : 0.35),
              width: done ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: done ? 0.45 : 0.16),
                blurRadius: done ? 26 : 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  TweenAnimationBuilder<double>(
                    key: ValueKey<String>('b' + h.id + cnt.toString()),
                    tween: Tween(begin: 1.35, end: 1.0),
                    duration: const Duration(milliseconds: 340),
                    curve: Curves.easeOutBack,
                    builder: (c3, s, ch) =>
                        Transform.scale(scale: s, child: ch),
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: c.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(_icon(h.icono), color: c, size: 26),
                        ),
                        if (h.alarma)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0A0E14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.alarm_on_rounded,
                                color: oro,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
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
                                h.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (h.alarma)
                              Text(
                                h.hora,
                                style: TextStyle(
                                  color: oro,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: frac),
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutCubic,
                            builder: (c4, f, ch) => LinearProgressIndicator(
                              value: f,
                              minHeight: 8,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation(c),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cnt.toString() + ' / ' + h.meta.toString(),
                          style: TextStyle(
                            color: c,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: frac),
                    duration: const Duration(milliseconds: 500),
                    builder: (c5, f, ch) => SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: f,
                            strokeWidth: 5,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation(c),
                          ),
                          Text(
                            (f * 100).round().toString(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: c,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (cnt > 0)
                Positioned(
                  right: 4,
                  top: -12,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey<String>('x' + h.id + cnt.toString()),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 750),
                    builder: (c6, t, ch) => Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -36 * t),
                        child: ch,
                      ),
                    ),
                    child: Text(
                      '+5',
                      style: TextStyle(
                        color: c,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              if (done)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey<String>('burst' + h.id + cnt.toString()),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      builder: (c7, t, ch) => Opacity(
                        opacity: (1 - t).clamp(0.0, 1.0),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (var k = 0; k < 8; k++)
                              Transform.translate(
                                offset: Offset(
                                  cos(k * pi / 4) * 74 * t,
                                  sin(k * pi / 4) * 74 * t,
                                ),
                                child: Icon(
                                  Icons.auto_awesome,
                                  color: c,
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _calendario() {
    final primero = DateTime(_mesVisto.year, _mesVisto.month, 1);
    final diasMes = DateTime(_mesVisto.year, _mesVisto.month + 1, 0).day;
    final offset = primero.weekday - 1;
    final celdas = <Widget>[];
    for (var i = 0; i < offset; i++) {
      celdas.add(const SizedBox(height: 46));
    }
    for (var d = 1; d <= diasMes; d++) {
      final f = _fecha(DateTime(_mesVisto.year, _mesVisto.month, d));
      final fr = _fracDia(f);
      final hay = regs[f] != null && regs[f]!.isNotEmpty;
      final esHoy = f == _hoy();
      final col = hay ? _colorCumple(fr) : Colors.white10;
      celdas.add(
        GestureDetector(
          onTap: () => _diaDetalle(f),
          child: Container(
            height: 46,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: hay ? col.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: esHoy
                    ? cian
                    : (hay ? col.withValues(alpha: 0.55) : Colors.white10),
                width: esHoy ? 2 : 1,
              ),
              boxShadow: hay
                  ? [
                      BoxShadow(
                        color: col.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  d.toString(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hay ? col : Colors.white38,
                  ),
                ),
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: hay ? col : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final filas = <Widget>[];
    var fila = <Widget>[];
    for (final w in celdas) {
      fila.add(Expanded(child: w));
      if (fila.length == 7) {
        filas.add(Row(children: fila));
        fila = [];
      }
    }
    if (fila.isNotEmpty) {
      while (fila.length < 7) {
        fila.add(const Expanded(child: SizedBox(height: 46)));
      }
      filas.add(Row(children: fila));
    }
    return _glowCard(
      cian,
      Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => _mesVisto = DateTime(
                    _mesVisto.year,
                    _mesVisto.month - 1,
                    1,
                  ),
                ),
                icon: const Icon(Icons.chevron_left_rounded, color: cian),
              ),
              Expanded(
                child: Text(
                  _mesesL[_mesVisto.month - 1].toUpperCase() +
                      ' ' +
                      _mesVisto.year.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => _mesVisto = DateTime(
                    _mesVisto.year,
                    _mesVisto.month + 1,
                    1,
                  ),
                ),
                icon: const Icon(Icons.chevron_right_rounded, color: cian),
              ),
            ],
          ),
          Row(
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                .map(
                  (l) => Expanded(
                    child: Center(
                      child: Text(
                        l,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          ...filas,
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _leyenda(lima, '100%'),
              const SizedBox(width: 14),
              _leyenda(oro, '>=50%'),
              const SizedBox(width: 14),
              _leyenda(rojo, '<50%'),
            ],
          ),
        ],
      ),
      alpha: 0.18,
    );
  }

  Widget _leyenda(Color c, String t) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6),
          ],
        ),
      ),
      const SizedBox(width: 5),
      Text(
        t,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Future<void> _diaDetalle(String f) async {
    final fr = _fracDia(f);
    await showModalBottomSheet(
      context: context,
      backgroundColor: tarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _fechaBonita(f).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              (fr * 100).round().toString() + '% cumplido',
              style: TextStyle(
                color: _colorCumple(fr),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            if (habitos.isEmpty)
              const Text(
                'Sin habitos ese dia',
                style: TextStyle(color: Colors.white38),
              )
            else
              ...habitos.map((h) {
                final cnt = regs[f]?[h.id] ?? 0;
                final st = cnt >= h.meta ? 2 : (cnt > 0 ? 1 : 0);
                final col = st == 2 ? lima : (st == 1 ? oro : rojo);
                final lbl = st == 2 ? 'BIEN' : (st == 1 ? 'A MEDIAS' : 'MAL');
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: col.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(_icon(h.icono), color: col, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          h.nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        cnt.toString() + '/' + h.meta.toString(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          lbl,
                          style: TextStyle(
                            color: col,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _recTab() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    children: [
      const Text(
        'RECORDATORIOS',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 12,
          letterSpacing: 3,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Te bloquean la pantalla hasta que cumplas',
        style: TextStyle(color: Colors.white24, fontSize: 12),
      ),
      const SizedBox(height: 14),
      if (recordatorios.isEmpty)
        _glowCard(
          cian,
          Column(
            children: [
              const Icon(Icons.alarm_off_rounded, color: cian, size: 38),
              const SizedBox(height: 8),
              const Text(
                'Sin recordatorios',
                style: TextStyle(color: Colors.white70),
              ),
              const Text(
                'Crea uno abajo y pruebalo con PROBAR',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
          alpha: 0.18,
        )
      else
        ...recordatorios.map(
          (r) => GestureDetector(
            onLongPress: () => _borrarRec(r),
            child: _glowCard(
              Color(r.color),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(r.color).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _animIcon(r.anim),
                      color: Color(r.color),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          r.hora + '  ·  ' + r.anim,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _disparar(r),
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white70,
                    ),
                  ),
                  Switch(
                    value: r.activo,
                    activeColor: Color(r.color),
                    onChanged: (v) {
                      setState(() {
                        recordatorios.remove(r);
                        recordatorios.add(
                          Recordatorio(
                            id: r.id,
                            nombre: r.nombre,
                            icono: r.icono,
                            color: r.color,
                            hora: r.hora,
                            anim: r.anim,
                            activo: v,
                            sonido: r.sonido,
                          ),
                        );
                      });
                      _programarRec(recordatorios.last);
                      _guardar();
                    },
                  ),
                ],
              ),
              alpha: 0.18,
              blur: 12,
            ),
          ),
        ),
      GestureDetector(
        onTap: _nuevoRec,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: cian.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cian.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: cian.withValues(alpha: 0.2), blurRadius: 16),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_alarm_rounded, color: cian, size: 26),
              SizedBox(width: 8),
              Text(
                'NUEVO RECORDATORIO',
                style: TextStyle(
                  color: cian,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _progTab() {
    final dias = <String>[];
    for (var i = 6; i >= 0; i--) {
      dias.add(_fecha(DateTime.now().subtract(Duration(days: i))));
    }
    const letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: _glowCard(
                oro,
                Column(
                  children: [
                    const Text(
                      'XP TOTAL',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      xp.toString(),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: oro,
                      ),
                    ),
                  ],
                ),
                alpha: 0.22,
              ),
            ),
            Expanded(
              child: _glowCard(
                magenta,
                Column(
                  children: [
                    const Text(
                      'RACHA',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _m,
                          builder: (c, ch) => Transform.scale(
                            scale: 1 + 0.12 * _m.value,
                            child: ch,
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: magenta,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _racha.toString() + ' d',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: magenta,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                alpha: 0.22,
              ),
            ),
          ],
        ),
        _calendario(),
        _glowCard(
          cian,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ULTIMOS 7 DIAS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 110,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: dias.map((f) {
                    final d = DateTime.parse(f);
                    final fr = _fracDia(f);
                    final bc = _colorCumple(fr);
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: fr),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (c, v, ch) => Container(
                              width: 18,
                              height: 6 + 84 * v,
                              decoration: BoxDecoration(
                                color: bc,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: bc.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            letras[d.weekday - 1],
                            style: const TextStyle(
                              color: Colors.white38,
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
        ...habitos.map(
          (h) => _glowCard(
            Color(h.color),
            Row(
              children: [
                Icon(_icon(h.icono), color: Color(h.color), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    h.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  _rachaDe(h).toString() + ' dias seguidos',
                  style: TextStyle(
                    color: Color(h.color),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            alpha: 0.15,
            blur: 10,
          ),
        ),
      ],
    );
  }

  Widget _habTab() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    children: [
      _glowCard(
        cian,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MI RETO',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Duracion (dias):',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                      text: retoDias.toString(),
                    ),
                    style: const TextStyle(
                      color: cian,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                    ),
                    onSubmitted: (v) {
                      setState(
                        () => retoDias = (int.tryParse(v) ?? 90).clamp(1, 3650),
                      );
                      if (retoInicio.isEmpty) retoInicio = _hoy();
                      _guardar();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: cian,
                      foregroundColor: const Color(0xFF0A0E14),
                    ),
                    onPressed: () {
                      setState(() => retoInicio = _hoy());
                      _guardar();
                      HapticFeedback.mediumImpact();
                    },
                    child: const Text('EMPEZAR RETO'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rango actual: ' +
                  _rangos[_rangoIdx] +
                  '  ·  Dia ' +
                  _diasReto.toString() +
                  '/' +
                  retoDias.toString(),
              style: const TextStyle(
                color: oro,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        alpha: 0.2,
      ),
      const SizedBox(height: 4),
      const Text(
        'TUS HABITOS  (toca = editar, manten = eliminar)',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      if (habitos.isEmpty)
        _glowCard(
          magenta,
          const Column(
            children: [
              Icon(Icons.inbox_rounded, color: magenta, size: 36),
              SizedBox(height: 8),
              Text(
                'Crea tu primer habito abajo',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          alpha: 0.18,
        )
      else
        ...habitos.map(
          (h) => GestureDetector(
            onTap: () => _nuevo(editar: h),
            onLongPress: () => _borrar(h),
            child: _glowCard(
              Color(h.color),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(h.color).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _icon(h.icono),
                      color: Color(h.color),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'meta ' +
                              h.meta.toString() +
                              (h.alarma
                                  ? '  ·  alarma ' + h.hora
                                  : '  ·  sin alarma'),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.edit_rounded,
                    color: Colors.white24,
                    size: 18,
                  ),
                ],
              ),
              alpha: 0.15,
              blur: 10,
            ),
          ),
        ),
      GestureDetector(
        onTap: () => _nuevo(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: lima.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: lima.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: lima.withValues(alpha: 0.2), blurRadius: 16),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: lima, size: 26),
              SizedBox(width: 8),
              Text(
                'NUEVO HABITO',
                style: TextStyle(
                  color: lima,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  InputDecoration _dec(String l) => InputDecoration(
    labelText: l,
    labelStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Colors.white10,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  Future<void> _nuevo({Habito? editar}) async {
    final nombre = TextEditingController(text: editar?.nombre ?? '');
    final meta = TextEditingController(text: (editar?.meta ?? 1).toString());
    int color = editar?.color ?? _palette[0];
    String icono = editar?.icono ?? 'star';
    bool alarma = editar?.alarma ?? false;
    var hora = const TimeOfDay(hour: 7, minute: 0);
    if (editar != null) {
      final pp = editar.hora.split(':');
      hora = TimeOfDay(
        hour: int.tryParse(pp[0]) ?? 7,
        minute: int.tryParse(pp.length > 1 ? pp[1] : '0') ?? 0,
      );
    }
    String? sonido = editar?.sonido;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(c).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  editar == null ? 'NUEVO HABITO' : 'EDITAR HABITO',
                  style: TextStyle(
                    color: Color(color),
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nombre,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Nombre del habito'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: meta,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Meta diaria (veces)'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final p in _palette)
                      GestureDetector(
                        onTap: () => setS(() => color = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(p),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == p
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(p).withValues(alpha: 0.5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final k in _iconKeys)
                      GestureDetector(
                        onTap: () => setS(() => icono = k),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: icono == k
                                ? Color(color).withValues(alpha: 0.25)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: icono == k
                                  ? Color(color)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(_icon(k), color: Color(color), size: 22),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: oro,
                  title: const Text(
                    'Activar alarma / recordatorio',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  value: alarma,
                  onChanged: (v) => setS(() => alarma = v),
                ),
                if (alarma) ...[
                  Row(
                    children: [
                      const Text(
                        'Hora:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.tonal(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: hora,
                          );
                          if (t != null) setS(() => hora = t);
                        },
                        child: Text(
                          hora.hour.toString().padLeft(2, '0') +
                              ':' +
                              hora.minute.toString().padLeft(2, '0'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final res = await FilePicker.platform.pickFiles(
                        type: FileType.audio,
                      );
                      if (res != null && res.files.isNotEmpty)
                        setS(() => sonido = res.files.first.path);
                    },
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(
                      sonido == null
                          ? 'Elegir tono propio'
                          : 'Tono propio listo',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Color(color),
                      foregroundColor: const Color(0xFF0A0E14),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: () async {
                      final n = nombre.text.trim();
                      final m = int.tryParse(meta.text) ?? 1;
                      if (n.isEmpty) return;
                      final h = Habito(
                        id:
                            editar?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        nombre: n,
                        icono: icono,
                        color: color,
                        meta: m,
                        alarma: alarma,
                        hora:
                            hora.hour.toString().padLeft(2, '0') +
                            ':' +
                            hora.minute.toString().padLeft(2, '0'),
                        sonido: sonido,
                      );
                      setState(() {
                        if (editar != null) habitos.remove(editar);
                        habitos.add(h);
                      });
                      await _guardar();
                      await _programarAlarma(h);
                      if (mounted) Navigator.pop(c);
                    },
                    child: Text(
                      editar == null ? 'CREAR HABITO' : 'GUARDAR CAMBIOS',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _nuevoRec() async {
    final nombre = TextEditingController();
    int color = _palette[0];
    String icono = 'drop';
    String anim = 'water';
    var hora = const TimeOfDay(hour: 8, minute: 0);
    String? sonido;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(c).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nombre,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Nombre (ej: AGUA)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Hora:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonal(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: hora,
                        );
                        if (t != null) setS(() => hora = t);
                      },
                      child: Text(
                        hora.hour.toString().padLeft(2, '0') +
                            ':' +
                            hora.minute.toString().padLeft(2, '0'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'COLOR DEL BLOQUEO',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final p in _palette)
                      GestureDetector(
                        onTap: () => setS(() => color = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(p),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == p
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(p).withValues(alpha: 0.5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ANIMACION DEL BLOQUEO',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final a in _animKeys)
                      GestureDetector(
                        onTap: () => setS(() => anim = a),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: anim == a
                                ? Color(color).withValues(alpha: 0.25)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: anim == a
                                  ? Color(color)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(_animIcon(a), color: Color(color), size: 20),
                              const SizedBox(width: 6),
                              Text(
                                a.toUpperCase(),
                                style: TextStyle(
                                  color: Color(color),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(
                      type: FileType.audio,
                    );
                    if (res != null && res.files.isNotEmpty)
                      setS(() => sonido = res.files.first.path);
                  },
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(
                    sonido == null ? 'Elegir tono propio' : 'Tono propio listo',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: oro),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      final n = nombre.text.trim().isEmpty
                          ? 'PRUEBA'
                          : nombre.text.trim();
                      final r = Recordatorio(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        nombre: n,
                        icono: icono,
                        color: color,
                        hora:
                            hora.hour.toString().padLeft(2, '0') +
                            ':' +
                            hora.minute.toString().padLeft(2, '0'),
                        anim: anim,
                        sonido: sonido,
                      );
                      Navigator.pop(c);
                      _disparar(r);
                    },
                    child: const Text('PROBAR AHORA'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Color(color),
                      foregroundColor: const Color(0xFF0A0E14),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: () async {
                      final n = nombre.text.trim();
                      if (n.isEmpty) return;
                      final r = Recordatorio(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        nombre: n,
                        icono: icono,
                        color: color,
                        hora:
                            hora.hour.toString().padLeft(2, '0') +
                            ':' +
                            hora.minute.toString().padLeft(2, '0'),
                        anim: anim,
                        sonido: sonido,
                      );
                      setState(() => recordatorios.add(r));
                      await _guardar();
                      await _programarRec(r);
                      if (mounted) Navigator.pop(c);
                    },
                    child: const Text('CREAR RECORDATORIO'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    setState(() {});
  }
}
