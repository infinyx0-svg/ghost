import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'dart:convert';

void main() => runApp(const GhostHabitosApp());

// ---------- MODELO ----------
class Habito {
  String id;
  String nombre;
  String categoria;
  int hora;
  int minuto;
  int duracionMin;
  List<int> dias; // 1=Lun ... 7=Dom
  bool activado;
  int racha;
  Map<String, bool> historial;

  Habito({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.hora,
    required this.minuto,
    this.duracionMin = 30,
    required this.dias,
    this.activado = true,
    this.racha = 0,
    Map<String, bool>? historial,
  }) : historial = historial ?? {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'categoria': categoria,
    'hora': hora,
    'minuto': minuto,
    'duracionMin': duracionMin,
    'dias': dias,
    'activado': activado,
    'racha': racha,
    'historial': historial,
  };

  static Habito fromJson(Map<String, dynamic> j) => Habito(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    categoria: j['categoria'] as String,
    hora: (j['hora'] as num).toInt(),
    minuto: (j['minuto'] as num).toInt(),
    duracionMin: (j['duracionMin'] as num?)?.toInt() ?? 30,
    dias: (j['dias'] as List).map((e) => (e as num).toInt()).toList(),
    activado: (j['activado'] as bool?) ?? true,
    racha: (j['racha'] as num?)?.toInt() ?? 0,
    historial:
        (j['historial'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as bool?) ?? false),
        ) ??
        {},
  );

  String get horaTexto =>
      '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';
}

// ---------- CATEGORÍAS ----------
class CatConf {
  final IconData icono;
  final Color color;
  const CatConf(this.icono, this.color);
}

const _cats = {
  'CUERPO': CatConf(Icons.fitness_center_rounded, Color(0xFFFF6B35)),
  'MENTE': CatConf(Icons.psychology_rounded, Color(0xFF00B3FF)),
  'NEGOCIO': CatConf(Icons.trending_up_rounded, Color(0xFF00FF88)),
  'ESPIRITU': CatConf(Icons.self_improvement_rounded, Color(0xFFB44CFF)),
};

CatConf _conf(String cat) =>
    _cats[cat] ?? const CatConf(Icons.star_rounded, Color(0xFF00FF88));

const _wd = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _diasLetra = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

// ---------- APP ----------
class GhostHabitosApp extends StatelessWidget {
  const GhostHabitosApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ghost',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF07070C),
      colorScheme: const ColorScheme.dark(primary: Color(0xFF00FF88)),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      dialogBackgroundColor: const Color(0xFF12121A),
    ),
    home: const HabitosScreen(),
  );
}

// ---------- PANTALLA ----------
class HabitosScreen extends StatefulWidget {
  const HabitosScreen({super.key});
  @override
  State<HabitosScreen> createState() => _HabitosScreenState();
}

class _HabitosScreenState extends State<HabitosScreen> {
  List<Habito> _habitos = [];
  bool _cargado = false;
  Timer? _tick;

  String get _hoy {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}';
  }

  @override
  void initState() {
    super.initState();
    _cargar();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('habitos') ?? '[]';
    setState(() {
      _habitos = (jsonDecode(raw) as List)
          .map((e) => Habito.fromJson(e as Map<String, dynamic>))
          .toList();
      _ordenar();
      _cargado = true;
    });
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'habitos',
      jsonEncode(_habitos.map((e) => e.toJson()).toList()),
    );
  }

  void _ordenar() => _habitos.sort(
    (a, b) => (a.hora * 60 + a.minuto).compareTo(b.hora * 60 + b.minuto),
  );

  Future<void> _toggle(Habito h) async {
    setState(() {
      final era = h.historial[_hoy] ?? false;
      h.historial[_hoy] = !era;
      h.racha = !era ? h.racha + 1 : (h.racha > 0 ? h.racha - 1 : 0);
    });
    await _guardar();
  }

  MapEntry<Habito, DateTime>? _proximo() {
    final now = DateTime.now();
    for (int d = 0; d <= 7; d++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
      for (final h in _habitos) {
        if (!h.activado || !h.dias.contains(day.weekday)) continue;
        final t = DateTime(day.year, day.month, day.day, h.hora, h.minuto);
        if (t.isAfter(now)) return MapEntry(h, t);
      }
    }
    return null;
  }

  String _cd(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final totalHoy = _habitos
        .where((h) => h.activado && h.dias.contains(now.weekday))
        .length;
    final hechosHoy = _habitos.where((h) => h.historial[_hoy] == true).length;
    final frac = totalHoy == 0 ? 0.0 : hechosHoy / totalHoy;
    final prox = _proximo();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00FF88),
        onPressed: () async {
          final res = await showDialog<Habito>(
            context: context,
            builder: (_) => const _FormHabito(),
          );
          if (res != null) {
            setState(() {
              _habitos.add(res);
              _ordenar();
            });
            await _guardar();
          }
        },
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      const Text('👻', style: TextStyle(fontSize: 34)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GHOST',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                          Text(
                            '${_wd[now.weekday - 1]} ${now.day}/${now.month}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '$hechosHoy/$totalHoy',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00FF88),
                        ),
                      ),
                    ],
                  ),
                ),
                // PROGRESO DE HOY
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12121A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF1C1C28)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'PROGRESO DE HOY',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                letterSpacing: 2,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(frac * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00FF88),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: frac,
                            minHeight: 8,
                            backgroundColor: const Color(0xFF1C1C28),
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF00FF88),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // PRÓXIMO HÁBITO (CONTADOR EN VIVO)
                if (prox != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            _conf(prox.key.categoria).color.withOpacity(0.22),
                            const Color(0xFF12121A),
                          ],
                        ),
                        border: Border.all(
                          color: _conf(prox.key.categoria).color
                              .withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _conf(prox.key.categoria).icono,
                            color: _conf(prox.key.categoria).color,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PRÓXIMO: ${prox.key.nombre.toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  prox.value.day == now.day
                                      ? 'hoy a las ${prox.key.horaTexto}'
                                      : 'mañana a las ${prox.key.horaTexto}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _cd(prox.value.difference(now)),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _conf(prox.key.categoria).color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // LISTA DE TARJETAS
                Expanded(
                  child: !_cargado
                      ? const Center(child: CircularProgressIndicator())
                      : _habitos.isEmpty
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('👻', style: TextStyle(fontSize: 60)),
                            SizedBox(height: 8),
                            Text(
                              'Sin hábitos todavía.\nToca + para crear el primero.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 90),
                          itemCount: _habitos.length,
                          itemBuilder: (_, i) => _tarjeta(_habitos[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(Habito h) {
    final conf = _conf(h.categoria);
    final hecho = h.historial[_hoy] ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final res = await showDialog<Habito>(
              context: context,
              builder: (_) => _FormHabito(inicial: h),
            );
            if (res != null) {
              setState(() {
                final idx = _habitos.indexWhere((x) => x.id == h.id);
                if (idx >= 0) _habitos[idx] = res;
                _ordenar();
              });
              await _guardar();
            }
          },
          onLongPress: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('¿Borrar hábito?'),
                content: Text(h.nombre),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('NO'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'SÍ',
                      style: TextStyle(color: Color(0xFFFF3355)),
                    ),
                  ),
                ],
              ),
            );
            if (ok == true) {
              setState(() => _habitos.removeWhere((x) => x.id == h.id));
              await _guardar();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: conf.color.withOpacity(hecho ? 0.9 : 0.25),
                width: hecho ? 1.5 : 1,
              ),
              boxShadow: hecho
                  ? [
                      BoxShadow(
                        color: conf.color.withOpacity(0.22),
                        blurRadius: 18,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      h.horaTexto,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: hecho ? Colors.grey : Colors.white,
                      ),
                    ),
                    Text(
                      '${h.duracionMin}m',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(
                  width: 3,
                  height: 38,
                  decoration: BoxDecoration(
                    color: conf.color.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.nombre,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: hecho ? Colors.grey : Colors.white,
                          decoration: hecho ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(conf.icono, size: 13, color: conf.color),
                          const SizedBox(width: 4),
                          Text(
                            h.categoria,
                            style: TextStyle(
                              fontSize: 10,
                              color: conf.color,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            h.dias.map((d) => _diasLetra[d - 1]).join(' '),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (h.racha > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 16,
                        color: Color(0xFFFF6B35),
                      ),
                      Text(
                        '${h.racha}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                GestureDetector(
                  onTap: () => _toggle(h),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hecho ? conf.color : Colors.transparent,
                      border: Border.all(
                        color: hecho ? conf.color : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: hecho
                        ? const Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: Colors.black,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- FORMULARIO ----------
class _FormHabito extends StatefulWidget {
  final Habito? inicial;
  const _FormHabito({this.inicial});
  @override
  State<_FormHabito> createState() => _FormHabitoState();
}

class _FormHabitoState extends State<_FormHabito> {
  final _nombre = TextEditingController();
  String _cat = 'CUERPO';
  TimeOfDay _hora = const TimeOfDay(hour: 6, minute: 0);
  int _dur = 30;
  final Set<int> _dias = {1, 2, 3, 4, 5, 6, 7};

  @override
  void initState() {
    super.initState();
    final h = widget.inicial;
    if (h != null) {
      _nombre.text = h.nombre;
      _cat = h.categoria;
      _hora = TimeOfDay(hour: h.hora, minute: h.minuto);
      _dur = h.duracionMin;
      _dias
        ..clear()
        ..addAll(h.dias);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.inicial == null ? 'NUEVO HÁBITO' : 'EDITAR HÁBITO'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _cat,
              items: const [
                DropdownMenuItem(value: 'CUERPO', child: Text('CUERPO')),
                DropdownMenuItem(value: 'MENTE', child: Text('MENTE')),
                DropdownMenuItem(value: 'NEGOCIO', child: Text('NEGOCIO')),
                DropdownMenuItem(value: 'ESPIRITU', child: Text('ESPIRITU')),
              ],
              onChanged: (v) => setState(() => _cat = v!),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hora de inicio'),
              trailing: TextButton(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _hora,
                  );
                  if (t != null) setState(() => _hora = t);
                },
                child: Text(
                  '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ),
            DropdownButtonFormField<int>(
              value: _dur,
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 min')),
                DropdownMenuItem(value: 30, child: Text('30 min')),
                DropdownMenuItem(value: 60, child: Text('60 min')),
                DropdownMenuItem(value: 90, child: Text('90 min')),
              ],
              onChanged: (v) => setState(() => _dur = v!),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: List.generate(7, (i) {
                final d = i + 1;
                return FilterChip(
                  label: Text(_diasLetra[i]),
                  selected: _dias.contains(d),
                  onSelected: (s) =>
                      setState(() => s ? _dias.add(d) : _dias.remove(d)),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        TextButton(
          onPressed: () {
            final n = _nombre.text.trim();
            if (n.isEmpty || _dias.isEmpty) return;
            Navigator.pop(
              context,
              Habito(
                id:
                    widget.inicial?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                nombre: n,
                categoria: _cat,
                hora: _hora.hour,
                minuto: _hora.minute,
                duracionMin: _dur,
                dias: _dias.toList()..sort(),
                historial: widget.inicial?.historial,
                racha: widget.inicial?.racha ?? 0,
                activado: widget.inicial?.activado ?? true,
              ),
            );
          },
          child: const Text(
            'GUARDAR',
            style: TextStyle(color: Color(0xFF00FF88)),
          ),
        ),
      ],
    );
  }
}
