//
//  LegalComplianceView.swift
//  Encore
//
//  Created for App Store & GDPR Compliance.
//

import SwiftUI

public struct LegalComplianceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: LegalTab

    public enum LegalTab: String, CaseIterable, Identifiable {
        case privacy = "Súkromie"
        case terms = "Podmienky"
        case disclaimer = "Zodpovednosť"
        case audioKsis = "Hudba a KSIS"

        public var id: String { rawValue }

        
        var icon: String {
            switch self {
            case .privacy: return "hand.raised.fill"
            case .terms: return "doc.text.fill"
            case .disclaimer: return "cross.case.fill"
            case .audioKsis: return "music.note.list"
            }
        }
    }

    /// `initialTab` opens the section the user tapped (e.g. Terms from the login screen).
    public init(initialTab: LegalTab = .privacy) {
        _selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                VStack(spacing: 0) {
                    // All four sections visible at once, two per row.
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(LegalTab.allCases) { tab in
                            tabButton(tab)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .sensoryFeedback(.selection, trigger: selectedTab)

                    // Content ScrollView
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            switch selectedTab {
                            case .privacy:
                                privacyPolicyContent
                            case .terms:
                                termsAndEulaContent
                            case .disclaimer:
                                disclaimerContent
                            case .audioKsis:
                                audioAndKsisContent
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Právne informácie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") {
                        dismiss()
                    }
                    .foregroundColor(.gold400)
                }
            }
        }
    }

    // MARK: - 1. Privacy Policy (GDPR)
    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerBadge(title: "Zásady ochrany osobných údajov", icon: "lock.shield.fill")
            
            legalSection(
                title: "1. Prevádzkovateľ a správca osobných údajov",
                body: "Prevádzkovateľom aplikácie Encore a správcom osobných údajov je Jakub Kalina (fyzická osoba). Kontakt pre otázky a uplatnenie práv dotknutých osôb podľa GDPR: \(AppContact.supportEmail)."
            )
            
            legalSection(
                title: "2. Aké údaje spracúvame a prečo",
                body: """
                • Registračné údaje: meno alebo prezývka a e-mailová adresa (zadané priamo alebo cez prihlásenie Google či Apple). Právny základ: plnenie zmluvy o poskytovaní služby.
                • Rok narodenia (len rok, nie dátum): ak môžeš mať menej ako 16 rokov, pri registrácii súhlasí rodič a ostatní ťa nájdu len podľa ID tanečníka alebo QR kódu, nie podľa mena. Právny základ: plnenie zmluvy a čl. 8 GDPR.
                • Tanečné materiály: zostavy, choreografie, vlastné poznámky a nahrávky figúr. Vidíš ich len ty a ľudia, s ktorými ich sám zdieľaš.
                • Záloha denníka, plánu a poznámok: text zápisov z Denníka, Plánu a poznámok z Domova ukladáme na server, aby si ich dostal späť na novom iPhone. Videá, hlasové poznámky a fotky ostávajú v iPhone. Vidíš ich len ty.
                • Tréningové videá a porovnanie so vzorom: videá sú v tvojich Fotkách. Čiary a sklon v porovnaní kreslíš sám; appka nerozpoznáva postavu ani tvár a videá nepoužíva na biometrickú identifikáciu.
                • Súťažné dáta z verejného systému KSIS (szts.ksis.eu), ktoré si uložíš zo stránky KSIS otvorenej v appke: kto si v KSIS (osobné číslo z preukazu, meno, klub, triedy), tvoje páry a pri tvojich súťažiach trieda, body, finále a výsledky.
                """
            )
            
            legalSection(
                title: "3. Doba uchovávania a zmazanie",
                body: "Tvoje údaje uchovávame, kým aplikáciu používaš. Kedykoľvek môžeš v Profile → Nastavenia ťuknúť na „Zmazať účet a osobné dáta“. Tým sa natrvalo zmažú všetky tvoje údaje zo serverov a zruší sa prihlásenie."
            )
            
            legalSection(
                title: "4. Tvoje práva podľa GDPR",
                body: """
                Ako dotknutá osoba máš právo na:
                • prístup k osobným údajom a informácie o ich spracúvaní,
                • opravu nesprávnych alebo neúplných údajov,
                • vymazanie (právo „na zabudnutie“) priamo v aplikácii,
                • prenosnosť a kópiu svojich údajov kedykoľvek (Profil → Nastavenia → Stiahnuť moje dáta),
                • podanie sťažnosti na Úrad na ochranu osobných údajov SR.
                """
            )
            
            legalSection(
                title: "5. Tretie strany a infraštruktúra",
                body: "Dáta sú bezpečne ukladané v databáze Supabase s platnou zmluvou o spracovaní údajov (DPA) a servermi umiestnenými v Európskej únii. Tvoje tréningové videá ostávajú v tvojich Fotkách na iPhone. Keď video zdieľaš s partnerom alebo trénerom, jeho zmenšenú kópiu ukladáme v úložisku Cloudflare R2 v Európe (so zmluvou o spracovaní údajov); vidí ju len tvoj partner alebo partnerka (či tréner) a po zrušení zdieľania sa zmaže. Žiadne osobné údaje nepredávame reklamným sieťam ani nesledujeme používateľov naprieč inými aplikáciami (App Tracking Transparency = No Tracking)."
            )
            
            legalSection(
                title: "6. Verejné športové dáta (SZTŠ / ksis.eu)",
                body: "Keď v appke otvoríš stránku KSIS, appka ju pošle na náš server, ktorý z nej prečíta len údaje o tebe. Uloží: kto si v KSIS (osobné číslo z preukazu, meno, klub a triedy, keď sa sám vyberieš v zozname členov), tvoje páry vrátane skončených a pri tvojich súťažiach triedu, body, finále, umiestnenia a krížiky porotcov. Mená ostatných členov a párov sa neukladajú. Kým ťa neoverí Encore alebo tvoj overený partner či partnerka, tieto údaje vidíš len ty. Páry ukladáš so súhlasom partnera alebo partnerky a každý pár aj s jeho výsledkami môžeš kedykoľvek odstrániť. Ak si overený a v nastaveniach zapneš Ukazovať moje výsledky spojeniam, ľudia, s ktorými si v appke spojený, uvidia triedu, body a uložené súťaže tvojich párov. Predvolene je to vypnuté. Právny základ: oprávnený záujem (čl. 6 ods. 1 písm. f GDPR), evidencia vlastnej športovej výkonnosti. Jediným oficiálnym zdrojom výsledkov je SZTŠ."
            )
            
            legalSection(
                title: "7. Administrátorský a servisný prístup",
                body: "Personál a správca aplikácie má prístup k systémovým údajom výlučne na účely technickej podpory, diagnostiky chýb a riešenia nahlásených bezpečnostných incidentov. Správca aplikácie neposkytuje ani nezverejňuje súkromné materiály používateľov."
            )
        }
    }

    // MARK: - 2. Terms of Service & EULA
    private var termsAndEulaContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerBadge(title: "Podmienky používania (EULA)", icon: "doc.plaintext.fill")

            legalSection(
                title: "1. Prijatie podmienok",
                body: "Používaním aplikácie Encore súhlasíš s týmito podmienkami používania (EULA). Ak s nimi nesúhlasíš, aplikáciu nepoužívaj."
            )

            legalSection(
                title: "2. Pravidlá používateľského obsahu (UGC)",
                body: """
                Aplikácia Encore uplatňuje politiku nulovej tolerancie voči nevhodnému obsahu:
                • Je prísne zakázané nahrávať, synchronizovať alebo zdieľať cez QR kód obsah, ktorý je urážlivý, nezákonný, hanlivý, obťažujúci alebo porušuje autorské práva tretích strán.
                • Zdieľanie zostáv s tanečným partnerom alebo priateľom je určené výhradne na legálne športové a tréningové účely.
                • Porušenie týchto pravidiel má za následok okamžité zablokovanie účtu a vymazanie synchronizovaných zostáv.
                """
            )

            legalSection(
                title: "3. Duševné vlastníctvo a vlastníctvo choreografií",
                body: "Všetky tvoje choreografie, zostavy, videá a poznámky zostávajú v tvojom výlučnom vlastníctve. Prevádzkovateľovi aplikácie udeľuješ iba technickú licenciu nevyhnutnú na ich uloženie a zobrazenie na tvojich zariadeniach."
            )

            legalSection(
                title: "4. Predplatné a In-App platby",
                body: "Pokiaľ aplikácia ponúka platené funkcie alebo predplatné na iOS zariadeniach, platby sú spracovávané výhradne prostredníctvom Apple In-App Purchase (StoreKit) v súlade s pravidlami spoločnosti Apple. Správu predplatného a žiadosti o vrátenie peňazí je možné vykonávať cez nastavenia Apple ID."
            )

            legalSection(
                title: "5. Bezplatné VIP licencie a dary",
                body: "Prevádzkovateľ aplikácie si vyhradzuje právo podľa vlastného uváženia bezplatne udeliť alebo predĺžiť plnú či čiastočnú prémiovú licenciu vybraným používateľom (VIP grant pre partnerov, trénerov, ambasádorov a testerov) bez vzniku nároku na takéto plnenie pre ostatných používateľov."
            )

            legalSection(
                title: "6. Moderácia a zablokovanie účtu",
                body: "Prevádzkovateľ má právo okamžite pozastaviť alebo zablokovať účet používateľovi, ktorý závažne poruší tieto Podmienky používania, pravidlá slušnosti, pokúsi sa o neoprávnený zásah do bezpečnosti alebo obťažovanie iných používateľov. V prípade zablokovania z dôvodu porušenia pravidiel nevzniká nárok na refundáciu predplatného."
            )

            legalSection(
                title: "7. Vekové obmedzenie a ochrana mladistvých (GDPR)",
                body: "Aplikácia Encore je určená pre tanečníkov všetkých vekových kategórií vrátane juniorov a mládeže. Používatelia mladší ako 16 rokov môžu aplikáciu používať a zakladať si účet výhradne so súhlasom svojho zákonného zástupcu (rodiča) v súlade s článkom 8 nariadenia GDPR a zákonom č. 18/2018 Z. z. o ochrane osobných údajov."
            )
        }
    }

    // MARK: - 3. Disclaimers
    private var disclaimerContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerBadge(title: "Vyhlásenie o vylúčení zodpovednosti", icon: "cross.case.fill")

            legalSection(
                title: "1. Zdravotné a tréningové vyhlásenie",
                body: """
                Aplikácia Encore je asistenčný nástroj pre tanečníkov a trénerov. 
                • Porovnanie so vzorom, čiary, sklon a tréningové záznamy majú výhradne orientačný charakter a nenahrádzajú trénera.
                • Aplikácia nenahrádza odborné vedenie certifikovaného trénera, fyzioterapeuta ani lekára.
                • Tréning a fyzické cvičenie vykonávaš na vlastné riziko. Prevádzkovateľ nenesie zodpovednosť za akékoľvek zranenia, úrazy alebo poškodenia zdravia vzniknuté v súvislosti s tréningom podľa aplikácie.
                """
            )

            legalSection(
                title: "2. Presnosť súťažných dát",
                body: "Dáta o bodoch a finálových umiestneniach zo systému ksis.eu majú informatívny charakter. Jediným oficiálnym a právne záväzným zdrojom súťažných výsledkov je Slovenský zväz tanečného športu (SZTŠ)."
            )
        }
    }

    // MARK: - 4. Audio & KSIS Fair Use
    private var audioAndKsisContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerBadge(title: "Hudba, médiá a KSIS", icon: "music.note.list")

            legalSection(
                title: "1. Zvukové nahrávky a metronóm",
                body: """
                • Metronóm nevyužíva žiadne chránené zvukové vzorky tretích strán — všetky rytmické signály sú generované algoritmicky v reálnom čase matematickou syntézou zvukovej vlny.
                • Nástroj Hudba prehráva len vlastné zvukové súbory používateľa. Aplikácia neobsahuje žiadne chránené hudobné diela. Používateľ zodpovedá za to, že k nahrávkam, ktoré si do aplikácie importuje, disponuje príslušnými právami.
                """
            )

            legalSection(
                title: "2. Záznamy zo seminárov a videá vzorov",
                body: "Pri nahrávaní tréningových seminárov alebo importovaní vzorových videí používateľ zodpovedá za získanie súhlasu dotknutých osôb v zmysle autorského zákona a ochrany osobnosti. Tieto záznamy slúžia len na súkromné študijné účely používateľa."
            )

            legalSection(
                title: "3. Informácia o systéme KSIS",
                body: "Názov KSIS a výsledkové listiny sú majetkom ich prevádzkovateľov. Encore číta len verejné stránky KSIS, ktoré si sám otvoríš v appke. Sama na KSIS nechodí ani nič neobnovuje na pozadí."
            )
        }
    }

    // MARK: - Helpers
    private func tabButton(_ tab: LegalTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selectedTab = tab }
        } label: {
            Label(tab.rawValue, systemImage: tab.icon)
                .font(.footnote.weight(.semibold))
                .foregroundColor(isSelected ? Color.obsidian900 : .white.opacity(0.85))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(isSelected ? Color.gold400 : Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0 : 0.1), lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func headerBadge(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.gold400)
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.black))
                .foregroundColor(.gold400)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.vertical, 4)
    }

    private func legalSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)

            Text(body)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 16)
    }
}

// MARK: - Xcode Canvas Preview
#Preview("LegalComplianceView") {
    LegalComplianceView()
        .preferredColorScheme(.dark)
}
