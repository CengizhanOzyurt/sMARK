import SwiftUI
import MapKit
import CoreLocation
import Combine
import FirebaseAuth
import FirebaseFirestore

// --- KOORDINAT ESITLEME ---
// harita uzerindeki iki koordinatın (enlem ve boylam) birbirine esit olup olmadigini
// kontrol edebilmek için CLLocationCoordinate2D protokolunu genisletiyoruz
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// --- 0. KONUM YÖNETİCİSİ ---
// kullanicinin anlik konumunu almak ve izinleri yonetmek icin kullanilan siniftir
class KonumYoneticisi: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var kullaniciKonumu: CLLocationCoordinate2D? //konum degistikce arayuzu gunceller
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest //en yuksek konum hassasiyetini ayarlar
    }

    // uygulama konum izni ister ve konum guncellemelerini baslatir
    func izinIste() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    // telefon her konum guncellediginde bu fonk calisir ve veriyi saklar
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        kullaniciKonumu = locations.first?.coordinate
    }
    
    // izin durumu degistiginde (mesela kullanici izni onayladiginda) takibi baslatir
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// --- VERİ MODELİ ---
// Firestore'dan cekilen otopark bilgilerini temsil eden nesne yapisi
struct Otopark: Identifiable {
    let id: String                          //her otoparkin benzersiz kimligi
    let isim: String                        //otopark adi
    let koordinat: CLLocationCoordinate2D   //harita uzerindeki yeri
    let mevcutDoluluk: Int                  //icerdeki arac sayisi
    let toplamKapasite: Int                 //max kapasite
    
    // doluluk oranini yuzde olarak hesaplayan degisken
    var dolulukYuzdesi: Double {
        guard toplamKapasite > 0 else { return 0 }
        return (Double(mevcutDoluluk) / Double(toplamKapasite)) * 100
    }
    
    // yuzdelik degere gore harita icon rengini belirleme
    var noktaRengi: Color {
        if dolulukYuzdesi >= 100 {
            return .red      // %100: tamamen dolu
        } else if dolulukYuzdesi >= 85 {
            return .orange   // %85 - %99: kritik doluluk
        } else if dolulukYuzdesi >= 50 {
            return .yellow   // %50 - %84: yogun
        } else {
            return .green    // %0 - %49: musait
        }
    }

    //otoparkta bos yer var mi?
    var musaitlikDurumu: Bool {
        return mevcutDoluluk < toplamKapasite
    }
}

// --- ANA GIRIS KONTROLU ---
// uygulamanin en tepesindeki kontrol mekanizmasi
// kullanici giris yapmissa uygulamayi, yapmamissa giris/kayit ekranlarini gosterir
struct ContentView: View {
    @StateObject private var konumYoneticisi = KonumYoneticisi() //konum servislerini baslatan nesne
    @AppStorage("girisYapildi") var girisYapildi: Bool = false // oturum bilgisini cihaz hafizasinda tutar
    
    var body: some View {
        Group {
            if girisYapildi {
                // kullanici oturum acmissa ana sekmeli yapiyi (harita/liste/profil) goster
                AnaUygulamaView()
                    .environmentObject(konumYoneticisi) // konum yoneticisini alt gorunumlere aktarır
                    .transition(.opacity) //ekranlar arasi yumusak gecis saglar
            } else {
                // kullanici oturum acmamissa hos geldiniz/giris/kayit konteynerini goster
                AuthContainerView()
            }
        }
        .preferredColorScheme(.light) // uygulamanin her zaman acik modda gorunmesini saglar
    }
}

// --- AUTH CONTAINER ---
// giris ve kayit ekranlari arasindaki gecisi yoneten ara katmandir
struct AuthContainerView: View {
    @State private var ekranDurumu: AuthEkraniTipi = .karsilama // ilk acilista karsilamayi gosterir
    enum AuthEkraniTipi { case karsilama, giris, kayit }
    
    var body: some View {
        ZStack {
            switch ekranDurumu {
            case .karsilama:
                // ilk acilis ekrani
                KarsilamaEkrani(baslaAction: { withAnimation { ekranDurumu = .giris } })
            case .giris:
                //giris yapma ekrani
                GirisEkrani(kayitOlAction: { withAnimation { ekranDurumu = .kayit } })
            case .kayit:
                // kayit olma ekrani
                KayitEkrani(girisYapAction: { withAnimation { ekranDurumu = .giris } })
            }
        }
    }
}

// --- 1. KARŞILAMA EKRANI ---
// ONBOARDING SAYFASI
struct KarsilamaEkrani: View {
    var baslaAction: () -> Void // butona basildiginda calisacak kod
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]), startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 40) {
                Spacer()
                Image(systemName: "location.circle.fill").resizable().scaledToFit().frame(width: 120).foregroundColor(.blue).shadow(radius: 10)
                VStack(spacing: 16) {
                    Text("sMARK").font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                    Text("En yakın otoparkı bul, rotanı oluştur.").multilineTextAlignment(.center).foregroundColor(.secondary)
                }
                Spacer()
                // baslatma butonu
                Button(action: baslaAction) {
                    HStack { Text("Hemen Başla").fontWeight(.bold); Image(systemName: "arrow.right") }
                        .frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(16).shadow(radius: 5)
                }.padding(.horizontal, 40).padding(.bottom, 50)
            }
        }
    }
}

// --- 2. GİRİŞ EKRANI ---
// mevcut kullanicilarin eposta ve sifre ile giris yaptigi bolumdur
struct GirisEkrani: View {
    var kayitOlAction: () -> Void
    @AppStorage("girisYapildi") var girisYapildi: Bool = false
    @State private var email = ""
    @State private var sifre = ""
    @State private var mesaj = ""

    var body: some View {
        VStack(spacing: 25) {
            Text("Giriş Yap").font(.largeTitle).bold().foregroundColor(.blue)
            VStack(spacing: 15) {
                TextField("E-posta Adresi", text: $email).textFieldStyle(RoundedBorderTextFieldStyle()).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                SecureField("Şifre", text: $sifre).textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            if !mesaj.isEmpty {
                Text(mesaj).foregroundColor(mesaj.contains("Hoş geldiniz") ? .green : .red).font(.caption).bold()
            }
            // firebase authentication ile giris islemini tetikleyen buton
            Button(action: girisYap) {
                Text("Giriş Yap").frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(12)
            }.padding(.horizontal)
            HStack {
                Text("Hesabın yok mu?")
                Button("Kayıt Ol", action: kayitOlAction).fontWeight(.bold).foregroundColor(.blue)
            }
        }.padding().background(Color.white)
    }

    func girisYap() {
        // firebase auth: eposta ve sifre dogrulamasi yapar
        Auth.auth().signIn(withEmail: email, password: sifre) { result, error in
            if let error = error {
                mesaj = "Giriş başarısız: \(error.localizedDescription)"
            } else {
                mesaj = "Giriş başarılı! Hoş geldiniz."
                // 1.5 saniye sonra oturum durumunu guncelleyip ana ekrana yonlendirir
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { girisYapildi = true } }
            }
        }
    }
}

// --- 3. KAYIT EKRANI ---
// yeni kullanicilarin hesap olusturdugu ve bilgilerini girdigi ekrandir
struct KayitEkrani: View {
    var girisYapAction: () -> Void
    @AppStorage("girisYapildi") var girisYapildi: Bool = false
    @AppStorage("kullaniciPlaka") var kullaniciPlaka: String = ""
    @AppStorage("kullaniciAdSoyad") var kullaniciAdSoyad: String = ""
    @State private var adSoyad = ""
    @State private var email = ""
    @State private var telefon = ""
    @State private var sifre = ""
    @State private var plaka = ""
    @State private var mesaj = ""

    var body: some View {
        ScrollView {        //klavyenin formu kapatmamasi icin kaydirilabilir yapi
            VStack(spacing: 25) {
                Text("Kayıt Ol").font(.largeTitle).bold().foregroundColor(.blue).padding(.top, 40)
                VStack(spacing: 15) {
                    TextField("Ad Soyad", text: $adSoyad).textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("E-posta Adresi", text: $email).textFieldStyle(RoundedBorderTextFieldStyle()).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    TextField("Telefon Numarası (Örn: 5551234567)", text: $telefon)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.phonePad) // Sadece rakam klavyesi açar
                    SecureField("Şifre (En az 8 karakter)", text: $sifre).textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Araç Plakası (Örn: 34ABC123)", text: $plaka).textFieldStyle(RoundedBorderTextFieldStyle()).textInputAutocapitalization(.characters)
                }.padding(.horizontal)
                
                if !mesaj.isEmpty {
                    Text(mesaj).foregroundColor(mesaj.contains("başarıyla") ? .green : .red).font(.caption).bold().multilineTextAlignment(.center).padding(.horizontal)
                }
                
                Button(action: kayitOl) {
                    Text("Kayıt Ol ve Başla").frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
                }.padding(.horizontal)
                HStack {
                    Text("Zaten hesabın var mı?")
                    Button("Giriş Yap", action: girisYapAction).fontWeight(.bold).foregroundColor(.blue)
                }
            }.padding().background(Color.white)
        }
    }

    func kayitOl() {
        // form kontrolleri (validasyonlar)
        if adSoyad.isEmpty || email.isEmpty || sifre.isEmpty || plaka.isEmpty { mesaj = "Lütfen tüm alanları doldurun."; return }
        if !email.contains("@") { mesaj = "Geçersiz e-posta adresi girdiniz."; return }
        if sifre.count < 8 { mesaj = "Şifre 8 haneden küçük olamaz."; return }
        if telefon.count > 10 || telefon.count < 10 { mesaj = "Telefon numarası 10 haneli olmalıdır."; return }
        if !telefon.starts(with: "5") { mesaj = "Telefon numarası 5 ile başlamalıdır."; return }

        // firebase auth: yeni kullanici olusturma islemi
        Auth.auth().createUser(withEmail: email, password: sifre) { result, error in
            if let error = error {
                mesaj = "Hata: \(error.localizedDescription)"
            } else {
                guard let uid = result?.user.uid else { return }
                let temizPlaka = plaka.replacingOccurrences(of: " ", with: "").uppercased()
                let db = Firestore.firestore()
                
                // firestore: kullanici bilgilerini veritabanina kaydetme (AI formatina uygun sekilde)
                let veri: [String: Any] = ["name": adSoyad, "email": email, "plate": temizPlaka, "phone": telefon, "uid": uid]
                db.collection("users").document(uid).setData(veri) { err in
                    if err != nil { mesaj = "Veritabanı hatası oluştu." } else {
                        // basarili kayit: bilgileri yerel hafizaya yaz ve oturumu baslat
                        mesaj = "Kayıt başarıyla oluşturuldu! Hoş geldiniz."
                        kullaniciPlaka = temizPlaka
                        kullaniciAdSoyad = adSoyad
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { withAnimation { girisYapildi = true } }
                    }
                }
            }
        }
    }
}

// --- ANA UYGULAMA ---
// oturum acildiktan sonra gorunen ana sekmeli ekran (tab bar)
struct AnaUygulamaView: View {
    @State private var otoparklar: [Otopark] = [] //otopark listesi burada saklanir

    var body: some View {
        TabView {
            // harita sekmesi
            HaritaEkrani(otoparklar: $otoparklar).tabItem { Label("Harita", systemImage: "map.fill") }
            // otoparklari liste olarak gosteren sekme
            ListeEkrani(otoparklar: $otoparklar).tabItem { Label("Liste", systemImage: "list.bullet") }
            // kullanici profil ve cikis sekmesi
            ProfilEkrani().tabItem { Label("Profil", systemImage: "person.circle.fill") }
        }.tint(.blue)
    }
}

// --- HARİTA EKRANI ---
struct HaritaEkrani: View {
    // konum yoneticisi ve otopark verilerini baglar
    @EnvironmentObject var konumYoneticisi: KonumYoneticisi
    @Binding var otoparklar: [Otopark]

    //yerel degiskenler
    @State private var kameraPozisyonu: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var secilenOtopark: Otopark?
    @State private var navigasyonModu = false
    @State private var hesaplananRota: MKRoute?
    
    // secili otoparka gore canli doluluk orani
    var canliDoluluk: Int {
        if let otopark = secilenOtopark {
            return Int(otopark.dolulukYuzdesi)
        }
        return 0
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // ANA HARITA KATMANI
            Map(position: $kameraPozisyonu) {
                UserAnnotation() // kullanicinin harita uzerindeki konumunu gosterir

                //eger rota hesaplanmissa harita uzerinde cizer
                if let rota = hesaplananRota {
                    MapPolyline(rota)
                        .stroke(.blue, lineWidth: 6)
                }

                //firestore'dan gelen otopark listesini harita uzerindeki iconlara donusturur
                ForEach(otoparklar) { otopark in
                    Annotation(otopark.isim, coordinate: otopark.koordinat) {
                        VStack(spacing: 4) {
                            Image(systemName: "car.fill") //otopark simgesi
                                .padding(8)
                                .background(otopark.noktaRengi) //doluluk oranina gore rengi
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                        .onTapGesture {   // otopark iconuna basildiginda secili otopark olarak ayarlar
                            if !navigasyonModu {
                                secilenOtopark = otopark
                            }
                        }
                    }
                }
            }
            // harita uzerindeki standart Apple kontrolleri
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }

            // sag ust otopark doluluk gostergesi
            // sadece bir otopark secildiginde veya navigasyon basladiginda gorunur
            if secilenOtopark != nil || navigasyonModu {
                VStack {
                    HStack {
                        Spacer() //paneli saga ittirmek icin
                        VStack(spacing: 4) {
                            Text("Doluluk")
                                .font(.caption2)
                                .bold()

                            Text("\(canliDoluluk)%") //secili otoparkin canli doluluk yuzdesi
                                .font(.title2)
                                .bold()
                                //doluluk yuzde 80 den fazlaysa metni kirmizi yapar
                                .foregroundColor(canliDoluluk > 80 ? .red : .blue)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.95))
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding(.top, 60)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }

            // alt kontrol paneli
            VStack {
                if navigasyonModu {
                    // navigasyon devam ederken "bitir" butonu
                    Button(action: navigasyonuBitir) {
                        Text("Navigasyonu Bitir")
                            .bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    .padding()

                } else if let otopark = secilenOtopark {
                    // bir otopark secildiginde acilan detay ve yol tarifi karti
                    OtoparkDetayKarti(
                        otopark: otopark,
                        kapatAction: {
                            secilenOtopark = nil
                            hesaplananRota = nil
                        },
                        yolTarifiAction: {
                            Task {
                                await rotayiHesapla(hedef: otopark.koordinat)
                            }
                        }
                    )

                } else {
                    // hicbir sey secili degilken en altta duran ana islem butonu
                    Button(action: akilliEnYakinBul) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title3)

                            Text("En Yakın Boş Park Yerini Bul")
                                .fontWeight(.bold)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 30) // tab bar'in hemen ustunde durabilmesi icin
                }
            }
        }
        .onAppear {
            // ekran acildiginda konum izni istenir ve db dinlenmeye baslanir
            konumYoneticisi.izinIste()
            firebaseVerileriniDinle()
        }
    }

    // en yakin bos otopark bulma
    func akilliEnYakinBul() {
        // kullanicinin mevcut konumu bulunamazsa islem yapma
        guard let userLoc = konumYoneticisi.kullaniciKonumu else { return }

        // sadece bos yer olan otoparklari listele
        let bosOtoparklar = otoparklar.filter { $0.musaitlikDurumu }

        // filtrelenen otoparklar arasinda mesafesi en dusuk olani sec
        let enYakin = bosOtoparklar.min {
            CLLocation(latitude: $0.koordinat.latitude, longitude: $0.koordinat.longitude)
                .distance(from: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude))
            <
            CLLocation(latitude: $1.koordinat.latitude, longitude: $1.koordinat.longitude)
                .distance(from: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude))
        }

        // eger uygun bir otopark bulunduysa kamerayi oraya suzulerek odakla
        if let hedef = enYakin {
            withAnimation(.easeInOut(duration: 1.2)) {
                secilenOtopark = hedef
                kameraPozisyonu = .region(
                    MKCoordinateRegion(
                        center: hedef.koordinat,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )
                )
            }
        }
    }

    // firestore uzerindeki otopark verilerini anlik olarak takip eder
    func firebaseVerileriniDinle() {
        let db = Firestore.firestore()
        // dinlenecek collection list
        let collections = [ "parking_spots"]

        for name in collections {
            db.collection(name).addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { return }

                //db den gelen veriyi 'otopark' modeline donusturur
                let yeniOtoparklar = docs.compactMap { d -> Otopark? in
                    let data = d.data()
                    let geo = data["location"] as? GeoPoint

                    return Otopark(
                        id: d.documentID,
                        isim: data["name"] as? String ?? "Otopark",
                        koordinat: CLLocationCoordinate2D(
                            latitude: geo?.latitude ?? 0,
                            longitude: geo?.longitude ?? 0
                        ),
                        mevcutDoluluk: data["current_occupancy"] as? Int ?? 0,
                        toplamKapasite: data["total_capacity"] as? Int ?? 100
                    )
                }

                // arayuz guncellemelerini ana islemci uzerinde yap
                DispatchQueue.main.async {
                    for yeni in yeniOtoparklar {
                        // eger otopark listede varsa guncelle, yoksa yeni ekle
                        if let index = otoparklar.firstIndex(where: { $0.id == yeni.id }) {
                            otoparklar[index] = yeni
                        } else {
                            otoparklar.append(yeni)
                        }
                    }
                }
            }
        }
    }

    // kullanicidan otoparka giden yolu Apple Servisler kullanarak cizer
    func rotayiHesapla(hedef: CLLocationCoordinate2D) async {
        guard let baslangic = konumYoneticisi.kullaniciKonumu else { return }

        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: baslangic))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: hedef))

        // Apple sunuculardan yol tarifi vermesi istenir
        if let result = try? await MKDirections(request: req).calculate(),
           let rota = result.routes.first {

            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    hesaplananRota = rota //haritadaki mavi cizgiyi gunceller
                    navigasyonModu = true //alt paneli navigasyon gorunumune sokar
                    //secilenOtopark = nil
                    kameraPozisyonu = .userLocation(fallback: .automatic) //kamerayi kullaniciya odaklar
                }
            }
        }
    }

    // rota cizgisini siler ve arayuzu normal harita moduna dondurur
    func navigasyonuBitir() {
        withAnimation {
            navigasyonModu = false
            hesaplananRota = nil
            secilenOtopark = nil
            kameraPozisyonu = .userLocation(fallback: .automatic)
        }
    }
}



// LISTE EKRANI
// mevcut otoparklari doluluk oranlari ve renkli gostergeleriyle listeleyen ekran
struct ListeEkrani: View {
    @Binding var otoparklar: [Otopark]
    var body: some View {
        NavigationStack {
            List(otoparklar) { otopark in
                HStack(spacing: 15) {
                    // doluluk durumuna gore renkli yanan nokta
                    Circle().fill(otopark.noktaRengi).frame(width: 15, height: 15)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(otopark.isim).font(.headline)
                        Text("Doluluk: %\(Int(otopark.dolulukYuzdesi))").font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        // bos yer varsa "musait" yoksa "dolu" etiketi
                        Text(otopark.musaitlikDurumu ? "Müsait" : "Dolu")
                            .font(.caption).bold()
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(otopark.musaitlikDurumu ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            .foregroundColor(otopark.musaitlikDurumu ? .green : .red).cornerRadius(8)
                        Text("\(otopark.mevcutDoluluk) / \(otopark.toplamKapasite)").font(.system(size: 10)).foregroundColor(.gray)
                    }
                }
            }.navigationTitle("Otopark Durumu")
        }
    }
}

// --- PROFİL EKRANI ---
// kullanici bilgilerini gosteren ve guvenli cikis yapilmasini saglayan ekran
struct ProfilEkrani: View {
    @AppStorage("girisYapildi") var girisYapildi: Bool = true
    @AppStorage("kullaniciPlaka") var kullaniciPlaka: String = ""
    @AppStorage("kullaniciAdSoyad") var kullaniciAdSoyad: String = ""
    
    var body: some View {
            NavigationStack {
                List {
                    VStack(spacing: 15) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                        
                        Text(kullaniciAdSoyad)
                            .font(.title2)
                            .bold()
                        
                        Text(kullaniciPlaka)
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear) // Kartın arkasını şeffaf yapar
                    .listRowSeparator(.hidden)
                    .padding(.bottom, 20)

                    Section(header: Text("HESAP AYARLARI")) {
                        // firebase oturumunu sonlandiran buton
                        Button(action: {
                            withAnimation {
                                girisYapildi = false
                                try? Auth.auth().signOut()
                            }
                        }) {
                            HStack {
                                Image(systemName: "power")
                                    .foregroundColor(.red)
                                Text("Çıkış Yap")
                                    .foregroundColor(.red)
                                    .bold()
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Profilim")
                .onAppear { profilBilgileriniGuncelle() } // sayfa acilinca verileri db den tazele
            }
        }

    // firestore'dan guncel kullanici verilerini ceker
    func profilBilgileriniGuncelle() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).getDocument { d, _ in
            if let data = d?.data() {
                self.kullaniciAdSoyad = data["name"] as? String ?? "Misafir"
                self.kullaniciPlaka = data["plate"] as? String ?? "34TR1234"
            }
        }
    }
}

// --- DETAY KARTI ---
// haritada otopark secildiginde altta acilan bilgi paneli
struct OtoparkDetayKarti: View {
    let otopark: Otopark
    let kapatAction: () -> Void
    let yolTarifiAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(otopark.isim).font(.title3).bold()
                    // doluluk orani ve ona uygun rengi gosterir
                    Text("Doluluk Oranı: %\(Int(otopark.dolulukYuzdesi))").foregroundColor(otopark.noktaRengi)
                }
                Spacer()
                // paneli kapatma butonu
                Button(action: kapatAction) { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }
            }
            
            // eger otoparkta yer varsa navigasyon butonu aktif olur
            if otopark.musaitlikDurumu {
                Button(action: yolTarifiAction) {
                    Text("Navigasyonu Başlat").frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(12)
                }
                //doluysa deaktif
            } else {
                Text("Otopark Tamamen Dolu").frame(maxWidth: .infinity).padding().background(Color.gray).foregroundColor(.white).cornerRadius(12)
            }
        }
        .padding().background(Color.white).cornerRadius(20).shadow(radius: 5).padding()
    }
}

