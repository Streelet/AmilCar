import '../models/cliente.dart';
import '../models/metodo_pago.dart';
import '../models/nota.dart';
import '../models/orden_trabajo.dart';
import '../models/pago.dart';
import '../models/pdf_cotizacion.dart';
import '../models/perfil.dart';

/// Una cuenta de prueba para el modo Mockup (login simulado).
class DemoAccount {
  const DemoAccount({
    required this.email,
    required this.password,
    required this.perfil,
  });

  final String email;
  final String password;
  final Perfil perfil;
}

/// Set de datos ficticios locales para el MODO MOCKUP.
///
/// Permite probar el 100% de la lógica de negocio sin internet ni tablas:
/// login simulado, cambio de roles, Kanban con drag&drop, botones de PDF y
/// el diálogo de aprobación de monto.
///
/// La normalización refleja la arquitectura real: un mismo `Cliente` puede
/// referenciarse desde varias `OrdenTrabajo` vía `clienteId`.
class MockData {
  const MockData._();

  /// Usuarios de prueba: un 'admin' (PC) y un 'asesor' (técnico en campo).
  /// Contraseña para ambos: `123456`.
  static const List<DemoAccount> demoAccounts = [
    DemoAccount(
      email: 'admin@amilcar.com',
      password: '123456',
      perfil: Perfil(
        id: 'mock-admin',
        rol: UserRole.admin,
        nombre: 'Erick (Admin)',
        email: 'admin@amilcar.com',
        // fotoUrl null a propósito: en modo offline se muestran iniciales.
        fotoUrl: null,
      ),
    ),
    DemoAccount(
      email: 'asesor@amilcar.com',
      password: '123456',
      perfil: Perfil(
        id: 'mock-asesor',
        rol: UserRole.asesor,
        nombre: 'Hermano (Asesor)',
        email: 'asesor@amilcar.com',
        fotoUrl: null,
      ),
    ),
  ];

  /// Genera una copia fresca y mutable del directorio de clientes ficticio.
  /// El [MockClientesRepository] trabaja sobre esta lista en memoria.
  static List<Cliente> seedClientes() {
    return [
      const Cliente(
        id: 'c1',
        nombre: 'María González',
        telefono: '+502 5512 8834',
        direccion: 'Km 14.5 Carretera a El Salvador, frente a Pradera',
        email: 'maria.gonzalez@gmail.com',
      ),
      const Cliente(
        id: 'c2',
        nombre: 'Carlos Méndez',
        telefono: '+502 4478 1290',
        direccion: 'Zona 10, 5a Avenida, varado en parqueo',
        email: 'carlos.mendez@outlook.com',
      ),
      const Cliente(
        id: 'c3',
        nombre: 'Ana Lucía Pérez',
        telefono: '+502 3320 9981',
        direccion: 'Mixco, Calzada San Juan, taller cerrado',
        email: null,
      ),
      const Cliente(
        id: 'c4',
        nombre: 'Roberto Castillo',
        telefono: '+502 5566 7788',
        direccion: 'Antigua Guatemala, 3a Calle Poniente',
        email: 'rcastillo@empresa.com',
      ),
      const Cliente(
        id: 'c5',
        nombre: 'Lcda. Patricia Solórzano',
        telefono: '+502 4012 3344',
        direccion: 'Zona 15, Vista Hermosa II',
        email: 'patricia.solorzano@bufete.gt',
      ),
      const Cliente(
        id: 'c6',
        nombre: 'Jorge Ramírez',
        telefono: '+502 5901 2233',
        direccion: 'Villa Nueva, Bulevar El Frutal',
        email: null,
      ),
      const Cliente(
        id: 'c7',
        nombre: 'Sofía Aguilar',
        telefono: '+502 4455 6677',
        direccion: 'Zona 16, Cayalá',
        email: 'sofia.aguilar@gmail.com',
      ),
      const Cliente(
        id: 'c8',
        nombre: 'Empresa TransCargo S.A.',
        telefono: '+502 2233 4455',
        direccion: 'Amatitlán, ruta al Pacífico Km 28',
        email: 'flotilla@transcargo.com.gt',
      ),
      const Cliente(
        id: 'c9',
        nombre: 'Diego Fuentes',
        telefono: '+502 5677 8899',
        direccion: 'Zona 11, Colonia Mariscal',
        email: null,
      ),
      const Cliente(
        id: 'c10',
        nombre: 'Luis Morales',
        telefono: '+502 4001 0010',
        direccion: 'Chimaltenango, entrada principal',
        email: 'luis.morales@hotmail.com',
      ),
    ];
  }

  /// Genera una copia fresca y mutable de las órdenes de trabajo ficticias.
  /// El [MockOrdenesTrabajoRepository] trabaja sobre esta lista en memoria.
  ///
  /// Nota: la orden `e11` referencia el mismo cliente `c1` (María González)
  /// que `e1` — caso explícito para demostrar que la normalización soporta
  /// varias órdenes por cliente.
  static List<OrdenTrabajo> seedOrdenesTrabajo() {
    final ahora = DateTime.now();
    DateTime hace(int dias) => ahora.subtract(Duration(days: dias));

    return [
      // ───────── Columna: Por Hacer ─────────
      OrdenTrabajo(
        id: 'e1',
        clienteId: 'c1',
        vehiculoMarca: 'Toyota',
        vehiculoModelo: 'Hilux',
        vehiculoAnio: 2021,
        vehiculoVin: 'MR0FB22G1M0123456',
        fotosUrls: const ['foto_bumper_1.jpg', 'foto_bumper_2.jpg'],
        notas: [
          Nota(
            texto: 'El cliente reporta un ruido al frenar; revisar pastillas '
                'antes de cualquier otra cosa.',
            fecha: hace(1),
          ),
        ],
        estadoKanban: EstadoKanban.porHacer,
        createdAt: hace(1),
      ),
      OrdenTrabajo(
        id: 'e2',
        clienteId: 'c2',
        vehiculoMarca: 'Nissan',
        vehiculoModelo: 'Frontier',
        vehiculoAnio: 2019,
        vehiculoVin: '1N6AD0ER5KN712345',
        fotosUrls: const ['foto_motor.jpg'],
        estadoKanban: EstadoKanban.porHacer,
        createdAt: hace(1),
      ),

      // ───────── Columna: Listos para Enviar ─────────
      OrdenTrabajo(
        id: 'e3',
        clienteId: 'c3',
        vehiculoMarca: 'Honda',
        vehiculoModelo: 'CR-V',
        vehiculoAnio: 2020,
        vehiculoVin: '7FARW2H50LE012345',
        fotosUrls: const ['foto_faro.jpg', 'foto_capo.jpg', 'foto_lateral.jpg'],
        pdfsUrls: const [
          PdfCotizacion(
            titulo: 'OEM',
            url: 'cotizacion_crv_oem.pdf',
            montoSugerido: 5000,
          ),
          PdfCotizacion(
            titulo: 'Aftermarket',
            url: 'cotizacion_crv_aftermarket.pdf',
            montoSugerido: 3500,
          ),
        ],
        estadoKanban: EstadoKanban.listosParaEnviar,
        createdAt: hace(2),
      ),
      OrdenTrabajo(
        id: 'e4',
        clienteId: 'c4',
        vehiculoMarca: 'Mazda',
        vehiculoModelo: 'CX-5',
        vehiculoAnio: 2022,
        vehiculoVin: 'JM3KFBCM8N0123456',
        fotosUrls: const ['foto_transmision.jpg'],
        pdfsUrls: const [
          PdfCotizacion(
            titulo: 'Reparación completa',
            url: 'cotizacion_cx5_full.pdf',
            montoSugerido: 8200,
          ),
        ],
        estadoKanban: EstadoKanban.listosParaEnviar,
        createdAt: hace(3),
      ),

      // ───────── Columna: Esperando Aprobación ─────────
      OrdenTrabajo(
        id: 'e5',
        clienteId: 'c5',
        vehiculoMarca: 'Toyota',
        vehiculoModelo: 'Land Cruiser Prado',
        vehiculoAnio: 2018,
        vehiculoVin: 'JTEBR3FJ8J5098765',
        fotosUrls: const ['foto_suspension_1.jpg', 'foto_suspension_2.jpg'],
        pdfsUrls: const [
          PdfCotizacion(
            titulo: 'OEM',
            url: 'cotizacion_prado_oem.pdf',
            montoSugerido: 12500,
          ),
          PdfCotizacion(
            titulo: 'Aftermarket Premium',
            url: 'cotizacion_prado_aft_premium.pdf',
            montoSugerido: 8900,
          ),
          PdfCotizacion(
            titulo: 'Aftermarket Económico',
            url: 'cotizacion_prado_aft_eco.pdf',
            montoSugerido: 6400,
          ),
        ],
        notas: [
          Nota(
            texto: 'Suspensión vencida en ambos amortiguadores delanteros.',
            fecha: hace(4),
          ),
          Nota(
            texto: 'La clienta pide priorizar el repuesto OEM como primera '
                'opción.',
            fecha: hace(3),
          ),
        ],
        estadoKanban: EstadoKanban.esperandoAprobacion,
        createdAt: hace(4),
      ),
      OrdenTrabajo(
        id: 'e6',
        clienteId: 'c6',
        vehiculoMarca: 'Hyundai',
        vehiculoModelo: 'Tucson',
        vehiculoAnio: 2021,
        vehiculoVin: 'KM8J3CA46MU012345',
        fotosUrls: const ['foto_frenos.jpg', 'foto_disco.jpg'],
        pdfsUrls: const [
          PdfCotizacion(
            titulo: 'OEM',
            url: 'cotizacion_tucson_oem.pdf',
            montoSugerido: 4200,
          ),
          PdfCotizacion(
            titulo: 'Aftermarket',
            url: 'cotizacion_tucson_aft.pdf',
            montoSugerido: 2800,
          ),
        ],
        estadoKanban: EstadoKanban.esperandoAprobacion,
        createdAt: hace(5),
      ),

      // ───────── Pestaña: Pendientes de Trabajo (ya aprobado) ─────────
      OrdenTrabajo(
        id: 'e7',
        clienteId: 'c7',
        vehiculoMarca: 'Kia',
        vehiculoModelo: 'Sportage',
        vehiculoAnio: 2020,
        vehiculoVin: 'KNDPM3AC5L7012345',
        fotosUrls: const ['foto_aire.jpg'],
        pdfsUrls: const [
          PdfCotizacion(
            titulo: 'OEM',
            url: 'cotizacion_sportage_oem.pdf',
            montoSugerido: 3900,
          ),
          PdfCotizacion(
            titulo: 'Aftermarket',
            url: 'cotizacion_sportage_aft.pdf',
            montoSugerido: 2600,
          ),
        ],
        montoAprobado: 2600,
        estadoKanban: EstadoKanban.pendienteTrabajo,
        createdAt: hace(6),
      ),

      // ───────── Pestaña: En Proceso ─────────
      OrdenTrabajo(
        id: 'e8',
        clienteId: 'c8',
        vehiculoMarca: 'Isuzu',
        vehiculoModelo: 'NPR',
        vehiculoAnio: 2017,
        vehiculoVin: 'JALC4B16XH7012345',
        fotosUrls: const ['foto_clutch.jpg', 'foto_caja.jpg'],
        pdfsUrls: const [
          PdfCotizacion(
            titulo: 'Reparación integral',
            url: 'cotizacion_npr.pdf',
            montoSugerido: 15400,
          ),
        ],
        montoAprobado: 15400,
        estadoKanban: EstadoKanban.enProceso,
        createdAt: hace(8),
      ),

      // ───────── Pestaña: Pendiente de Pago (solo admin) ─────────
      OrdenTrabajo(
        id: 'e9',
        clienteId: 'c9',
        vehiculoMarca: 'Volkswagen',
        vehiculoModelo: 'Amarok',
        vehiculoAnio: 2019,
        vehiculoVin: 'WV1ZZZ2HZKH012345',
        fotosUrls: const ['foto_radiador.jpg'],
        pdfsUrls: const [
          PdfCotizacion(
            titulo: 'OEM',
            url: 'cotizacion_amarok_oem.pdf',
            montoSugerido: 6700,
          ),
        ],
        notas: [
          Nota(
            texto: 'Trabajo terminado. Pendiente coordinar el pago con el '
                'cliente.',
            fecha: hace(2),
          ),
        ],
        montoAprobado: 6700,
        estadoKanban: EstadoKanban.pendientePago,
        createdAt: hace(12),
      ),

      // ───────── Archivado (no aparece en el tablero activo) ─────────
      OrdenTrabajo(
        id: 'e10',
        clienteId: 'c10',
        vehiculoMarca: 'Suzuki',
        vehiculoModelo: 'Vitara',
        vehiculoAnio: 2016,
        vehiculoVin: 'JS3TD0D45G4012345',
        fotosUrls: const ['foto_alternador.jpg'],
        pdfsUrls: const [
          PdfCotizacion(
            titulo: 'OEM',
            url: 'cotizacion_vitara_oem.pdf',
            montoSugerido: 3100,
          ),
          PdfCotizacion(
            titulo: 'Aftermarket',
            url: 'cotizacion_vitara_aft.pdf',
            montoSugerido: 1900,
          ),
        ],
        estadoKanban: EstadoKanban.esperandoAprobacion,
        archivado: true,
        createdAt: hace(15),
      ),

      // ───────── Cliente recurrente: María González vuelve con su Hilux ─────────
      // Demuestra que la normalización admite varias órdenes por cliente.
      OrdenTrabajo(
        id: 'e11',
        clienteId: 'c1',
        vehiculoMarca: 'Toyota',
        vehiculoModelo: 'Hilux',
        vehiculoAnio: 2021,
        vehiculoVin: 'MR0FB22G1M0123456',
        fotosUrls: const ['foto_servicio_mantenimiento.jpg'],
        pdfsUrls: const [
          PdfCotizacion(
            titulo: 'Servicio 60.000 km',
            url: 'cotizacion_hilux_servicio.pdf',
            montoSugerido: 1850,
          ),
        ],
        notas: [
          Nota(
            texto: 'Cliente recurrente. Servicio mayor programado.',
            fecha: hace(7),
          ),
        ],
        montoAprobado: 1850,
        estadoKanban: EstadoKanban.pendientePago,
        createdAt: hace(7),
      ),
    ];
  }

  /// Pagos / anticipos ficticios. Cubren tres casos para ver el "Restante"
  /// funcionando:
  ///   - e9 (Diego Fuentes, monto aprobado $6,700): un anticipo de $3,000
  ///     → restante $3,700.
  ///   - e11 (María González, monto aprobado $1,850): pagado completo en
  ///     un solo pago → restante $0 (badge "Pagado completo").
  static List<Pago> seedPagos() {
    final ahora = DateTime.now();
    DateTime hace(int dias) => ahora.subtract(Duration(days: dias));

    return [
      Pago(
        id: 'p1',
        ordenId: 'e9',
        monto: 3000,
        fecha: hace(1),
        metodoPago: MetodoPago.efectivo,
        notas: [
          Nota(
            texto: 'Anticipo en efectivo. Cliente entregó al recibir el '
                'vehículo.',
            fecha: hace(1),
          ),
        ],
      ),
      Pago(
        id: 'p2',
        ordenId: 'e11',
        monto: 1850,
        fecha: hace(3),
        metodoPago: MetodoPago.otro,
        metodoPagoOtro: 'Transferencia BAC',
        notas: [
          Nota(
            texto: 'Pago completo por transferencia BAC. '
                'Confirmación 4422-XX.',
            fecha: hace(3),
          ),
        ],
      ),
      // Pago cancelado de ejemplo: contra e9, $1,000 que el cliente
      // pidió revertir. Sigue visible (tachado) pero NO cuenta para el
      // saldo de e9 (que queda en $3,000 cobrado de $6,700).
      Pago(
        id: 'p3',
        ordenId: 'e9',
        monto: 1000,
        fecha: hace(1),
        metodoPago: MetodoPago.zelle,
        canceladoAt: DateTime.now(),
        motivoCancelacion:
            'Transferencia rebotó por error en datos. Se reintentará.',
        notas: [
          Nota(
            texto: 'Intento de pago Zelle (cancelado).',
            fecha: hace(1),
          ),
        ],
      ),
    ];
  }
}
