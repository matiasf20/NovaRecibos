// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // 🚀 NECESARIO PARA kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart'; // 🚀 PAQUETE UNIVERSAL
import 'pantalla_bienvenida.dart';

// 🧱 ESTRUCTURAS DE CONTROL
// ---------------------------------------------------------------------
class Recibo {
  final int numero;
  final String sr;
  final String origen;
  final String destino;
  final String observaciones;
  final double monto;
  final DateTime fecha;
  final bool esConvenio;
  final String empresaPasajero;
  final bool mostrarLogosPago;

  Recibo({
    required this.numero, required this.sr, required this.origen,
    required this.destino, required this.observaciones, required this.monto,
    required this.fecha, required this.esConvenio, required this.empresaPasajero,
    required this.mostrarLogosPago,
  });

  Map<String, dynamic> toJson() => {
        'numero': numero, 'sr': sr, 'origen': origen, 'destino': destino,
        'observaciones': observaciones, 'monto': monto, 'fecha': fecha.toIso8601String(),
        'esConvenio': esConvenio, 'empresaPasajero': empresaPasajero, 'mostrarLogosPago': mostrarLogosPago,
      };

  factory Recibo.fromJson(Map<String, dynamic> json) => Recibo(
        numero: json['numero'] ?? 1, sr: json['sr'] ?? '', origen: json['origen'] ?? '',
        destino: json['destino'] ?? '', observaciones: json['observaciones'] ?? '',
        monto: (json['monto'] ?? 0).toDouble(), fecha: DateTime.parse(json['fecha']),
        esConvenio: json['esConvenio'] ?? false, empresaPasajero: json['empresaPasajero'] ?? '',
        mostrarLogosPago: json['mostrarLogosPago'] ?? false,
      );
}

class DatosEmpresa {
  final String nombreConductor;
  final String nombreEmpresa;
  final String rutEmpresa;
  final String celular; 
  final String correo;
  final String patente; 
  final String sitioWeb; 
  final String? rutaLogo;

  DatosEmpresa({
    required this.nombreConductor, 
    required this.nombreEmpresa, 
    required this.rutEmpresa,
    required this.celular, 
    required this.correo, 
    required this.patente, 
    required this.sitioWeb, 
    this.rutaLogo,
  });
}

// ---------------------------------------------------------------------
// 📋 PANEL ADAPTATIVO: INDEPENDIENTE VS FLOTA
// ---------------------------------------------------------------------
class PantallaInicio extends StatefulWidget {
  final DatosEmpresa datosEmpresa;
  const PantallaInicio({super.key, required this.datosEmpresa});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  List<Recibo> misRecibos = [];
  bool _esFlota = false;
  bool _cargandoVinculo = true;
  String? _empresaCorreoReal;
  late DatosEmpresa datosEmpresaActiva;

  @override
  void initState() {
    super.initState();
    datosEmpresaActiva = widget.datosEmpresa;
    _cargarRecibosMemoria();
    _analizarPerfilYVinculacion();
  }

  Future<void> _analizarPerfilYVinculacion() async {
    try {
      DocumentSnapshot docFlota = await FirebaseFirestore.instance
          .collection('conductores_flota')
          .doc(widget.datosEmpresa.correo)
          .get();

      if (docFlota.exists) {
        String correoAdminFlota = docFlota['empresa_correo'] ?? "";
        
        String nombreEmpresa = "TRANSPORTE CORPORATIVO";
        String rutEmpresa = "";
        String celularEmpresa = "";
        String sitioWeb = "";
        String? rutaLogo;

        DocumentSnapshot docEmpresa = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(correoAdminFlota)
            .get();

        if (!docEmpresa.exists) {
          QuerySnapshot q = await FirebaseFirestore.instance.collection('empresas').where('correo', isEqualTo: correoAdminFlota).get();
          if (q.docs.isNotEmpty) docEmpresa = q.docs.first;
        }

        if (docEmpresa.exists) {
          final data = docEmpresa.data() as Map<String, dynamic>? ?? {};
          nombreEmpresa = data['empresa_nombre'] ?? data['nombre'] ?? "TAXI-VÍA AERO TRANSPORTE";
          rutEmpresa = data['rut_empresa'] ?? data['rut'] ?? "78.325.923-0";
          celularEmpresa = data['celular_contacto'] ?? data['celular'] ?? "928207018";
          sitioWeb = data['sitio_web'] ?? data['web'] ?? "";
          rutaLogo = data['ruta_logo'] ?? data['logo_url'];
        }

        setState(() {
          _esFlota = true;
          _empresaCorreoReal = correoAdminFlota;
          datosEmpresaActiva = DatosEmpresa(
            nombreConductor: docFlota['nombre'] ?? widget.datosEmpresa.nombreConductor,
            nombreEmpresa: nombreEmpresa,
            rutEmpresa: rutEmpresa,
            celular: celularEmpresa, 
            correo: widget.datosEmpresa.correo,
            patente: docFlota['patente'] ?? widget.datosEmpresa.patente,
            sitioWeb: sitioWeb,
            rutaLogo: rutaLogo,
          );
          _cargandoVinculo = false;
        });
        return;
      } 
      
      DocumentSnapshot docIndep = await FirebaseFirestore.instance
          .collection('conductores_independientes')
          .doc(widget.datosEmpresa.correo)
          .get();

      if (docIndep.exists) {
        final data = docIndep.data() as Map<String, dynamic>? ?? {};
        setState(() {
          _esFlota = false;
          _empresaCorreoReal = widget.datosEmpresa.correo;
          datosEmpresaActiva = DatosEmpresa(
            nombreConductor: data['nombre'] ?? widget.datosEmpresa.nombreConductor,
            nombreEmpresa: data['empresa_nombre'] ?? data['nombre_empresa'] ?? widget.datosEmpresa.nombreEmpresa,
            rutEmpresa: data['rut_empresa'] ?? data['rut'] ?? widget.datosEmpresa.rutEmpresa,
            celular: data['celular_contacto'] ?? data['celular'] ?? widget.datosEmpresa.celular,
            correo: widget.datosEmpresa.correo,
            patente: data['patente'] ?? widget.datosEmpresa.patente,
            sitioWeb: data['sitio_web'] ?? widget.datosEmpresa.sitioWeb,
            rutaLogo: data['ruta_logo'] ?? widget.datosEmpresa.rutaLogo,
          );
          _cargandoVinculo = false;
        });
      } else {
        setState(() { 
          _esFlota = false;
          _cargandoVinculo = false; 
        });
      }
    } catch (e) {
      setState(() { 
        _esFlota = false;
        _cargandoVinculo = false; 
      });
    }
  }

  Future<void> _cargarRecibosMemoria() async {
    final prefs = await SharedPreferences.getInstance();
    final String? datosGuardados = prefs.getString('recibos_guardados_${widget.datosEmpresa.correo}');
    if (datosGuardados != null) {
      try {
        final List<dynamic> listaJson = jsonDecode(datosGuardados);
        setState(() { misRecibos = listaJson.map((json) => Recibo.fromJson(json)).toList(); });
      } catch (e) {
        await prefs.remove('recibos_guardados_${widget.datosEmpresa.correo}');
      }
    }
  }

  Future<void> _guardarRecibosMemoria() async {
    final prefs = await SharedPreferences.getInstance();
    final String datosParaGuardar = jsonEncode(misRecibos.map((r) => r.toJson()).toList());
    await prefs.setString('recibos_guardados_${widget.datosEmpresa.correo}', datosParaGuardar);
  }

  Future<void> _eliminarComprobanteDeLista(Recibo reciboAEliminar, int indiceReal) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Comprobante", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("¿Estás seguro de que deseas eliminar este comprobante? Esta acción borrará el registro de tu lista y de las finanzas."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("SÍ, ELIMINAR"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final q = await FirebaseFirestore.instance.collection('recibos')
          .where('numero', isEqualTo: reciboAEliminar.numero)
          .where('empresa_correo', isEqualTo: _empresaCorreoReal ?? datosEmpresaActiva.correo)
          .get();
        for (var doc in q.docs) {
          await doc.reference.delete();
        }

        setState(() {
          misRecibos.removeAt(indiceReal);
        });
        await _guardarRecibosMemoria();

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Comprobante eliminado con éxito.")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
      }
    }
  }

  void _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PantallaBienvenida()),
      (route) => false,
    );
  }

  Future<bool> _solicitarConfirmacionSalida() async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cerrar Sesión", style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
        content: const Text("¿Estás seguro de que deseas cerrar tu sesión?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("VOLVER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("CERRAR SESIÓN"),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  // 🚀 CAMBIO 1: EXPORTACIÓN DE CSV USANDO EL PAQUETE "PRINTING" (DirectRenderer)
  Future<void> _exportarCSVFinanzas() async {
    try {
      if (misRecibos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos para exportar.")));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generando Excel financiero... ⏳")));
      
      String csvData = "Numero,Fecha,Pasajero,Origen,Destino,Monto\n";
      double sumaTotal = 0; 

      final fMoneda = NumberFormat('#,##0', 'es_CL');

      for (var r in misRecibos) {
        final fecha = DateFormat('dd/MM/yyyy').format(r.fecha);
        final passenger = r.sr.replaceAll('"', '""');
        final origen = r.origen.replaceAll('"', '""');
        final destino = r.destino.replaceAll('"', '""');
        final montoFormateado = "\$${fMoneda.format(r.monto)}";
        
        csvData += "${r.numero},$fecha,\"$passenger\",\"$origen\",\"$destino\",\"$montoFormateado\"\n";
        sumaTotal += r.monto; 
      }
      
      final totalFormateado = "\$${fMoneda.format(sumaTotal)}";
      csvData += ",,,,\"TOTAL:\",\"$totalFormateado\"\n";
      
      final nombreArchivo = "Reporte_Financiero_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.csv";
      final bytes = Uint8List.fromList([239, 187, 191] + utf8.encode(csvData)); // Formato UTF-8 con BOM para Excel

      // 🚀 Usamos Printing para compartir/descargar el archivo binario
      await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al generar .CSV: $e")));
    }
  }

  // 🚀 CAMBIO 2: LÓGICA DE PDF UNIVERSAL
  Future<Uint8List?> _generarBytesPDF(Recibo recibo) async {
    try {
      final pdf = pw.Document();
      pw.MemoryImage? imagenLogo;

      if (datosEmpresaActiva.rutaLogo != null && datosEmpresaActiva.rutaLogo!.isNotEmpty) {
        try {
          if (datosEmpresaActiva.rutaLogo!.startsWith('http')) {
            final request = await HttpClient().getUrl(Uri.parse(datosEmpresaActiva.rutaLogo!));
            final response = await request.close();
            final List<int> bytes = [];
            await for (var chunk in response) { bytes.addAll(chunk); }
            imagenLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          } else if (datosEmpresaActiva.rutaLogo!.length > 500) { 
            final bytes = base64Decode(datosEmpresaActiva.rutaLogo!);
            imagenLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          } else {
             // 🚀 PROTECCIÓN DE ARCHIVO LOCAL EN WEB
             if (!kIsWeb) {
               final file = File(datosEmpresaActiva.rutaLogo!);
               if (file.existsSync()) {
                  imagenLogo = pw.MemoryImage(file.readAsBytesSync());
               }
             }
          }
        } catch (e) { print(e); }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(22 * PdfPageFormat.cm, 11 * PdfPageFormat.cm, marginAll: 1 * PdfPageFormat.cm),
          build: (pw.Context context) {
            return pw.Container(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (imagenLogo != null) pw.Image(imagenLogo, width: 80, height: 80)
                      else pw.Container(width: 80, height: 80, color: PdfColors.grey200, alignment: pw.Alignment.center, child: pw.Text("LOGO")),
                      pw.SizedBox(width: 15),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text("COMPROBANTE SERVICIO DE TRANSPORTE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 5),
                            pw.Text(datosEmpresaActiva.nombreEmpresa.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            if (datosEmpresaActiva.rutEmpresa.isNotEmpty) pw.Text("RUT: ${datosEmpresaActiva.rutEmpresa}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            pw.SizedBox(height: 2),
                            pw.Text("Correo: ${datosEmpresaActiva.correo}", style: const pw.TextStyle(fontSize: 10)),
                            pw.SizedBox(height: 5),
                            pw.Text("+56 ${datosEmpresaActiva.celular}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("Recibo N° ${recibo.numero.toString().padLeft(4, '0')}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Text("Fecha: ${DateFormat('dd/MM/yyyy').format(recibo.fecha)}", style: const pw.TextStyle(fontSize: 10)),
                          pw.Text("Hora: ${DateFormat('HH:mm').format(recibo.fecha)}", style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text("SR (A): ${recibo.sr}".toUpperCase(), style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 8),
                  pw.Text("ORIGEN: ${recibo.origen} ➔ DESTINO: ${recibo.destino}".toUpperCase(), style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 8),
                  pw.Text("OBSERVACIONES: ${recibo.observaciones}".toUpperCase(), style: const pw.TextStyle(fontSize: 12)),
                  pw.Spacer(),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text("TOTAL VALOR \$ ${NumberFormat('#,##0', 'es_CL').format(recibo.monto)}", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                  )
                ],
              ),
            );
          },
        ),
      );
      return await pdf.save();
    } catch (e) {
      return null;
    }
  }

  // 🚀 CAMBIO 3: MENÚ DE PDF (Usa Printing para web y nativo)
  Future<void> _abrirOpcionesPDFDesdeLista(Recibo recibo) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Procesando documento... ⏳"), duration: Duration(milliseconds: 800)));
    
    final Uint8List? pdfBytes = await _generarBytesPDF(recibo);
    if (pdfBytes == null) return;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Opciones del Comprobante", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            ),
            ListTile(
              leading: const Icon(Icons.print, color: Colors.blue),
              title: const Text("Abrir y Ver PDF"),
              onTap: () async {
                Navigator.pop(context);
                await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes); 
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text("Compartir / Descargar"),
              onTap: () async {
                Navigator.pop(context);
                await Printing.sharePdf(bytes: pdfBytes, filename: 'Recibo_N${recibo.numero}_Independiente.pdf');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _construirAvatarLogo(String? ruta) {
    Widget imagenFinal;
    if (ruta == null || ruta.isEmpty) {
      imagenFinal = const Icon(Icons.business, color: Color(0xFF0D47A1), size: 24);
    } else if (ruta.startsWith('http')) {
      imagenFinal = Image.network(ruta, fit: BoxFit.contain);
    } else if (ruta.length > 500) {
      imagenFinal = Image.memory(base64Decode(ruta), fit: BoxFit.contain);
    } else {
      // 🚀 PROTECCIÓN DE ARCHIVO LOCAL EN WEB
      if (kIsWeb) {
        imagenFinal = const Icon(Icons.business, color: Color(0xFF0D47A1), size: 24);
      } else {
        final file = File(ruta);
        if (file.existsSync()) {
          imagenFinal = Image.file(file, fit: BoxFit.contain);
        } else {
          imagenFinal = const Icon(Icons.business, color: Color(0xFF0D47A1), size: 24);
        }
      }
    }

    return Container(
      color: Colors.white, 
      padding: const EdgeInsets.all(3), 
      child: imagenFinal,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoVinculo) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final salir = await _solicitarConfirmacionSalida();
        if (salir) _cerrarSesion();
      },
      child: _esFlota 
        ? Scaffold(
            appBar: AppBar(
              title: const Text("Mis Comprobantes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF0D47A1),
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
                  final salir = await _solicitarConfirmacionSalida();
                  if (salir) _cerrarSesion();
                },
              ),
            ),
            body: _buildVistaComprobantes(),
          )
        : DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                toolbarHeight: 80, 
                backgroundColor: const Color(0xFF0D47A1),
                elevation: 0,
                leadingWidth: 70,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 10, bottom: 10),
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    clipBehavior: Clip.hardEdge,
                    child: _construirAvatarLogo(datosEmpresaActiva.rutaLogo),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Hola, ${datosEmpresaActiva.nombreConductor}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(datosEmpresaActiva.nombreEmpresa, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.black87, width: 1.5),
                      ),
                      child: Text(
                        datosEmpresaActiva.patente, 
                        style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () async {
                      final salir = await _solicitarConfirmacionSalida();
                      if (salir) _cerrarSesion();
                    },
                  ),
                ],
                bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  tabs: [
                    Tab(icon: Icon(Icons.receipt_long), text: "Comprobantes"),
                    Tab(icon: Icon(Icons.bar_chart), text: "Mis Finanzas"),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _buildVistaComprobantes(),
                  _buildVistaFinanzasIndependiente(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildVistaComprobantes() {
    final f = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: ElevatedButton.icon(
            onPressed: () async {
              int proximoNumero = 1;
              try {
                QuerySnapshot qMax = await FirebaseFirestore.instance
                    .collection('recibos')
                    .where('empresa_correo', isEqualTo: _empresaCorreoReal ?? datosEmpresaActiva.correo)
                    .get();

                if (qMax.docs.isNotEmpty) {
                  List<int> numerosEmitidos = qMax.docs.map((doc) => ((doc.data() as Map<String, dynamic>)['numero'] as int? ?? 0)).toList();
                  proximoNumero = numerosEmitidos.reduce(max) + 1;
                }
              } catch (e) {
                if (misRecibos.isNotEmpty) {
                  proximoNumero = misRecibos.map((e) => e.numero).reduce(max) + 1;
                }
              }

              final resultado = await Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaFormulario(numeroSugerido: proximoNumero)));
              
              if (resultado != null && resultado is Recibo) {
                setState(() { misRecibos.add(resultado); });
                await _guardarRecibosMemoria();
                
                try {
                  await FirebaseFirestore.instance.collection('recibos').add({
                    'numero': resultado.numero,
                    'sr': resultado.sr, 
                    'origen': resultado.origen, 
                    'destino': resultado.destino,
                    'observaciones': resultado.observaciones,
                    'monto': resultado.monto,
                    'fecha': resultado.fecha.toIso8601String(), 
                    'esConvenio': resultado.esConvenio,
                    'empresaPasajero': resultado.empresaPasajero,
                    'conductor_email': datosEmpresaActiva.correo,
                    'conductor_nombre': datosEmpresaActiva.nombreConductor,
                    'patente': datosEmpresaActiva.patente,
                    'empresa_correo': _empresaCorreoReal ?? datosEmpresaActiva.correo, 
                  });
                } catch (e) {
                  print("Error al subir a la nube: $e");
                }
                _abrirOpcionesPDFDesdeLista(resultado);
              }
            },
            icon: const Icon(Icons.add), label: const Text("NUEVO COMPROBANTE"),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFFE3F2FD), foregroundColor: const Color(0xFF0D47A1), elevation: 0),
          ),
        ),
        Expanded(
          child: misRecibos.isEmpty
              ? const Center(child: Text("Sin comprobantes generados.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: misRecibos.length,
                  itemBuilder: (context, index) {
                    final int indiceReal = misRecibos.length - 1 - index;
                    final recibo = misRecibos[indiceReal];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: const Color(0xFFE3F2FD), child: Text(recibo.numero.toString(), style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold))),
                        title: Text("Pasajero: ${recibo.sr}"),
                        subtitle: Text("Monto: ${f.format(recibo.monto)}\nEmitido por: ${datosEmpresaActiva.nombreConductor.toUpperCase()}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                              onPressed: () => _abrirOpcionesPDFDesdeLista(recibo), 
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey),
                              onPressed: () => _eliminarComprobanteDeLista(recibo, indiceReal),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVistaFinanzasIndependiente() {
    double totalDia = 0;
    double totalSemana = 0;
    double totalMes = 0;

    final ahora = DateTime.now();
    for (var r in misRecibos) {
      if (r.fecha.year == ahora.year && r.fecha.month == ahora.month && r.fecha.day == ahora.day) {
        totalDia += r.monto;
      }
      if (ahora.difference(r.fecha).inDays <= 7) {
        totalSemana += r.monto;
      }
      if (r.fecha.year == ahora.year && r.fecha.month == ahora.month) {
        totalMes += r.monto;
      }
    }

    final fMoneda = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTarjetaMoneda("MI RENDIMIENTO HOY", fMoneda.format(totalDia), Colors.blue),
          const SizedBox(height: 16),
          _buildTarjetaMoneda("MI RENDIMIENTO SEMANAL", fMoneda.format(totalSemana), Colors.orange),
          const SizedBox(height: 16),
          _buildTarjetaMoneda("MI TOTAL MENSUAL", fMoneda.format(totalMes), Colors.green),
          const SizedBox(height: 40),
          
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56), backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.analytics),
            label: const Text("GENERAR MI .CSV FINANCIERO", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _exportarCSVFinanzas, 
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaMoneda(String t, String m, Color c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border(left: BorderSide(color: c, width: 6)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(m, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: c)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// 📋 FORMULARIO DE RECOPILACIÓN DE DATOS
// ---------------------------------------------------------------------
class PantallaFormulario extends StatefulWidget {
  final int numeroSugerido;
  const PantallaFormulario({super.key, required this.numeroSugerido});

  @override
  State<PantallaFormulario> createState() => _PantallaFormularioState();
}

class _PantallaFormularioState extends State<PantallaFormulario> {
  final _srController = TextEditingController();
  final _origenController = TextEditingController();
  final _destinoController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _montoController = TextEditingController();
  final _empresaPasajeroController = TextEditingController();

  bool _esConvenio = false;
  bool _mostrarLogosPago = true; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Comprobante N° ${widget.numeroSugerido.toString().padLeft(4, '0')}", style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0D47A1), iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text("Convenio de Empresa", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Habilita esto si el pasajero viaja por convenio"),
              value: _esConvenio, activeThumbColor: const Color(0xFF0D47A1), 
              onChanged: (bool valor) { setState(() { _esConvenio = valor; }); },
            ),
            if (_esConvenio) ...[
              TextField(controller: _empresaPasajeroController, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: "Nombre Empresa del Pasajero", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 15),
            ],
            TextField(controller: _srController, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: "Nombre Pasajero (Sr/Sra)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: TextField(controller: _origenController, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: "Origen", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _destinoController, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: "Destino", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
              ],
            ),
            const SizedBox(height: 15),
            TextField(controller: _observacionesController, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: "Observaciones", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 15),
            TextField(
              controller: _montoController, decoration: InputDecoration(labelText: "Valor \$", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 15),
            SwitchListTile(
              title: const Text("Mostrar medios de pago", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Agrega Redcompra, visa Y Mastercard Al Pdf"),
              value: _mostrarLogosPago, activeThumbColor: const Color(0xFF0D47A1), 
              onChanged: (bool valor) { setState(() { _mostrarLogosPago = valor; }); },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54), backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
              onPressed: () {
                if (_srController.text.isEmpty || _montoController.text.isEmpty) return;
                
                final nuevoRecibo = Recibo(
                  numero: widget.numeroSugerido, sr: _srController.text, origen: _origenController.text,
                  destino: _destinoController.text, observaciones: _observacionesController.text,
                  monto: double.tryParse(_montoController.text) ?? 0.0, 
                  fecha: DateTime.now(), 
                  esConvenio: _esConvenio, empresaPasajero: _empresaPasajeroController.text,
                  mostrarLogosPago: _mostrarLogosPago,
                );
                Navigator.pop(context, nuevoRecibo);
              },
              child: const Text("GUARDAR COMPROBANTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// 🖨️ VISUALIZADOR DETALLE Y GENERADOR PDF + COMPARTIR (VERSIÓN ÚNICA)
// ---------------------------------------------------------------------
class PantallaDetalleRecibo extends StatelessWidget {
  final Recibo recibo;
  final DatosEmpresa datosEmpresa;

  const PantallaDetalleRecibo({super.key, required this.recibo, required this.datosEmpresa});

  Future<void> _generarYCompartirPDF(BuildContext context) async {
    try {
      final pdf = pw.Document();
      pw.MemoryImage? imagenLogo;

      if (datosEmpresa.rutaLogo != null && datosEmpresa.rutaLogo!.isNotEmpty) {
        try {
          if (datosEmpresa.rutaLogo!.startsWith('http')) {
            final uri = Uri.parse(datosEmpresa.rutaLogo!);
            final request = await HttpClient().getUrl(uri);
            final response = await request.close();
            final List<int> bytes = [];
            await for (var chunk in response) { bytes.addAll(chunk); }
            imagenLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          } else if (datosEmpresa.rutaLogo!.length > 500) { 
            final bytes = base64Decode(datosEmpresa.rutaLogo!);
            imagenLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          } else {
             // 🚀 PROTECCIÓN DE ARCHIVO LOCAL EN WEB
             if (!kIsWeb) {
               final file = File(datosEmpresa.rutaLogo!);
               if (file.existsSync()) {
                  imagenLogo = pw.MemoryImage(file.readAsBytesSync());
               }
             }
          }
        } catch (e) {
          print("Aviso: Logo no cargado ($e)");
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(22 * PdfPageFormat.cm, 11 * PdfPageFormat.cm, marginAll: 1 * PdfPageFormat.cm),
          build: (pw.Context context) {
            return pw.Container(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (imagenLogo != null) pw.Image(imagenLogo, width: 80, height: 80)
                      else pw.Container(width: 80, height: 80, color: PdfColors.grey200, alignment: pw.Alignment.center, child: pw.Text("LOGO")),
                      pw.SizedBox(width: 15),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text("COMPROBANTE SERVICIO DE TRANSPORTE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 5),
                            pw.Text(datosEmpresa.nombreEmpresa.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            if (datosEmpresa.rutEmpresa.isNotEmpty) pw.Text("RUT: ${datosEmpresa.rutEmpresa}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            pw.SizedBox(height: 2),
                            pw.Text("Correo: ${datosEmpresa.correo}", style: const pw.TextStyle(fontSize: 10)),
                            pw.SizedBox(height: 5),
                            pw.Text("+56 ${datosEmpresa.celular}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("Recibo N° ${recibo.numero.toString().padLeft(4, '0')}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Text("Fecha: ${DateFormat('dd/MM/yyyy').format(recibo.fecha)}", style: const pw.TextStyle(fontSize: 10)),
                          pw.Text("Hora: ${DateFormat('HH:mm').format(recibo.fecha)}", style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text("SR (A): ${recibo.sr}".toUpperCase(), style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 8),
                  pw.Text("ORIGEN: ${recibo.origen} ➔ DESTINO: ${recibo.destino}".toUpperCase(), style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 8),
                  pw.Text("OBSERVACIONES: ${recibo.observaciones}".toUpperCase(), style: const pw.TextStyle(fontSize: 12)),
                  pw.Spacer(),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text("TOTAL VALOR \$ ${NumberFormat('#,##0', 'es_CL').format(recibo.monto)}", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                  )
                ],
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();

      // 🚀 CAMBIO 4: USA PRINTING PARA COMPARTIR EL DOCUMENTO SIN COLAPSO WEB
      await Printing.sharePdf(bytes: pdfBytes, filename: "Recibo_N${recibo.numero}_${recibo.sr}.pdf");
      
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fMoneda = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return Scaffold(
      backgroundColor: Colors.grey[100], 
      appBar: AppBar(title: Text("Comprobante N° ${recibo.numero.toString().padLeft(4, '0')}", style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0D47A1), iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              padding: const EdgeInsets.all(25.0),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 2, offset: const Offset(0, 5))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Text("COMPROBANTE N° ${recibo.numero.toString().padLeft(4, '0')}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)))),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.grey, thickness: 1), 
                  const SizedBox(height: 20),
                  _construirFilaDato("Sr (a):", recibo.sr),
                  if (recibo.esConvenio) ...[
                    const SizedBox(height: 10),
                    _construirFilaDato("Convenio:", recibo.empresaPasajero),
                  ],
                  const SizedBox(height: 10),
                  _construirFilaDato("Origen:", recibo.origen),
                  const SizedBox(height: 10),
                  _construirFilaDato("Destino:", recibo.destino),
                  const SizedBox(height: 10),
                  _construirFilaDato("Obs:", recibo.observaciones),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("VALOR:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(fMoneda.format(recibo.monto), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generando comprobante... ⏳')));
                      await _generarYCompartirPDF(context);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text("COMPARTIR COMPROBANTE", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirFilaDato(String titulo, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(titulo, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
        Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16))),
      ],
    );
  }
}