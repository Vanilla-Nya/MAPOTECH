class PageTutorialData {
  final String title;
  final String description;
  final List<TutorialStep> steps;

  const PageTutorialData({
    required this.title,
    required this.description,
    required this.steps,
  });
}

class TutorialStep {
  final String title;
  final String description;

  const TutorialStep({
    required this.title,
    required this.description,
  });
}

/// Localized Indonesian Page Tutorials
final Map<String, Map<String, PageTutorialData>> _idTutorials = {
  'dokter': {
    'dashboard': const PageTutorialData(
      title: 'Dashboard Praktik Mandiri',
      description: 'Pantau ringkasan statistik harian, status antrian pasien, jadwal janji temu, dan notifikasi penting.',
      steps: [
        TutorialStep(
          title: 'Statistik Cepat',
          description: 'Lihat jumlah pasien hari ini, pendapatan bulanan, dan efisiensi waktu pelayanan secara real-time.',
        ),
        TutorialStep(
          title: 'Jadwal Hari Ini',
          description: 'Kelola daftar kunjungan pasien terjadwal dan status kehadiran mereka secara langsung.',
        ),
      ],
    ),
    'pasien': const PageTutorialData(
      title: 'Manajemen Rekam Medis Pasien',
      description: 'Kelola data demografi pasien, riwayat alergi, catatan rekam medis (SOAP), dan resep obat yang pernah diberikan.',
      steps: [
        TutorialStep(
          title: 'Cari & Filter Pasien',
          description: 'Temukan data pasien dengan cepat menggunakan nama, nomor rekam medis, atau NIK.',
        ),
        TutorialStep(
          title: 'Tambah Pasien Baru',
          description: 'Daftarkan pasien baru ke klinik Anda lengkap dengan data kontak dan riwayat medis awal.',
        ),
      ],
    ),
    'obat': const PageTutorialData(
      title: 'Inventori Obat & Resep',
      description: 'Kelola persediaan obat pribadi klinik, harga jual, dosis rekomendasi, dan buat resep elektronik (e-prescription).',
      steps: [
        TutorialStep(
          title: 'Stok Obat',
          description: 'Pantau jumlah sisa obat, tanggal kedaluwarsa, dan dapatkan peringatan otomatis jika stok menipis.',
        ),
        TutorialStep(
          title: 'Daftar Resep',
          description: 'Lihat daftar resep yang telah Anda berikan kepada pasien dan status pengambilan obat di apotek.',
        ),
      ],
    ),
    'antrian': const PageTutorialData(
      title: 'Sistem Antrian Pasien',
      description: 'Kelola urutan panggilan pemeriksaan pasien di ruang tunggu secara teratur dan real-time.',
      steps: [
        TutorialStep(
          title: 'Panggil & Lewati',
          description: 'Klik tombol Panggil untuk memanggil pasien berikutnya atau Lewati jika pasien tidak hadir.',
        ),
        TutorialStep(
          title: 'Prioritas Antrian',
          description: 'Atur prioritas antrian khusus untuk kondisi darurat atau pasien dengan kebutuhan khusus.',
        ),
      ],
    ),
    'pemeriksaan': const PageTutorialData(
      title: 'Modul Pemeriksaan Dokter',
      description: 'Catat keluhan pasien, pemeriksaan fisik, diagnosis ICD-10, tindakan medis, dan resep obat.',
      steps: [
        TutorialStep(
          title: 'Metode SOAP',
          description: 'Isi Subjektif, Objektif, Asesmen, dan Perencanaan secara terstruktur pada rekam medis pasien.',
        ),
        TutorialStep(
          title: 'Rekomendasi Tindakan',
          description: 'Pilih tindakan medis dan input tarif tindakan secara langsung ke dalam sistem kasir.',
        ),
      ],
    ),
    'pembukuan': const PageTutorialData(
      title: 'Laporan Keuangan & Kasir',
      description: 'Pantau total pemasukan klinik, pengeluaran operasional, pembayaran pasien, dan klaim asuransi.',
      steps: [
        TutorialStep(
          title: 'Kasir Digital',
          description: 'Proses pembayaran jasa medis, obat, dan tindakan dari pasien secara tunai maupun non-tunai.',
        ),
        TutorialStep(
          title: 'Laporan Pendapatan',
          description: 'Unduh laporan berkala harian, mingguan, atau bulanan untuk analisis performa klinik.',
        ),
      ],
    ),
    'asisten_praktik': const PageTutorialData(
      title: 'Manajemen Asisten Praktik',
      description: 'Kelola akun asisten, perawat, atau staf administrasi klinik Anda dengan hak akses yang terenkripsi.',
      steps: [
        TutorialStep(
          title: 'Hak Akses Staf',
          description: 'Atur bagian mana saja yang dapat diakses oleh asisten Anda (misal: hanya registrasi & antrian).',
        ),
        TutorialStep(
          title: 'Aktivitas Staf',
          description: 'Pantau riwayat pencatatan dan aktivitas staf untuk menjaga transparansi operasional.',
        ),
      ],
    ),
    'profile': const PageTutorialData(
      title: 'Profil Profesional Dokter',
      description: 'Atur profil publik Anda agar mudah ditemukan pasien. Tambahkan informasi spesialisasi, jam praktik, dan lokasi klinik Anda.',
      steps: [
        TutorialStep(
          title: 'Foto Profil',
          description: 'Unggah foto profesional Anda untuk memberikan kesan terpercaya kepada pasien.',
        ),
        TutorialStep(
          title: 'Jam Praktik',
          description: 'Atur jadwal ketersediaan Anda agar pasien dapat membuat janji temu pada waktu yang tepat.',
        ),
      ],
    ),
  },
  'apotek': {
    'dashboard': const PageTutorialData(
      title: 'Dashboard Operasional Apotek',
      description: 'Ringkasan penjualan hari ini, pesanan masuk yang perlu diproses, status inventori obat, dan aktivitas staff.',
      steps: [
        TutorialStep(
          title: 'Grafik Penjualan',
          description: 'Analisis tren penjualan obat resep dan obat bebas secara berkala.',
        ),
        TutorialStep(
          title: 'Peringatan Penting',
          description: 'Notifikasi otomatis untuk obat mendekati kedaluwarsa atau stok kritis di bawah batas minimum.',
        ),
      ],
    ),
    'penjualan': const PageTutorialData(
      title: 'Point of Sale (POS) Apotek',
      description: 'Sistem kasir cepat untuk transaksi penjualan obat bebas (OTC) maupun obat resep dokter.',
      steps: [
        TutorialStep(
          title: 'Scan Barcode',
          description: 'Gunakan kamera atau scanner untuk memasukkan obat ke dalam keranjang belanja secara instan.',
        ),
        TutorialStep(
          title: 'Verifikasi Resep',
          description: 'Periksa keaslian resep digital atau fisik dari dokter sebelum menyerahkan obat keras.',
        ),
      ],
    ),
    'inventori': const PageTutorialData(
      title: 'Manajemen Stok & Inventori',
      description: 'Kelola daftar obat, kategori, batch number, tanggal kedaluwarsa, harga beli, dan harga jual retail.',
      steps: [
        TutorialStep(
          title: 'Kartu Stok',
          description: 'Lacak riwayat masuk dan keluar obat secara detail untuk mencegah selisih stok.',
        ),
        TutorialStep(
          title: 'Stok Opname',
          description: 'Lakukan pencocokan stok fisik di gudang dengan data di sistem secara terjadwal.',
        ),
      ],
    ),
    'pesanan': const PageTutorialData(
      title: 'Kelola Pesanan Masuk',
      description: 'Proses pesanan obat online yang dipesan oleh pasien melalui aplikasi MAPOTECH.',
      steps: [
        TutorialStep(
          title: 'Verifikasi Pesanan',
          description: 'Periksa ketersediaan item yang dipesan sebelum menyetujui transaksi.',
        ),
        TutorialStep(
          title: 'Pengiriman & Ambil di Tempat',
          description: 'Siapkan paket obat untuk kurir pengiriman atau beri notifikasi siap ambil ke pasien.',
        ),
      ],
    ),
    'laporan': const PageTutorialData(
      title: 'Laporan Keuangan Apotek',
      description: 'Lihat laba rugi, omset harian, laporan penjualan per kategori obat, dan pajak penjualan.',
      steps: [
        TutorialStep(
          title: 'Ekspor Laporan',
          description: 'Unduh data keuangan dalam format PDF atau Excel untuk pelaporan pajak & internal.',
        ),
        TutorialStep(
          title: 'Analisis Margin',
          description: 'Identifikasi produk obat dengan profit margin terbaik untuk meningkatkan omset.',
        ),
      ],
    ),
    'staff': const PageTutorialData(
      title: 'Manajemen Staff Apoteker',
      description: 'Kelola jam kerja shift, hak akses kasir apotek, dan performa transaksi tiap asisten apoteker.',
      steps: [
        TutorialStep(
          title: 'Jadwal Shift',
          description: 'Atur jadwal kerja apoteker penanggung jawab dan asisten secara mingguan.',
        ),
        TutorialStep(
          title: 'Audit Log Kasir',
          description: 'Pantau transaksi yang dilakukan oleh masing-masing akun kasir untuk menghindari fraud.',
        ),
      ],
    ),
    'profile': const PageTutorialData(
      title: 'Profil Publik Apotek',
      description: 'Lengkapi informasi apotek seperti jam buka, foto apotek, lokasi peta, dan nomor telepon darurat.',
      steps: [
        TutorialStep(
          title: 'SIA & SIPA',
          description: 'Unggah dokumen Surat Izin Apotek dan Surat Izin Praktik Apoteker agar terverifikasi oleh dinas terkait.',
        ),
        TutorialStep(
          title: 'Layanan Pengantaran',
          description: 'Aktifkan atau nonaktifkan radius layanan pengantaran obat ke rumah pasien.',
        ),
      ],
    ),
  },
  'pasien': {
    'dashboard': const PageTutorialData(
      title: 'Portal Layanan Kesehatan Pasien',
      description: 'Temukan klinik terdekat, konsultasi dengan dokter profesional, cari obat di apotek terdekat, dan pantau resep Anda.',
      steps: [
        TutorialStep(
          title: 'Pencarian Cepat',
          description: 'Cari dokter spesialis atau apotek terdekat dari lokasi Anda saat ini secara instan.',
        ),
        TutorialStep(
          title: 'Resep Aktif',
          description: 'Pantau resep digital dari dokter yang siap ditebus di apotek pilihan Anda.',
        ),
      ],
    ),
    'dokter_search': const PageTutorialData(
      title: 'Cari Praktik Dokter Mandiri',
      description: 'Cari dokter berdasarkan spesialisasi, lokasi, jarak, rating, jadwal ketersediaan praktik, dan tarif konsultasi.',
      steps: [
        TutorialStep(
          title: 'Booking Jadwal',
          description: 'Pilih hari dan jam yang tersedia, lalu buat janji temu konsultasi secara online.',
        ),
        TutorialStep(
          title: 'Profil Dokter',
          description: 'Baca ulasan pasien lain, riwayat pendidikan, dan pengalaman kerja dokter sebelum memesan.',
        ),
      ],
    ),
    'puskesmas_search': const PageTutorialData(
      title: 'Cari Puskesmas & Faskes Publik',
      description: 'Temukan Puskesmas, Ponkesdes, dan Pustu terdekat untuk mendapatkan pelayanan kesehatan masyarakat.',
      steps: [
        TutorialStep(
          title: 'Informasi Layanan & BPJS',
          description: 'Lihat status penerimaan BPJS, jam layanan, dan fasilitas klaster yang tersedia.',
        ),
        TutorialStep(
          title: 'Peta & Petunjuk Arah',
          description: 'Buka peta dan petunjuk arah langsung menuju fasilitas kesehatan pilihan Anda.',
        ),
      ],
    ),
    'pustu_search': const PageTutorialData(
      title: 'Cari Pustu & Ponkesdes',
      description: 'Temukan Puskesmas Pembantu (Pustu) dan Pondok Kesehatan Desa (Ponkesdes) terdekat di wilayah desa Anda.',
      steps: [
        TutorialStep(
          title: 'Layanan Desa',
          description: 'Lihat lokasi Pustu dan Ponkesdes untuk pelayanan kesehatan dasar terdekat.',
        ),
      ],
    ),
        ),
      ],
    ),
    'apotek_search': const PageTutorialData(
      title: 'Cari Apotek & Tebus Obat',
      description: 'Temukan apotek terdekat yang memiliki stok obat lengkap, bandingkan harga obat, dan pesan obat untuk diantar.',
      steps: [
        TutorialStep(
          title: 'Cek Ketersediaan',
          description: 'Ketik nama obat untuk mencari apotek mana saja yang memiliki stok obat tersebut.',
        ),
        TutorialStep(
          title: 'Tebus Resep Digital',
          description: 'Kirimkan resep digital dari dokter langsung ke apotek terpilih untuk disiapkan.',
        ),
      ],
    ),
    'history': const PageTutorialData(
      title: 'Riwayat Konsultasi & Medis',
      description: 'Lihat catatan riwayat pemeriksaan Anda, riwayat diagnosis, hasil lab, serta kuitansi pembayaran.',
      steps: [
        TutorialStep(
          title: 'Detail Pemeriksaan',
          description: 'Buka kembali catatan diagnosis dan anjuran dokter dari pemeriksaan terdahulu.',
        ),
        TutorialStep(
          title: 'Unduh Invoice',
          description: 'Dapatkan bukti pembayaran sah untuk keperluan reimburse kantor atau asuransi pribadi.',
        ),
      ],
    ),
    'prescription': const PageTutorialData(
      title: 'Daftar Resep & Pengingat Obat',
      description: 'Pantau resep aktif, aturan minum obat, dan atur alarm pengingat minum obat agar konsisten.',
      steps: [
        TutorialStep(
          title: 'Aturan Minum',
          description: 'Lihat instruksi detail dosis (misal: 3x1 sehari setelah makan) langsung dari dokter.',
        ),
        TutorialStep(
          title: 'Alarm Minum Obat',
          description: 'Aktifkan pengingat notifikasi otomatis di ponsel Anda untuk setiap jadwal minum obat.',
        ),
      ],
    ),
    'profile': const PageTutorialData(
      title: 'Informasi Profil Medis Pasien',
      description: 'Lengkapi profil medis pribadi Anda, termasuk golongan darah, alergi obat, riwayat penyakit kronis, dan kontak darurat.',
      steps: [
        TutorialStep(
          title: 'Kartu Pasien Digital',
          description: 'Tunjukkan barcode profil Anda saat registrasi di klinik untuk mempercepat proses check-in.',
        ),
        TutorialStep(
          title: 'Alergi Obat',
          description: 'Wajib cantumkan daftar alergi obat Anda agar dokter tidak salah memberikan resep.',
        ),
      ],
    ),
  },
};

/// Localized English Page Tutorials
final Map<String, Map<String, PageTutorialData>> _enTutorials = {
  'dokter': {
    'dashboard': const PageTutorialData(
      title: 'Doctor Dashboard',
      description: 'Monitor daily statistics summaries, patient queue status, scheduled appointments, and important notifications.',
      steps: [
        TutorialStep(
          title: 'Quick Stats',
          description: 'View today\'s patient count, monthly revenue, and average service time efficiency in real-time.',
        ),
        TutorialStep(
          title: 'Today\'s Schedule',
          description: 'Manage scheduled patient visits and monitor their check-in status directly.',
        ),
      ],
    ),
    'pasien': const PageTutorialData(
      title: 'Patient Medical Record Management',
      description: 'Manage patient demographic data, drug allergies, medical record notes (SOAP), and historical prescriptions.',
      steps: [
        TutorialStep(
          title: 'Search & Filter',
          description: 'Find patient records quickly using name, medical record number, or national ID (NIK).',
        ),
        TutorialStep(
          title: 'Add New Patient',
          description: 'Register a new patient to your clinic with essential contact info and initial medical history.',
        ),
      ],
    ),
    'obat': const PageTutorialData(
      title: 'Medication Inventory & Prescriptions',
      description: 'Manage clinic drug stock, selling prices, recommended dosages, and issue digital prescriptions (e-prescriptions).',
      steps: [
        TutorialStep(
          title: 'Drug Stock',
          description: 'Monitor stock levels, expiration dates, and get automatic warnings when inventory runs low.',
        ),
        TutorialStep(
          title: 'Prescription List',
          description: 'Review digital prescriptions issued to patients and their collection status at pharmacies.',
        ),
      ],
    ),
    'antrian': const PageTutorialData(
      title: 'Patient Queue System',
      description: 'Manage the sequence of patients waiting for check-ups in the waiting room in real-time.',
      steps: [
        TutorialStep(
          title: 'Call & Skip',
          description: 'Click the Call button to summon the next patient or Skip if they are absent.',
        ),
        TutorialStep(
          title: 'Queue Priority',
          description: 'Assign priority status for emergency cases or patients with special needs.',
        ),
      ],
    ),
    'pemeriksaan': const PageTutorialData(
      title: 'Medical Examination Module',
      description: 'Record patient symptoms, physical exam notes, ICD-10 diagnosis, procedures, and prescriptions.',
      steps: [
        TutorialStep(
          title: 'SOAP Method',
          description: 'Fill in Subjective, Objective, Assessment, and Plan notes systematically in patient charts.',
        ),
        TutorialStep(
          title: 'Recommend Procedures',
          description: 'Select medical procedures and input rates directly into the billing system.',
        ),
      ],
    ),
    'pembukuan': const PageTutorialData(
      title: 'Financial Reports & Cashier',
      description: 'Monitor total clinic income, operational expenses, patient payments, and insurance claims.',
      steps: [
        TutorialStep(
          title: 'Digital Cashier',
          description: 'Process payments for consultation fees, medicines, and procedures via cash or cashless methods.',
        ),
        TutorialStep(
          title: 'Revenue Reports',
          description: 'Download daily, weekly, or monthly reports to analyze your clinic\'s financial performance.',
        ),
      ],
    ),
    'asisten_praktik': const PageTutorialData(
      title: 'Practice Assistant Management',
      description: 'Manage assistant, nurse, or administrative staff credentials with encrypted access permissions.',
      steps: [
        TutorialStep(
          title: 'Staff Permissions',
          description: 'Configure which features your assistant can access (e.g., only registration & queue).',
        ),
        TutorialStep(
          title: 'Activity Logs',
          description: 'Audit record modifications and staff activity history for operational transparency.',
        ),
      ],
    ),
    'profile': const PageTutorialData(
      title: 'Doctor Professional Profile',
      description: 'Configure your public profile to make it easy for patients to find you. Add specialities, practice hours, and clinic location.',
      steps: [
        TutorialStep(
          title: 'Profile Photo',
          description: 'Upload your professional photo to establish trust and credibility with patients.',
        ),
        TutorialStep(
          title: 'Practice Hours',
          description: 'Set your availability schedule so patients can book appointments at the right time.',
        ),
      ],
    ),
  },
  'apotek': {
    'dashboard': const PageTutorialData(
      title: 'Pharmacy Operations Dashboard',
      description: 'Summaries of today\'s sales, incoming orders waiting to be processed, stock alerts, and staff activities.',
      steps: [
        TutorialStep(
          title: 'Sales Chart',
          description: 'Analyze sales trends of prescription and over-the-counter (OTC) medicines over time.',
        ),
        TutorialStep(
          title: 'Critical Alerts',
          description: 'Get automated alerts for medicines nearing expiration or falling below safety stock limits.',
        ),
      ],
    ),
    'penjualan': const PageTutorialData(
      title: 'Pharmacy Point of Sale (POS)',
      description: 'Fast checkout system for over-the-counter (OTC) and digital doctor prescription transactions.',
      steps: [
        TutorialStep(
          title: 'Scan Barcodes',
          description: 'Use a camera or scanner to search and add medicines to the cart instantly.',
        ),
        TutorialStep(
          title: 'Verify Prescription',
          description: 'Verify digital or physical doctor prescriptions before dispensing restricted medication.',
        ),
      ],
    ),
    'inventori': const PageTutorialData(
      title: 'Stock & Inventory Management',
      description: 'Manage drug items, categories, batch numbers, expiration dates, cost prices, and retail margins.',
      steps: [
        TutorialStep(
          title: 'Stock Cards',
          description: 'Track detailed incoming and outgoing stock logs to prevent inventory discrepancies.',
        ),
        TutorialStep(
          title: 'Stock Count',
          description: 'Perform scheduled physical stock counts in the warehouse to match digital balances.',
        ),
      ],
    ),
    'pesanan': const PageTutorialData(
      title: 'Manage Incoming Orders',
      description: 'Process online medicine orders placed by patients through the MAPOTECH app.',
      steps: [
        TutorialStep(
          title: 'Order Verification',
          description: 'Check item stock availability and details before accepting incoming orders.',
        ),
        TutorialStep(
          title: 'Delivery & Pick-Up',
          description: 'Prepare medication packages for shipping couriers or send ready-to-collect alerts to patients.',
        ),
      ],
    ),
    'laporan': const PageTutorialData(
      title: 'Pharmacy Financial Reports',
      description: 'Review profit margins, daily revenue, sales reports grouped by drug categories, and sales tax.',
      steps: [
        TutorialStep(
          title: 'Export Reports',
          description: 'Download financial statements in PDF or Excel formats for tax filings and business audits.',
        ),
        TutorialStep(
          title: 'Margin Analysis',
          description: 'Identify high-margin products to optimize inventory and maximize returns.',
        ),
      ],
    ),
    'staff': const PageTutorialData(
      title: 'Pharmacist Staf Management',
      description: 'Configure shift rosters, cashier checkouts access, and track transaction performance of each assistant.',
      steps: [
        TutorialStep(
          title: 'Shift Schedules',
          description: 'Create weekly shift schedules for supervising pharmacists and pharmacy technicians.',
        ),
        TutorialStep(
          title: 'Cashier Audit Log',
          description: 'Monitor all transactions finalized by cashier accounts to prevent financial errors.',
        ),
      ],
    ),
    'profile': const PageTutorialData(
      title: 'Public Pharmacy Profile',
      description: 'Complete pharmacy details such as business hours, storefront photos, map pin location, and emergency contacts.',
      steps: [
        TutorialStep(
          title: 'Licensing (SIA/SIPA)',
          description: 'Upload required health department permit documents to achieve verified pharmacy status.',
        ),
        TutorialStep(
          title: 'Delivery Service',
          description: 'Toggle on/off the home-delivery coverage radius and rates for patients.',
        ),
      ],
    ),
  },
  'pasien': {
    'dashboard': const PageTutorialData(
      title: 'Patient Health Services Portal',
      description: 'Find nearby medical practices, consult with professional doctors, locate pharmacies, and manage active prescriptions.',
      steps: [
        TutorialStep(
          title: 'Quick Search',
          description: 'Locate specialists or pharmacies closest to your current location instantly.',
        ),
        TutorialStep(
          title: 'Active Prescriptions',
          description: 'Track digital prescriptions from your doctor that are ready to be filled at your preferred pharmacy.',
        ),
      ],
    ),
    'dokter_search': const PageTutorialData(
      title: 'Search Medical Practices',
      description: 'Find doctors by specialty, location, distance, feedback ratings, available times, and consultation fees.',
      steps: [
        TutorialStep(
          title: 'Book Appointment',
          description: 'Select an available date and time slot, then book a medical visit online instantly.',
        ),
        TutorialStep(
          title: 'Doctor Profile',
          description: 'Read reviews from other patients, educational history, and clinical experience before booking.',
        ),
      ],
    ),
    'puskesmas_search': const PageTutorialData(
      title: 'Search Public Health Centers',
      description: 'Find nearby Puskesmas, Ponkesdes, and Pustu for comprehensive public healthcare services.',
      steps: [
        TutorialStep(
          title: 'Service Info & BPJS',
          description: 'Check BPJS coverage status, operating hours, and integrated healthcare cluster facilities.',
        ),
        TutorialStep(
          title: 'Maps & Directions',
          description: 'Get directions and map locations directly to your selected health center.',
        ),
      ],
    ),
    'pustu_search': const PageTutorialData(
      title: 'Search Pustu & Ponkesdes',
      description: 'Find auxiliary health centers (Pustu) and village health posts (Ponkesdes) in your local community.',
      steps: [
        TutorialStep(
          title: 'Community Care',
          description: 'Locate primary healthcare units providing localized village health services.',
        ),
      ],
    ),
        ),
      ],
    ),
    'apotek_search': const PageTutorialData(
      title: 'Search Pharmacies',
      description: 'Find pharmacies with complete medicine stock, compare item pricing, and buy medicine online.',
      steps: [
        TutorialStep(
          title: 'Check Inventory',
          description: 'Type a medicine name to see which nearby pharmacies have it in stock.',
        ),
        TutorialStep(
          title: 'Submit Digital Prescription',
          description: 'Send doctor-issued digital prescriptions directly to your selected pharmacy for preparation.',
        ),
      ],
    ),
    'history': const PageTutorialData(
      title: 'Medical History & Visits',
      description: 'Access records of your clinical visits, past diagnoses, laboratory results, and receipt invoices.',
      steps: [
        TutorialStep(
          title: 'Visit Details',
          description: 'Retrieve detailed doctor diagnosis and notes from your historical clinic appointments.',
        ),
        TutorialStep(
          title: 'Download Invoices',
          description: 'Export official payment receipts for employee health benefits or insurance reimbursement.',
        ),
      ],
    ),
    'prescription': const PageTutorialData(
      title: 'Prescriptions & Pill Reminders',
      description: 'View active prescriptions, dosage instructions, and configure automatic pill reminders.',
      steps: [
        TutorialStep(
          title: 'Usage Instructions',
          description: 'Check exact dosages (e.g. 3x daily after meals) prescribed directly by your physician.',
        ),
        TutorialStep(
          title: 'Pill Reminders',
          description: 'Enable recurring notifications on your smartphone for each of your medication times.',
        ),
      ],
    ),
    'profile': const PageTutorialData(
      title: 'Patient Medical Profile',
      description: 'Fill in your personal health records including blood type, drug allergies, chronic diseases, and emergency contacts.',
      steps: [
        TutorialStep(
          title: 'Digital Patient Card',
          description: 'Show your profile barcode at the clinic counter to speed up check-in registration.',
        ),
        TutorialStep(
          title: 'Drug Allergies',
          description: 'List all drug allergies to ensure doctors do not issue incompatible prescriptions.',
        ),
      ],
    ),
  },
};

/// Get page-specific tutorial data. Generates fallback if the page is not in the registry.
PageTutorialData getTutorialData(String role, String menuId, String menuLabel, String language) {
  final Map<String, Map<String, PageTutorialData>> selectedRegistry = 
      (language.toLowerCase() == 'en') ? _enTutorials : _idTutorials;

  final roleData = selectedRegistry[role.toLowerCase()];
  if (roleData != null) {
    final tutorial = roleData[menuId.toLowerCase()];
    if (tutorial != null) {
      return tutorial;
    }
  }

  // Fallback Generation
  final isEn = (language.toLowerCase() == 'en');
  final fallbackTitle = isEn 
      ? '$menuLabel Guide'
      : 'Panduan $menuLabel';
  final fallbackDesc = isEn
      ? 'Learn how to use the $menuLabel feature to manage your clinical and pharmacy operations effectively.'
      : 'Pelajari cara menggunakan fitur $menuLabel untuk mengelola aktivitas klinis dan apotek Anda secara efektif.';
  
  return PageTutorialData(
    title: fallbackTitle,
    description: fallbackDesc,
    steps: isEn 
        ? [
            const TutorialStep(
              title: 'Overview',
              description: 'Explore the interface, cards, and key information modules in this page.',
            ),
            const TutorialStep(
              title: 'Actions & Features',
              description: 'Configure and click on action buttons to execute tasks relevant to your workflow.',
            ),
          ]
        : [
            const TutorialStep(
              title: 'Ringkasan Halaman',
              description: 'Pelajari tampilan, kartu status, dan modul informasi utama pada halaman ini.',
            ),
            const TutorialStep(
              title: 'Aksi & Fitur Utama',
              description: 'Gunakan tombol tindakan untuk menjalankan instruksi atau tugas penting pada alur kerja Anda.',
            ),
          ],
  );
}
