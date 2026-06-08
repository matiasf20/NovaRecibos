// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:convert';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; 
import 'pantalla_bienvenida.dart';
import 'package:universal_html/html.dart' as html;

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
  String _sitioWeb = "";
  String? _logoUrl;
  bool _cargandoDatos = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatosEmpresa();
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
          _nombreEmpresa = data['empresa_nombre']?.toString() ?? data['nombre']?.toString() ?? _nombreEmpresa;
          _rutEmpresa = data['rut_empresa']?.toString() ?? data['rut']?.toString() ?? "";
          _celularEmpresa = data['celular_contacto']?.toString() ?? data['celular']?.toString() ?? "";
          _sitioWeb = data['sitio_web']?.toString() ?? data['web']?.toString() ?? ""; 
          _logoUrl = data['ruta_logo']?.toString() ?? data['logo_url']?.toString();
        }
      }
      setState(() { _cargandoDatos = false; });
    } catch (e) {
      print("Aviso de carga: $e");
      setState(() { _cargandoDatos = false; });
    }
  }

  void _cerrarSesion() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
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

  pw.Widget _construirCajitaPDF(String texto) {
    return pw.Container(
      width: 22, height: 16,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      alignment: pw.Alignment.center,
      child: pw.Text(texto, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  pw.Widget _construirLineaPDF(String etiqueta, String valor) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text("$etiqueta ", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 1, left: 4), 
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.8))),
            child: pw.Text(valor, style: const pw.TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Future<Uint8List?> _generarBytesPDFAdmin(Map<String, dynamic> data) async {
    try {
      final pdf = pw.Document();
      pw.MemoryImage? imagenLogo;
      pw.MemoryImage? imagenPagos;

      if (_logoUrl != null && _logoUrl!.isNotEmpty) {
        try {
          if (_logoUrl!.startsWith('http')) {
            final req = await html.HttpRequest.request(
              _logoUrl!,
              responseType: 'arraybuffer',
            );
            imagenLogo = pw.MemoryImage((req.response as dynamic).asUint8List());
          } else if (_logoUrl!.length > 500) {
            final bytes = base64Decode(_logoUrl!);
            imagenLogo = pw.MemoryImage(Uint8List.fromList(bytes));
          }
        } catch (_) {
          print("Aviso: No se pudo procesar el formato del logo en el PDF.");
        }
      }

      try {
        final ByteData bytesPagos = await rootBundle.load('assets/pagos.jpg'); 
        imagenPagos = pw.MemoryImage(bytesPagos.buffer.asUint8List());
      } catch (_) {
        try { 
          final ByteData bytesPagos = await rootBundle.load('assets/pagos.png');
          imagenPagos = pw.MemoryImage(bytesPagos.buffer.asUint8List());
        } catch (_) {}
      }

      const String svgWhatsapp = '''<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#25D366" d="M12.031 0C5.383 0 0 5.383 0 12.031c0 2.124.551 4.195 1.597 6.012L.038 24l6.113-1.603a11.96 11.96 0 0 0 5.88 1.535h.005c6.648 0 12.031-5.384 12.031-12.032C24.067 5.383 18.679 0 12.031 0zm0 21.933h-.004a9.922 9.922 0 0 1-5.062-1.385l-.363-.215-3.766.987.998-3.668-.236-.376a9.92 9.92 0 0 1-1.517-5.313c0-5.502 4.478-9.98 9.98-9.98 5.502 0 9.98 4.478 9.98 9.98 0 5.502-4.478 9.98-9.98 9.98z"/><path fill="#FFF" d="M17.505 14.453c-.301-.151-1.777-.878-2.052-.979-.276-.1-.477-.151-.678.151-.201.301-.778.979-.953 1.18-.175.201-.351.226-.652.075-.301-.151-1.27-.468-2.42-1.493-.895-.798-1.501-1.784-1.677-2.085-.175-.301-.019-.464.132-.614.135-.135.301-.351.452-.527.151-.175.201-.351.301-.502.1-.201.05-.376-.025-.527-.075-.151-.678-1.631-.928-2.233-.245-.59-.493-.51-.678-.519-.175-.01-.376-.01-.577-.01-.201 0-.527.075-.803.376-.276.301-1.053 1.029-1.053 2.509s1.078 2.91 1.229 3.111c.151.201 2.124 3.242 5.143 4.545.719.31 1.28.495 1.718.633.723.23 1.382.197 1.901.12.583-.087 1.777-.726 2.028-1.43.251-.703.251-1.305.175-1.43-.075-.125-.276-.2-.577-.351z"/></svg>''';

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(22 * PdfPageFormat.cm, 11 * PdfPageFormat.cm, marginAll: 1 * PdfPageFormat.cm),
          build: (pw.Context context) {
            final date = DateTime.parse(data['fecha'] ?? DateTime.now().toIso8601String());
            final adminEmail = FirebaseAuth.instance.currentUser?.email ?? "";

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
                            pw.Text(adminEmail.toLowerCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            if (_sitioWeb.isNotEmpty) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(_sitioWeb.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            ],
                            
                            pw.SizedBox(height: 5),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.SvgImage(svg: svgWhatsapp, width: 14, height: 14),
                                pw.SizedBox(width: 5),
                                pw.Text("+56 $_celularEmpresa", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("Recibo N° ${data['numero'].toString().padLeft(4, '0')}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Row(
                            children: [
                              pw.Text("Fecha ", style: const pw.TextStyle(fontSize: 10)),
                              _construirCajitaPDF(DateFormat('dd').format(date)),
                              _construirCajitaPDF(DateFormat('MM').format(date)),
                              _construirCajitaPDF(DateFormat('yy').format(date)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                  
                  _construirLineaPDF("SR (A):", (data['sr'] ?? '').toString().toUpperCase()),
                  pw.SizedBox(height: 8),
                  if (data['esConvenio'] == true || data['convenio_empresa'] == true) ...[
                    _construirLineaPDF("EMPRESA CONVENIO:", (data['empresaPasajero'] ?? data['nombre_empresa_pasajero'] ?? '').toString().toUpperCase()),
                    pw.SizedBox(height: 8),
                  ],
                  pw.Row(
                    children: [
                      pw.Expanded(child: _construirLineaPDF("ORIGEN:", (data['origen'] ?? '').toString().toUpperCase())),
                      pw.SizedBox(width: 15),
                      pw.Expanded(child: _construirLineaPDF("DESTINO:", (data['destino'] ?? '').toString().toUpperCase())),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  _construirLineaPDF("OBSERVACIONES:", (data['observaciones'] ?? '').toString().toUpperCase()),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: _construirLineaPDF("CONDUCTOR:", (data['conductor_nombre'] ?? '').toString().toUpperCase())),
                      pw.SizedBox(width: 15),
                      pw.Expanded(flex: 2, child: _construirLineaPDF("PATENTE:", (data['patente'] ?? '').toString().toUpperCase())),
                    ],
                  ),
                  
                  pw.Spacer(),
                  
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (imagenPagos != null)
                        pw.Container(width: 120, height: 35, child: pw.Image(imagenPagos, fit: pw.BoxFit.contain))
                      else
                        pw.SizedBox(width: 120), 
                      
                      pw.Expanded(
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          mainAxisAlignment: pw.MainAxisAlignment.end, 
                          children: [
                            pw.Text("VALOR \$ ", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.Container(
                              width: 120,
                              padding: const pw.EdgeInsets.only(bottom: 2, left: 5), 
                              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.8))),
                              child: pw.Text(NumberFormat.currency(locale: 'es_CL', symbol: '', decimalDigits: 0).format(data['monto'] ?? 0), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
      return pdf.save();
    } catch (_) { 
      return null;
    }
  }

  void _abrirOpcionesPDF(Map<String, dynamic> item) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Procesando documento... ⏳"), duration: Duration(milliseconds: 800)));
    
    final pdfBytes = await _generarBytesPDFAdmin(item);
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
              title: const Text("Ver / Imprimir PDF"),
              onTap: () async {
                Navigator.pop(context);
                await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text("Compartir / Descargar"),
              onTap: () async {
                Navigator.pop(context);
                await Printing.sharePdf(bytes: pdfBytes, filename: "Recibo_N${item['numero']}_Admin.pdf");
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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

  Future<void> _exportarExcelAdmin(List<QueryDocumentSnapshot> docs) async {
    try {
      String csvData = "N° Recibo;Fecha;Conductor;Patente;Pasajero;Origen;Destino;Monto\n";
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
       csvData += "$numero;$fecha,\"$conductor\";\"$patente\";\"$passenger\";\"$origen\";\"$destino\";\"$montoFormateado\"\n";
      }

      final totalFormateado = "\$${fMoneda.format(sumaTotal)}";
      csvData += ";;;;;;;\"TOTAL:\";\"$totalFormateado\"\n";

      final nombreArchivo = "Reporte_Flota_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.csv";

      try {
        await FirebaseFirestore.instance.collection('reportes').add({
          'empresa_correo': FirebaseAuth.instance.currentUser?.email ?? "",
          'fecha': DateTime.now().toIso8601String(),
          'monto_total': sumaTotal,
          'total_recibos': docs.length,
          'csv_data': csvData,
          'nombre_archivo': nombreArchivo,
        });
      } catch (e) {
        print("Error respaldando reporte de flota: $e");
      }

      if (kIsWeb) {
        final bytes = utf8.encode('\uFEFF$csvData');
        final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
        final url = html.Url.createObjectUrlFromBlob(blob);
        
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", nombreArchivo)
          ..style.display = 'none';
        
        html.document.body?.children.add(anchor);
        anchor.click();
        
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archivo CSV descargado.')));
      } else {
        final bytes = Uint8List.fromList([239, 187, 191] + utf8.encode(csvData));
        await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar Excel: $e')));
    }
  }

  void _descargarReporteExistenteAdmin(String csvData, String nombreArchivo) async {
    if (kIsWeb) {
      final bytes = utf8.encode('\uFEFF$csvData'); 
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", nombreArchivo)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } else {
      final bytes = Uint8List.fromList([239, 187, 191] + utf8.encode(csvData));
      await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
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
      imagenFinal = const Icon(Icons.business, color: Color(0xFF0D47A1), size: 24);
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

              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 15),
              const Text("HISTORIAL DE REPORTES GENERADOS (FLOTA)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reportes')
                    .where('empresa_correo', isEqualTo: emailAdmin)
                    .snapshots(),
                builder: (context, snapshotReportes) {
                  if (!snapshotReportes.hasData) return const Center(child: CircularProgressIndicator());
                  final rDocs = snapshotReportes.data!.docs;
                  if (rDocs.isEmpty) return const Center(child: Text("No hay reportes archivados en esta flota.", style: TextStyle(color: Colors.grey, fontSize: 13)));
                  
                  final listaDocs = List<QueryDocumentSnapshot>.from(rDocs);
                  listaDocs.sort((a, b) => (b.data() as Map<String, dynamic>)['fecha'].toString().compareTo((a.data() as Map<String, dynamic>)['fecha'].toString()));

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: listaDocs.length,
                    itemBuilder: (context, index) {
                      final rData = listaDocs[index].data() as Map<String, dynamic>;
                      final fechaRep = DateTime.parse(rData['fecha'] ?? DateTime.now().toIso8601String());
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.insert_drive_file, color: Colors.green),
                          title: Text(rData['nombre_archivo'] ?? 'Finanzas.csv', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text("Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(fechaRep)}\nMonto total: ${f.format(rData['monto_total'] ?? 0)} (${rData['total_recibos'] ?? 0} viajes)"),
                          trailing: IconButton(
                            icon: const Icon(Icons.download_for_offline, color: Color(0xFF0D47A1), size: 28),
                            onPressed: () => _descargarReporteExistenteAdmin(rData['csv_data'] ?? '', rData['nombre_archivo'] ?? 'Reporte.csv'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
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
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12), 
        border: Border(left: BorderSide(color: c, width: 6)), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08), 
            blurRadius: 6,
          )
        ],
      ),
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

    return TextEditingValue(text: finalTxt, selection: TextSelection.collapsed(offset: finalTxt.length));
  }
}