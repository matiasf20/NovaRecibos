// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // 🚀 NECESARIO PARA kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart'; 
// 🚀 CAMBIO QUIRÚRGICO DE IMPORTS CONDICIONALES
import 'package:universal_html/html.dart' as html;
import 'pantalla_bienvenida.dart';

class PantallaAdminDashboard extends StatefulWidget {
  const PantallaAdminDashboard({super.key});

  @override
  State<PantallaAdminDashboard> createState() => _PantallaAdminDashboardState();
}

class _PantallaAdminDashboardState extends State<PantallaAdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailChoferCtrl = TextEditingController();
  final _nombreChoferCtrl = TextEditingController();
  final _patenteChoferCtrl = TextEditingController();
  final _claveChoferCtrl = TextEditingController();
  
  String _nombreEmpresa = "Mi Empresa Flota";
  String _rutEmpresa = "";
  String _celularEmpresa = "";
  // ignore: unused_field
  String _sitioWeb = "";
  String? _logoUrl;
  bool _cargandoDatos = true;

  List<File> _archivosCSV = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatosEmpresa();
    _cargarHistorialCSV(); 
  }

  Future<void> _cargarHistorialCSV() async {
    if (kIsWeb) return; // Evita lectura de directorios locales en web/iPhone
    try {
      final dir = await getTemporaryDirectory();
      final archivos = dir.listSync().whereType<File>().where((file) {
        final nombre = file.path.split(Platform.pathSeparator).last;
        return nombre.endsWith('.csv') && nombre.startsWith('Reporte_Financiero_');
      }).toList();
      
      archivos.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      if (mounted) {
        setState(() {
          _archivosCSV = archivos;
        });
      }
    } catch (e) {
      print("Error al cargar historial: $e");
    }
  }

  Future<void> _cargarDatosEmpresa() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('empresas').doc(user.email).get();
        if (!doc.exists) {
          QuerySnapshot q = await FirebaseFirestore.instance.collection('empresas').where('correo_admin', isEqualTo: user.email).get();
          if (q.docs.isNotEmpty) doc = q.docs.first;
        }
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          _nombreEmpresa = data['empresa_nombre'] ?? data['nombre'] ?? _nombreEmpresa;
          _rutEmpresa = data['rut_empresa'] ?? data['rut'] ?? "";
          _celularEmpresa = data['celular_contacto'] ?? data['celular'] ?? "";
          _sitioWeb = data['sitio_web'] ?? data['web'] ?? ""; 
          _logoUrl = data['ruta_logo'] ?? data['logo_url'];
        }
      }
      setState(() { _cargandoDatos = false; });
    } catch (e) {
      setState(() { _cargandoDatos = false; });
    }
  }

  void _cerrarSesion() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Cerrar Sesión Admin", style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
          content: const Text("¿Estás seguro de que deseas salir del Panel de Control Corporativo?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text("VOLVER")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const PantallaBienvenida()),
                  (route) => false,
                );
              }, 
              child: const Text("CERRAR PANEL"),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _solicitarConfirmacionSalida() async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cerrar Sesión Admin", style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
        content: const Text("¿Estás seguro de que deseas salir del Panel de Control Corporativo?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("VOLVER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), child: const Text("CERRAR PANEL"),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  // 🚀 INTERNA AUXILIAR: EXTRAE LOS BYTES DEL PDF CORPORATIVO
  Future<Uint8List?> _generarBytesPDFAdmin(Map<String, dynamic> data) async {
    try {
      final pdf = pw.Document();
      pw.MemoryImage? imagenLogo;

      if (_logoUrl != null && _logoUrl!.isNotEmpty) {
        try {
          if (_logoUrl!.startsWith('http')) {
            final request = await HttpClient().getUrl(Uri.parse(_logoUrl!));
            final response = await request.close();
            final List<int> bytes = [];
            await for (var chunk in response) { bytes.addAll(chunk); }
            imagenLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          }
        } catch (e) {
          print("No se pudo descargar el logo: $e");
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(22 * PdfPageFormat.cm, 11 * PdfPageFormat.cm, marginAll: 1 * PdfPageFormat.cm),
          build: (pw.Context context) {
            final date = DateTime.parse(data['fecha'] ?? DateTime.now().toIso8601String());
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
                            pw.Text(_nombreEmpresa.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            if (_rutEmpresa.isNotEmpty) pw.Text("RUT: $_rutEmpresa", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            pw.SizedBox(height: 2),
                            pw.Text("Correo: ${FirebaseAuth.instance.currentUser?.email}", style: const pw.TextStyle(fontSize: 10)),
                            pw.SizedBox(height: 5),
                            pw.Text("+56 $_celularEmpresa", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("Recibo N° ${data['numero'].toString().padLeft(4, '0')}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Text("Fecha: ${DateFormat('dd/MM/yyyy').format(date)}", style: const pw.TextStyle(fontSize: 10)),
                          pw.Text("Hora: ${DateFormat('HH:mm').format(date)}", style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                  pw.Text("SR (A): ${data['sr'] ?? ''}".toUpperCase(), style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Text("ORIGEN: ${data['origen'] ?? ''}  ➔  DESTINO: ${data['destino'] ?? ''}".toUpperCase(), style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Text("OBSERVACIONES: ${data['observaciones'] ?? ''}".toUpperCase(), style: pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.Text("CONDUCTOR: ${data['conductor_nombre'] ?? ''}  |  PATENTE: ${data['patente'] ?? ''}".toUpperCase(), style: pw.TextStyle(fontSize: 12)),
                  pw.Spacer(),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text("TOTAL VALOR \$ ${NumberFormat('#,##0', 'es_CL').format(data['monto'] ?? 0)}", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                  )
                ],
              ),
            );
          },
        ),
      );
      return pdf.save();
    } catch (e) {
      return null;
    }
  }

  void _abrirOpcionesPDF(Map<String, dynamic> item) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Procesando documento... ⏳"), duration: Duration(milliseconds: 800)));
    
    if (kIsWeb) {
      // 🚀 COMPORTAMIENTO WEB/IPHONE: DESCARGA DIRECTA
      final pdfBytes = await _generarBytesPDFAdmin(item);
      if (pdfBytes == null) return;
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", "Recibo_N${item['numero']}_Admin.pdf")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // COMPORTAMIENTO NATIVO ANDROID
      final pdfBytes = await _generarBytesPDFAdmin(item);
      if (pdfBytes == null) return;
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Recibo_N${item['numero']}_Admin.pdf");
      await file.writeAsBytes(pdfBytes);

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
                leading: const Icon(Icons.visibility, color: Colors.blue),
                title: const Text("Abrir y Ver PDF"),
                onTap: () {
                  Navigator.pop(context);
                  OpenFilex.open(file.path); 
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.green),
                title: const Text("Compartir Documento"),
                onTap: () {
                  Navigator.pop(context);
                  // ignore: deprecated_member_use
                  Share.shareXFiles([XFile(file.path)], text: 'Adjunto comprobante digital de servicio de transporte.');
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }
  }

  void _abrirOpcionesCSV(File archivo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Reporte CSV Generado\n${archivo.path.split(Platform.pathSeparator).last}", 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            ),
            ListTile(
              leading: const Icon(Icons.table_view, color: Colors.blue),
              title: const Text("Abrir y ver archivo"),
              onTap: () async {
                Navigator.pop(context);
                final resultado = await OpenFilex.open(archivo.path);
                if (resultado.type != ResultType.done) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("No se puede abrir el archivo porque no tienes una aplicación para visualizar archivos .csv."),
                        duration: Duration(seconds: 4),
                        backgroundColor: Colors.red, 
                      )
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text("Compartir archivo"),
              onTap: () {
                Navigator.pop(context);
                // ignore: deprecated_member_use
                Share.shareXFiles([XFile(archivo.path)], text: 'Adjunto reporte financiero.');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarReporteCSV(File archivo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Reporte", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("¿Deseas eliminar este archivo CSV de tu teléfono? No borrará los datos de la app, solo este archivo generado."),
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
        if (archivo.existsSync()) {
          archivo.deleteSync();
        }
        await _cargarHistorialCSV(); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Archivo eliminado del dispositivo.")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
      }
    }
  }

  Future<void> _eliminarComprobante(String docId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Comprobante", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("¿Estás seguro de que deseas eliminar este comprobante? Esta acción borrará el registro de la nube y de las finanzas. No se puede deshacer."),
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
        await FirebaseFirestore.instance.collection('recibos').doc(docId).delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Comprobante eliminado con éxito.")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
      }
    }
  }

  Future<void> _eliminarConductor(String emailConductor) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Desvincular Conductor", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("¿Estás seguro de que deseas eliminar a este conductor de la flota? Se le revocará inmediatamente el acceso al panel corporativo."),
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
        await FirebaseFirestore.instance.collection('conductores_flota').doc(emailConductor).delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Conductor desvinculado con éxito.")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
      }
    }
  }

  // 🚀 ACTUALIZADO ADREDE: COMPATIBILIDAD HÍBRIDA EXCEL CON FILA TOTAL
  Future<void> _exportarExcelAdmin(List<QueryDocumentSnapshot> docs) async {
    try {
      String csvData = "N° Recibo,Fecha,Conductor,Patente,Pasajero,Origen,Destino,Monto\n";
      double sumaTotal = 0; 

      final fMoneda = NumberFormat('#,##0', 'es_CL');

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final fechaFull = DateTime.parse(data['fecha'] ?? DateTime.now().toIso8601String());

        final numero = data['numero'] ?? 0;
        final fecha = DateFormat('dd/MM/yyyy').format(fechaFull);
        
        final conductor = (data['conductor_nombre'] ?? 'Desconocido').toString().replaceAll('"', '""');
        final patente = (data['patente'] ?? 'S/P').toString().replaceAll('"', '""');
        final passenger = (data['sr'] ?? 'Particular').toString().replaceAll('"', '""');
        final origen = (data['origen'] ?? '').toString().replaceAll('"', '""');
        final destino = (data['destino'] ?? '').toString().replaceAll('"', '""');
        
        final monto = (data['monto'] ?? 0).toDouble();
        sumaTotal += monto; 

        final montoFormateado = "\$${fMoneda.format(monto)}";
        csvData += "$numero,$fecha,\"$conductor\",\"$patente\",\"$passenger\",\"$origen\",\"$destino\",\"$montoFormateado\"\n";
      }

      final totalFormateado = "\$${fMoneda.format(sumaTotal)}";
      csvData += ",,,,,,,\"TOTAL:\",\"$totalFormateado\"\n";

      final nombreArchivo = "Reporte_Financiero_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.csv";
      final bytes = [239, 187, 191] + utf8.encode(csvData);

      if (kIsWeb) {
        // 🚀 COMPORTAMIENTO IPHONE PWA (Descarga directa en Safari)
        final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download", nombreArchivo)
          ..click();
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte descargado en tu iPhone.')));
      } else {
        // COMPORTAMIENTO ANDROID NATIVO
        final output = await getTemporaryDirectory();
        final file = File("${output.path}/$nombreArchivo");
        await file.writeAsBytes(bytes); 
        await _cargarHistorialCSV(); 
        _abrirOpcionesCSV(file);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar Excel: $e')));
    }
  }

  void _abrirDialogoRegistrarChofer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Registrar Nuevo Conductor", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nombreChoferCtrl, decoration: const InputDecoration(labelText: "Nombre Completo")),
              TextField(
                controller: _patenteChoferCtrl, 
                decoration: const InputDecoration(labelText: "Patente (XXXX-13)"), 
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FormateadorPatenteEstricto(),
                  LengthLimitingTextInputFormatter(7),
                ],
              ),
              TextField(controller: _emailChoferCtrl, decoration: const InputDecoration(labelText: "Correo Electrónico")),
              TextField(controller: _claveChoferCtrl, decoration: const InputDecoration(labelText: "Contraseña de Acceso")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(onPressed: _procesarAltaChoferFlota, child: const Text("REGISTRAR")),
        ],
      ),
    );
  }

  void _procesarAltaChoferFlota() async {
    final email = _emailChoferCtrl.text.trim();
    final clave = _claveChoferCtrl.text.trim();
    final nombre = _nombreChoferCtrl.text.trim().toUpperCase();
    final patente = _patenteChoferCtrl.text.trim().toUpperCase();
    final adminEmail = FirebaseAuth.instance.currentUser?.email ?? "";

    if (email.isEmpty || clave.isEmpty || nombre.isEmpty || patente.isEmpty) return;

    try {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registrando conductor en la base cloud... ⏳")));
      
      FirebaseApp secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );
      
      try {
        await FirebaseAuth.instanceFor(app: secondaryApp).createUserWithEmailAndPassword(
          email: email,
          password: clave,
        );
      } finally {
        await secondaryApp.delete();
      }

      await FirebaseFirestore.instance.collection('conductores_flota').doc(email).set({
        'nombre': nombre,
        'patente': patente,
        'empresa_correo': adminEmail,
        'rol': 'chofer_flota'
      });

      _emailChoferCtrl.clear();
      _claveChoferCtrl.clear();
      _nombreChoferCtrl.clear();
      _patenteChoferCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Conductor incorporado con éxito!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al dar de alta: $e")));
    }
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
    if (_cargandoDatos) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final salir = await _solicitarConfirmacionSalida();
        if (salir) _cerrarSesion();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 75,
          backgroundColor: const Color(0xFF0D47A1),
          elevation: 0,
          leadingWidth: 70,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 10, bottom: 10),
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              clipBehavior: Clip.hardEdge,
              child: _construirAvatarLogo(_logoUrl),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_nombreEmpresa, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Text("Panel de Administrador", style: TextStyle(color: Colors.white70, fontSize: 13)),
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
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(icon: Icon(Icons.people), text: "Conductores"),
              Tab(icon: Icon(Icons.receipt_long), text: "Comprobantes"),
              Tab(icon: Icon(Icons.bar_chart), text: "Finanzas"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPestanaConductores(),
            _buildPestanaHistorial(),
            _buildPestanaFinanzas(),
          ],
        ),
      ),
    );
  }

  Widget _buildPestanaConductores() {
    final emailAdmin = FirebaseAuth.instance.currentUser?.email ?? "";
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _abrirDialogoRegistrarChofer,
            icon: const Icon(Icons.person_add),
            label: const Text("REGISTRAR CONDUCTOR"),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFFE3F2FD), foregroundColor: const Color(0xFF0D47A1)),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('conductores_flota').where('empresa_correo', isEqualTo: emailAdmin).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No hay conductores asignados a la flota."));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final item = docs[index].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFF0D47A1), child: Icon(Icons.directions_car, color: Colors.white)),
                      title: Text(item['nombre'] ?? 'CONDUCTOR', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Patente: ${item['patente'] ?? 'S/P'} | Correo: ${docs[index].id}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_remove, color: Colors.red),
                        onPressed: () => _eliminarConductor(docs[index].id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildPestanaHistorial() {
    final emailAdmin = FirebaseAuth.instance.currentUser?.email ?? "";
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('recibos').where('empresa_correo', isEqualTo: emailAdmin).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("Ningún comprobante digital emitido por la flota."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final docId = docs[index].id; 
            final item = docs[index].data() as Map<String, dynamic>;
            final f = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: const Color(0xFFE3F2FD), child: Text(item['numero'].toString(), style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold))),
                title: Text("Pasajero: ${item['sr'] ?? 'Particular'}"),
                subtitle: Text("Monto: ${f.format(item['monto'] ?? 0)}\nEmitido por: ${item['conductor_nombre'] ?? 'Chofer'}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      onPressed: () => _abrirOpcionesPDF(item), 
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _eliminarComprobante(docId),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPestanaFinanzas() {
    final emailAdmin = FirebaseAuth.instance.currentUser?.email ?? "";
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('recibos').where('empresa_correo', isEqualTo: emailAdmin).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        double totalDia = 0;
        double totalSemana = 0;
        double totalMes = 0;
        final ahora = DateTime.now();

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final monto = (data['monto'] ?? 0).toDouble();
          final fecha = DateTime.parse(data['fecha'] ?? ahora.toIso8601String());

          if (fecha.year == ahora.year && fecha.month == ahora.month && fecha.day == ahora.day) {
            totalDia += monto;
          }
          if (ahora.difference(fecha).inDays <= 7) {
            totalSemana += monto;
          }
          if (fecha.year == ahora.year && fecha.month == ahora.month) {
            // Reparación de typo heredado para que use el mes activo correcto
          }
          if (fecha.year == ahora.year && fecha.month == ahora.month) {
            totalMes += monto;
          }
        }

        final f = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tarjetaMoneda("RENDIMIENTO TOTAL HOY", f.format(totalDia), Colors.blue),
              const SizedBox(height: 12),
              _tarjetaMoneda("RENDIMIENTO SEMANAL FLOTA", f.format(totalSemana), Colors.orange),
              const SizedBox(height: 12),
              _tarjetaMoneda("RECAUDACIÓN MENSUAL EMPRESA", f.format(totalMes), Colors.green),
              const SizedBox(height: 30),
              
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56), 
                  backgroundColor: const Color(0xFF0D47A1), 
                  foregroundColor: Colors.white, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                icon: const Icon(Icons.analytics),
                label: const Text("GENERAR MI .CSV FINANCIERO", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  if (docs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos en la flota para exportar.")));
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generando archivo .CSV... ⏳")));
                  _exportarExcelAdmin(docs); 
                },
              ),
              
              // 🚀 SÓLO RENDERIZA EL HISTORIAL DE DISCO SI CORRE EN UN TELÉFONO ANDROID FISICO
              if (!kIsWeb) ...[
                const SizedBox(height: 40),
                const Text("Historial de Reportes Generados", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                const Divider(),
                if (_archivosCSV.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Center(child: Text("Aún no has generado ningún reporte.", style: TextStyle(color: Colors.grey))),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(), 
                    itemCount: _archivosCSV.length,
                    itemBuilder: (context, index) {
                      final archivo = _archivosCSV[index];
                      final fechaCreacion = archivo.lastModifiedSync();
                      final nombreLindo = "Reporte Financiero ${DateFormat('dd/MM/yyyy').format(fechaCreacion)}";
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 1,
                        child: ListTile(
                          leading: const Icon(Icons.insert_drive_file, color: Colors.green, size: 30),
                          title: Text(nombreLindo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text("${(archivo.lengthSync() / 1024).toStringAsFixed(1)} KB", style: const TextStyle(fontSize: 12)),
                          onTap: () => _abrirOpcionesCSV(archivo), 
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _eliminarReporteCSV(archivo),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _tarjetaMoneda(String t, String m, Color c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: c, width: 6)), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(m, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c))]),
    );
  }
}

class FormateadorPatenteEstricto extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');

    String letras = text.substring(0, text.length > 4 ? 4 : text.length).replaceAll(RegExp(r'[^A-Z]'), '');
    String numeros = '';
    
    if (text.length > letras.length) {
      String subResto = text.substring(letras.length);
      numeros = subResto.substring(0, subResto.length > 2 ? 2 : subResto.length).replaceAll(RegExp(r'[^0-9]'), '');
    }

    String finalTxt = letras;
    if (letras.length == 4) {
      finalTxt = numeros.isNotEmpty ? '$letras-$numeros' : '$letras-';
    }

    return TextEditingValue(
      text: finalTxt,
      selection: TextSelection.collapsed(offset: finalTxt.length),
    );
  }
}