import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'ghost_alarm',
      channelName: 'Alarmas Ghost',
      channelDescription: 'Recordatorios que cubren la pantalla',
      defaultColor: const Color(0xFFFF6D00),
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
  final String categoria;

  Recordatorio({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.color,
    required this.hora,
    required this.anim,
    this.activo = true,
    this.sonido,
    this.categoria = 'recordatorio',
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
    'categoria': categoria,
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
    categoria: (j['categoria'] ?? 'recordatorio') as String,
  );
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
  bool vibrar = true;
  int? _stampNum;
  DateTime _mesVisto = DateTime.now();
  List<Habito> habitos = [];
  List<Recordatorio> recordatorios = [];
  Map<String, Map<String, int>> regs = {};
  Map<String, List<String>> fallados = {};
  bool celebrando = false;
  Recordatorio? _activo;
  bool _cargando = false;
  final Set<String> _firedDia = {};
  final Map<String, DateTime> _pospuestos = {};
  Timer? _tick;
  static void Function(bool)? _puente;
  final AudioPlayer _audio = AudioPlayer();
  late final AnimationController _m = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final AnimationController _reloj = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  late final AnimationController _fuego = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final AnimationController _stamp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _charge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  static const fondo = Color(0xFF0A0E14);
  static const tarjeta = Color(0xFF141A25);
  static const cian = Color(0xFF00D4FF);
  static const lima = Color(0xFF7CFF00);
  static const magenta = Color(0xFFFF3D71);
  static const oro = Color(0xFFFFB300);
  static const rojo = Color(0xFFFF4D4D);
  static const violeta = Color(0xFFB388FF);
  static const fuego1 = Color(0xFFFF6D00);
  static const fuego2 = Color(0xFFFFAB40);
  static const fuego3 = Color(0xFFFFD180);

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
    _charge.addStatusListener((st) {
      if (st == AnimationStatus.completed) _cerrar(true);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _m.dispose();
    _reloj.dispose();
    _fuego.dispose();
    _stamp.dispose();
    _fill.dispose();
    _charge.dispose();
    _audio.dispose();
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
              actionType: ActionType.KeepOnTop,
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
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
    await Permission.systemAlertWindow.request();
    await Permission.ignoreBatteryOptimizations.request();
    final ok = await AwesomeNotifications().isNotificationAllowed();
    if (!ok) {
      await AwesomeNotifications().requestPermissionToSendNotifications(
        channelKey: 'ghost_alarm',
        permissions: [
          NotificationPermission.Alert,
          NotificationPermission.Sound,
          NotificationPermission.Badge,
          NotificationPermission.CriticalAlert,
          NotificationPermission.FullScreenIntent,
          NotificationPermission.Vibration,
        ],
      );
    }
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

  String _animDe(String k) => k == 'drop'
      ? 'water'
      : (k == 'fire' || k == 'fit' || k == 'run')
      ? 'fire'
      : (k == 'brain' || k == 'meditate' || k == 'sleep')
      ? 'zen'
      : 'bolt';

  String _catDe(String k) => k == 'drop'
      ? 'agua'
      : (k == 'fit' || k == 'run')
      ? 'cuerpo'
      : (k == 'brain' || k == 'meditate' || k == 'book' || k == 'study')
      ? 'mente'
      : (k == 'sleep')
      ? 'sueno'
      : (k == 'money')
      ? 'plata'
      : (k == 'code')
      ? 'codigo'
      : 'habito';

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

  Future<String?> _copiarSonido(String origen) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final g = Directory(dir.path + '/ghost_sonidos');
      if (!await g.exists()) await g.create(recursive: true);
      final nombre =
          DateTime.now().millisecondsSinceEpoch.toString() +
          '_' +
          origen.split('/').last;
      await File(origen).copy(g.path + '/' + nombre);
      return g.path + '/' + nombre;
    } catch (e) {
      return null;
    }
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
    final fs = p.getString('g_falls') ?? '{}';
    fallados = (jsonDecode(fs) as Map).map(
      (k, v) => MapEntry(k as String, (v as List).cast<String>()),
    );
    xp = p.getInt('g_xp') ?? 0;
    retoDias = p.getInt('g_reto_dias') ?? 90;
    retoInicio = p.getString('g_reto_inicio') ?? '';
    vibrar = p.getBool('g_vibrar') ?? true;
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
    await p.setString('g_falls', jsonEncode(fallados));
    await p.setInt('g_xp', xp);
    await p.setInt('g_reto_dias', retoDias);
    await p.setString('g_reto_inicio', retoInicio);
    await p.setBool('g_vibrar', vibrar);
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
    if (vibrar) HapticFeedback.lightImpact();
    if (cur + 1 == h.meta) {
      final n = habitos.where((x) => _done(x)).length;
      _estampar(n);
    }
    final todos = habitos.isNotEmpty && habitos.every((x) => _done(x));
    if (todos && !celebrando) _celebrar();
    _guardar();
  }

  void _fallar(Habito h) {
    final f = _hoy();
    final list = fallados.putIfAbsent(f, () => []);
    if (list.contains(h.id)) return;
    setState(() => list.add(h.id));
    SystemSound.play(SystemSoundType.alert);
    if (vibrar) HapticFeedback.heavyImpact();
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
    if (vibrar) HapticFeedback.heavyImpact();
  }

  void _cerrarCelebracion() {
    setState(() => celebrando = false);
    _fuego.stop();
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
    for (final h in habitos) {
      if (!h.alarma) continue;
      final key = 'h_' + h.id + '_' + _hoy();
      if (h.hora == hm && !_firedDia.contains(key)) {
        _firedDia.add(key);
        _disparar(
          Recordatorio(
            id: h.id,
            nombre: h.nombre,
            icono: h.icono,
            color: h.color,
            hora: h.hora,
            anim: _animDe(h.icono),
            sonido: h.sonido,
            categoria: _catDe(h.icono),
          ),
        );
        return;
      }
    }
  }

  void _disparar(Recordatorio r) {
    setState(() => _activo = r);
    _stamp.forward(from: 0);
    _fill.forward(from: 0);
    if (vibrar) HapticFeedback.heavyImpact();
    if (r.sonido != null) {
      _audio.stop();
      _audio.play(DeviceFileSource(r.sonido!));
    }
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 500000 + r.id.hashCode.abs() % 100000,
        channelKey: 'ghost_alarm',
        title: r.nombre,
        body: r.categoria.toUpperCase() + ' · cumple ahora',
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
          actionType: ActionType.KeepOnTop,
        ),
        NotificationActionButton(
          key: 'POSTERGAR',
          label: '+10 MIN',
          color: const Color(0xFFFFB300),
        ),
      ],
    );
  }

  Future<void> _alarmaPrueba() async {
    final when = DateTime.now().add(const Duration(minutes: 1));
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 999999,
        channelKey: 'ghost_alarm',
        title: 'PRUEBA REAL',
        body: 'Si ves esto cubriendo tu pantalla, la alarma vive',
        wakeUpScreen: true,
        fullScreenIntent: true,
        category: NotificationCategory.Alarm,
        criticalAlert: true,
        autoDismissible: false,
      ),
      schedule: NotificationCalendar.fromDate(date: when),
      actionButtons: [
        NotificationActionButton(
          key: 'HECHO',
          label: 'HECHO',
          color: const Color(0xFF7CFF00),
          actionType: ActionType.KeepOnTop,
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
    _audio.stop();
    AwesomeNotifications().cancel(500000 + r.id.hashCode.abs() % 100000);
    setState(() {
      _activo = null;
      _cargando = false;
      _charge.reset();
      if (hecho) {
        final f = _hoy();
        regs.putIfAbsent(f, () => {})[r.id] = (regs[f]?[r.id] ?? 0) + 1;
        xp += 5;
      } else {
        _pospuestos[r.id] = DateTime.now().add(const Duration(minutes: 10));
      }
    });
    _guardar();
    if (vibrar) HapticFeedback.mediumImpact();
  }

  void _hecho() {
    if (_cargando) return;
    setState(() => _cargando = true);
    _charge.forward(from: 0);
    if (vibrar) HapticFeedback.mediumImpact();
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
        displayOnForeground: true,
        displayOnBackground: true,
      ),
      schedule: NotificationCalendar.fromDate(date: when),
      actionButtons: [
        NotificationActionButton(
          key: 'HECHO',
          label: 'HECHO',
          color: const Color(0xFF7CFF00),
          actionType: ActionType.KeepOnTop,
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
      ),
      schedule: NotificationCalendar(hour: hh, minute: mm, repeats: true),
      actionButtons: [
        NotificationActionButton(
          key: 'HECHO',
          label: 'HECHO',
          color: const Color(0xFF7CFF00),
          actionType: ActionType.KeepOnTop,
        ),
        NotificationActionButton(
          key: 'POSTERGAR',
          label: '+10 MIN',
          color: const Color(0xFFFFB300),
        ),
      ],
    );
  }

  Widget _fuegoVivo(double size) {
    return AnimatedBuilder(
      animation: _m,
      builder: (c, ch) {
        final f = _m.value;
        final flick = 0.9 + 0.1 * sin(f * pi * 2);
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: fuego1.withValues(alpha: 0.22),
                size: size * 1.5,
                shadows: [
                  Shadow(color: fuego1.withValues(alpha: 0.6), blurRadius: 30),
                ],
              ),
              Transform.scale(
                scale: flick,
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: fuego1,
                  size: size,
                ),
              ),
              Transform.scale(
                scale: 2 - flick,
                child: Icon(
                  Icons.whatshot_rounded,
                  color: fuego2,
                  size: size * 0.62,
                ),
              ),
              Transform.scale(
                scale: flick,
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: fuego3,
                  size: size * 0.34,
                ),
              ),
            ],
          ),
        );
      },
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
              child: [_hoyTab(), _progTab(), _alarmTab(), _ajustesTab()][tab],
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
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: Listenable.merge([_charge, _stamp]),
          builder: (ctx, ch) {
            final s = _stamp.value;
            final q = _charge.value;
            return Container(
              color: const Color(0xFF05070B),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    Opacity(
                      opacity: s.clamp(0.0, 1.0),
                      child: Text(
                        r.nombre.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: c,
                          shadows: [
                            Shadow(
                              color: c.withValues(alpha: 0.8),
                              blurRadius: 24,
                            ),
                            Shadow(
                              color: c.withValues(alpha: 0.4),
                              blurRadius: 60,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      r.categoria.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.hora,
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 6,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            height: 220,
                            child: CircularProgressIndicator(
                              value: q,
                              strokeWidth: 6,
                              strokeCap: StrokeCap.round,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation(c),
                            ),
                          ),
                          if (q > 0)
                            Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.35 * q),
                                    blurRadius: 40,
                                  ),
                                ],
                              ),
                            ),
                          Icon(
                            _icon(r.icono),
                            color: q >= 1
                                ? c
                                : Colors.white.withValues(alpha: 0.85),
                            size: 70,
                            shadows: [
                              Shadow(
                                color: c.withValues(alpha: 0.6),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: c,
                                foregroundColor: const Color(0xFF05070B),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _cargando ? null : _hecho,
                              child: const Text(
                                'HECHO',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _cargando
                                  ? null
                                  : () => _cerrar(false),
                              child: const Text(
                                '+10 MIN',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
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
      ),
    );
  }

  Widget _celebracion() {
    final r = _racha;
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _fuego,
          builder: (c, ch) {
            final t = _fuego.value;
            final e = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
            final numT = Curves.easeOutBack.transform(
              ((t - 0.4) / 0.6).clamp(0.0, 1.0),
            );
            return Container(
              color: Colors.black.withValues(alpha: 0.88),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: fuego1.withValues(alpha: 0.18 * e),
                    size: 120 + 160 * e,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _fuegoVivo(90 + 40 * e),
                          const SizedBox(width: 14),
                          Transform.rotate(
                            angle: -0.12 * numT,
                            child: Transform.scale(
                              scale: 1 + 2.0 * (1 - numT),
                              child: Text(
                                r.toString(),
                                style: const TextStyle(
                                  fontSize: 90,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(color: fuego1, blurRadius: 30),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: e,
                        child: const Text(
                          'DIAS DE RACHA',
                          style: TextStyle(
                            color: Colors.white54,
                            letterSpacing: 4,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 46),
                      SizedBox(
                        width: 160,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: fuego1,
                            foregroundColor: const Color(0xFF0A0E14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _cerrarCelebracion,
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _tabColor(int i) =>
      i == 0 ? fuego1 : (i == 1 ? lima : (i == 2 ? magenta : violeta));

  Widget _bar() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: tarjeta,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: fuego1.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: fuego1.withValues(alpha: 0.12), blurRadius: 20),
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
                                : Icons.settings_rounded)),
                i == 0
                    ? 'HOY'
                    : (i == 1 ? 'PROG' : (i == 2 ? 'ALARMAS' : 'AJUSTES')),
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
        if (vibrar) HapticFeedback.selectionClick();
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
    double blur = 10,
    double alpha = 0.12,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: tarjeta,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: c.withValues(alpha: alpha + 0.10)),
      boxShadow: [
        BoxShadow(
          color: c.withValues(alpha: alpha * 0.7),
          blurRadius: blur,
        ),
      ],
    ),
    child: child,
  );

  Widget _circleTile(Habito h) {
    final c = Color(h.color);
    final cnt = _count(h.id);
    final frac = (cnt / h.meta).clamp(0.0, 1.0);
    final done = cnt >= h.meta;
    final failed = fallados[_hoy()]?.contains(h.id) == true;
    return GestureDetector(
      onTap: () => _sumar(h),
      onLongPress: () => _fallar(h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: failed
                  ? rojo
                  : (done ? c : Colors.white.withValues(alpha: 0.05)),
              border: Border.all(
                color: failed ? rojo : (done ? c : Colors.white24),
                width: 2,
              ),
              boxShadow: (done || failed)
                  ? [
                      BoxShadow(
                        color: (failed ? rojo : c).withValues(alpha: 0.5),
                        blurRadius: 18,
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: CircularProgressIndicator(
                    value: frac,
                    strokeWidth: 4,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(c),
                  ),
                ),
                Text(
                  h.nombre.isNotEmpty ? h.nombre[0].toUpperCase() : 'G',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: (done || failed)
                        ? const Color(0xFF0A0E14)
                        : Colors.white38,
                  ),
                ),
                if (done)
                  const Positioned(
                    bottom: 8,
                    child: Icon(
                      Icons.check_rounded,
                      color: Color(0xFF0A0E14),
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 90,
            child: Text(
              h.nombre,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
            _fuegoVivo(56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _racha.toString() + ' dias de racha',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: fuego2,
                    ),
                  ),
                  Text(
                    _saludo() + ', capitan · ' + _fechaLarga(),
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
                    color: fuego1.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: fuego1.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    n.hour.toString().padLeft(2, '0') +
                        ':' +
                        n.minute.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      color: fuego2,
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
          fuego1,
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
                    valueColor: AlwaysStoppedAnimation(fuego1),
                  ),
                ),
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
                      'MISION DE HOY',
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
                      'XP ' + xp.toString(),
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
        const SizedBox(height: 4),
        const Text(
          'TOCA = CUMPLIR · MANTEN = FALLAR',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
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
                  'Ve a AJUSTES y crea tu primer reto',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            alpha: 0.2,
          )
        else
          Wrap(
            spacing: 14,
            runSpacing: 18,
            alignment: WrapAlignment.center,
            children: habitos.map((h) => _circleTile(h)).toList(),
          ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _nuevo(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: lima.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: lima.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: lima, size: 22),
                SizedBox(width: 8),
                Text(
                  'NUEVO HABITO',
                  style: TextStyle(
                    color: lima,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusIcon(int st) => st == 2
      ? const Icon(Icons.check_circle_rounded, color: lima, size: 20)
      : st == 1
      ? const Icon(Icons.fiber_manual_record_rounded, color: oro, size: 12)
      : const Icon(Icons.cancel_rounded, color: rojo, size: 20);

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
                    ? fuego1
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
      fuego1,
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
                icon: const Icon(Icons.chevron_left_rounded, color: fuego1),
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
                icon: const Icon(Icons.chevron_right_rounded, color: fuego1),
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
              _leyenda(lima, Icons.check_circle_rounded, '100%'),
              const SizedBox(width: 14),
              _leyenda(oro, Icons.fiber_manual_record_rounded, '>=50%'),
              const SizedBox(width: 14),
              _leyenda(rojo, Icons.cancel_rounded, '<50%'),
            ],
          ),
        ],
      ),
      alpha: 0.18,
    );
  }

  Widget _leyenda(Color c, IconData ic, String t) => Row(
    children: [
      Icon(ic, color: c, size: 12),
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
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: col.withValues(alpha: 0.25)),
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
                            fontSize: 14,
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
                      _statusIcon(st),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

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
                fuego1,
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
                        _fuegoVivo(30),
                        const SizedBox(width: 6),
                        Text(
                          _racha.toString() + ' d',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: fuego2,
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

  Widget _alarmTab() => ListView(
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
                          r.hora + '  ·  ' + r.categoria,
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
                            categoria: r.categoria,
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
      const SizedBox(height: 8),
      const Text(
        'HABITOS CON ALARMA',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 12,
          letterSpacing: 3,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      if (habitos.where((h) => h.alarma).isEmpty)
        const Text(
          'Ningun habito tiene alarma activada',
          style: TextStyle(color: Colors.white24, fontSize: 12),
        )
      else
        ...habitos
            .where((h) => h.alarma)
            .map(
              (h) => GestureDetector(
                onTap: () => _nuevo(editar: h),
                child: _glowCard(
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
                        h.hora,
                        style: TextStyle(
                          color: oro,
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
            ),
      const SizedBox(height: 14),
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
      const SizedBox(height: 10),
      GestureDetector(
        onTap: _alarmaPrueba,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: oro.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: oro.withValues(alpha: 0.5), width: 1.2),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_rounded, color: oro, size: 22),
              SizedBox(width: 8),
              Text(
                'ALARMA REAL EN 1 MIN',
                style: TextStyle(
                  color: oro,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _ajustesTab() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    children: [
      _glowCard(
        fuego1,
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
                      color: fuego2,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
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
                      backgroundColor: fuego1,
                      foregroundColor: const Color(0xFF0A0E14),
                    ),
                    onPressed: () {
                      setState(() => retoInicio = _hoy());
                      _guardar();
                      if (vibrar) HapticFeedback.mediumImpact();
                    },
                    child: const Text('EMPEZAR RETO'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rango: ' +
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
      _glowCard(
        violeta,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PREFERENCIAS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: violeta,
              title: const Text(
                'Vibracion',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              value: vibrar,
              onChanged: (v) {
                setState(() => vibrar = v);
                _guardar();
              },
            ),
          ],
        ),
        alpha: 0.18,
      ),
      _glowCard(
        cian,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PERMISOS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Si las alarmas no suenan con la app cerrada, vuelve a pedir permisos y revisa las 4 puertas de XOS.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _pedirPermisos,
                child: const Text('VOLVER A PEDIR PERMISOS'),
              ),
            ),
          ],
        ),
        alpha: 0.18,
      ),
      _glowCard(
        magenta,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TUS HABITOS  (toca = editar, manten = eliminar)',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (habitos.isEmpty)
              const Text(
                'Crea tu primer habito abajo',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              )
            else
              ...habitos.map(
                (h) => GestureDetector(
                  onTap: () => _nuevo(editar: h),
                  onLongPress: () => _borrar(h),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Color(h.color).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(_icon(h.icono), color: Color(h.color), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'meta ' +
                                    h.meta.toString() +
                                    (h.alarma ? '  ·  alarma ' + h.hora : ''),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
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
                  ),
                ),
              ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _nuevo(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: lima.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: lima.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: lima, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'NUEVO HABITO',
                      style: TextStyle(
                        color: lima,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        alpha: 0.15,
      ),
      _glowCard(
        oro,
        Row(
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              color: oro,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GHOST v4',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Sistema operativo personal',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        alpha: 0.15,
      ),
    ],
  );

  InputDecoration _dec(String l) => InputDecoration(
    labelText: l,
    labelStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
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
                                : Colors.white.withValues(alpha: 0.04),
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
                      if (res != null && res.files.isNotEmpty) {
                        final interno = await _copiarSonido(
                          res.files.first.path!,
                        );
                        setS(() => sonido = interno);
                      }
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
                                : Colors.white.withValues(alpha: 0.04),
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
                    if (res != null && res.files.isNotEmpty) {
                      final interno = await _copiarSonido(
                        res.files.first.path!,
                      );
                      setS(() => sonido = interno);
                    }
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
