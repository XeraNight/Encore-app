import SwiftUI

// MARK: - "Ako fungujú videá" (Settings → Pomoc a právne)
/// Explains where videos live, how sharing works and how to keep the shared space free.
struct VideoGuideView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    private struct Topic: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let text: String
    }

    private var topics: [Topic] {
        let photos = Topic(
            title: "TVOJE VIDEÁ SÚ VO FOTKÁCH",
            icon: "photo.on.rectangle.angled",
            text: "Čo natočíš v Encore, uloží sa do Fotiek do albumu Encore. Encore si pamätá len odkaz, takže video nemáš v telefóne dvakrát a zálohuje ho tvoj iCloud. Keď ho vo Fotkách zmažeš, zmizne aj z Encore."
        )
        let voice = Topic(
            title: "HLASOVÉ NAHRÁVKY",
            icon: "waveform",
            text: "Fotky zvuk neukladajú, preto hlasové poznámky ostávajú v Encore v tvojom iPhone. Zálohujú sa so zálohou iPhonu v iCloude."
        )
        guard AppFeatures.sharedVideos else {
            return [
                photos,
                Topic(
                    title: "VIDEO PRE PARTNERA",
                    icon: "paperplane.fill",
                    text: "Video nájdeš vo Fotkách v albume Encore. Partnerovi alebo trénerovi ho pošleš cez AirDrop alebo Správy, v plnej kvalite."
                ),
                voice,
            ]
        }
        let limits = SubscriptionTier.allCases.map { "\($0.rawValue) \($0.sharedVideoStorage)" }.joined(separator: ", ")
        return [
            photos,
            Topic(
                title: "ZDIEĽANIE S PARTNEROM A TRÉNEROM",
                icon: "person.2.fill",
                text: "V detaile figúry ťukni na ⋯ a vyber Zdieľať s partnerom a trénerom. Uvidia zmenšenú kópiu (720p) priamo pri figúre. Tvoj originál ostáva u teba. Keď natočíš novú verziu, zdieľaná sa sama vymení."
            ),
            Topic(
                title: "MIESTO NA ZDIEĽANÉ VIDEÁ",
                icon: "externaldrive.fill",
                text: "Zdieľané videá zaberajú miesto z tvojho plánu (\(limits)). Tvoj plán \(subscriptionManager.currentTier.rawValue) má \(subscriptionManager.currentTier.sharedVideoStorage). Polminútové video má asi 10 MB. Keď video už netreba, zruš zdieľanie a miesto sa uvoľní."
            ),
            Topic(
                title: "TIP: ULOŽ SI VIDEO OD PARTNERA",
                icon: "square.and.arrow.down.fill",
                text: "Video, ktoré ti niekto zdieľal, si ulož cez ⋯ → Uložiť do mojich Fotiek. Budeš ho mať natrvalo a aj bez internetu. Partner potom môže zdieľanie zrušiť a uvoľniť si miesto."
            ),
            voice,
        ]
    }

    var body: some View {
        ZStack {
            EllegancePageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(topics) { topic in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: topic.icon)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.gold400)
                                .frame(width: 36, height: 36)
                                .background(Color.gold500.opacity(0.14), in: Circle())
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(topic.title)
                                    .font(.system(.caption, design: .rounded).weight(.black))
                                    .tracking(1.1)
                                    .foregroundStyle(Color.gold400)
                                Text(topic.text)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .homeCard()
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Ako fungujú videá")
        .navigationBarTitleDisplayMode(.inline)
    }
}
