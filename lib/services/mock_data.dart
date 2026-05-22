import '../models/estimado.dart';
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

  /// Genera una copia fresca y mutable de los estimados ficticios.
  /// El repositorio mock trabaja sobre esta lista en memoria.
  static List<Estimado> seedEstimados() {
    final ahora = DateTime.now();
    DateTime hace(int dias) => ahora.subtract(Duration(days: dias));

    return [
      // ───────── Columna: Por Hacer ─────────
      Estimado(
        id: 'e1',
        clienteNombre: 'María González',
        telefono: '+502 5512 8834',
        direccion: 'Km 14.5 Carretera a El Salvador, frente a Pradera',
        vehiculoMarca: 'Toyota',
        vehiculoModelo: 'Hilux',
        vehiculoAnio: 2021,
        vehiculoVin: 'MR0FB22G1M0123456',
        fotosUrls: const ['foto_bumper_1.jpg', 'foto_bumper_2.jpg'],
        estadoKanban: EstadoKanban.porHacer,
        createdAt: hace(1),
      ),
      Estimado(
        id: 'e2',
        clienteNombre: 'Carlos Méndez',
        telefono: '+502 4478 1290',
        direccion: 'Zona 10, 5a Avenida, varado en parqueo',
        vehiculoMarca: 'Nissan',
        vehiculoModelo: 'Frontier',
        vehiculoAnio: 2019,
        vehiculoVin: '1N6AD0ER5KN712345',
        fotosUrls: const ['foto_motor.jpg'],
        estadoKanban: EstadoKanban.porHacer,
        createdAt: hace(1),
      ),

      // ───────── Columna: Listos para Enviar ─────────
      Estimado(
        id: 'e3',
        clienteNombre: 'Ana Lucía Pérez',
        telefono: '+502 3320 9981',
        direccion: 'Mixco, Calzada San Juan, taller cerrado',
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
      Estimado(
        id: 'e4',
        clienteNombre: 'Roberto Castillo',
        telefono: '+502 5566 7788',
        direccion: 'Antigua Guatemala, 3a Calle Poniente',
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
      Estimado(
        id: 'e5',
        clienteNombre: 'Lcda. Patricia Solórzano',
        telefono: '+502 4012 3344',
        direccion: 'Zona 15, Vista Hermosa II',
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
        estadoKanban: EstadoKanban.esperandoAprobacion,
        createdAt: hace(4),
      ),
      Estimado(
        id: 'e6',
        clienteNombre: 'Jorge Ramírez',
        telefono: '+502 5901 2233',
        direccion: 'Villa Nueva, Bulevar El Frutal',
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
      Estimado(
        id: 'e7',
        clienteNombre: 'Sofía Aguilar',
        telefono: '+502 4455 6677',
        direccion: 'Zona 16, Cayalá',
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
      Estimado(
        id: 'e8',
        clienteNombre: 'Empresa TransCargo S.A.',
        telefono: '+502 2233 4455',
        direccion: 'Amatitlán, ruta al Pacífico Km 28',
        vehiculoMarca: 'Isuzu',
        vehiculoModelo: 'NPR',
        vehiculoAnio: 2017,
        vehiculoVin: 'JALC4B16X H7012345',
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
      Estimado(
        id: 'e9',
        clienteNombre: 'Diego Fuentes',
        telefono: '+502 5677 8899',
        direccion: 'Zona 11, Colonia Mariscal',
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
        montoAprobado: 6700,
        estadoKanban: EstadoKanban.pendientePago,
        createdAt: hace(12),
      ),

      // ───────── Archivado (no aparece en el tablero activo) ─────────
      Estimado(
        id: 'e10',
        clienteNombre: 'Cliente Desistió - Luis Morales',
        telefono: '+502 4001 0010',
        direccion: 'Chimaltenango, entrada principal',
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
    ];
  }
}
